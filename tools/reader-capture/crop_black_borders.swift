import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum CropError: Error, CustomStringConvertible {
    case usage
    case cannotReadImage
    case cannotCreateContext
    case pageNotFound
    case cannotCreateOutput
    case cannotWriteOutput

    var description: String {
        switch self {
        case .usage:
            return "Usage: crop_black_borders INPUT OUTPUT [--titlebar-only]"
        case .cannotReadImage:
            return "入力PNGを読み込めません。"
        case .cannotCreateContext:
            return "画像解析用コンテキストを作成できません。"
        case .pageNotFound:
            return "黒背景内のページ領域を検出できません。"
        case .cannotCreateOutput:
            return "出力PNGを作成できません。"
        case .cannotWriteOutput:
            return "出力PNGを書き込めません。"
        }
    }
}

func run() throws {
    guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
        throw CropError.usage
    }

    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let titlebarOnly = CommandLine.arguments.count == 4 &&
        CommandLine.arguments[3] == "--titlebar-only"

    guard
        let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw CropError.cannotReadImage }

    let width = image.width
    let height = image.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        // メモリ上の行を画像上端からの順序にそろえる。
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard rendered else { throw CropError.cannotCreateContext }

    // Kindleのタイトルバーを横方向の検出から除外する。
    let scanStartY = min(40, max(0, height / 12))
    let brightnessThreshold = 70

    var minX = width
    var maxX = -1
    var minY = height
    var maxY = -1

    func isNonBlack(_ x: Int, _ y: Int) -> Bool {
        let memoryY = height - 1 - y
        let offset = memoryY * bytesPerRow + x * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        return max(red, green, blue) > brightnessThreshold
    }

    func colorAt(_ x: Int, _ y: Int) -> (red: Int, green: Int, blue: Int) {
        let memoryY = height - 1 - y
        let offset = memoryY * bytesPerRow + x * bytesPerPixel
        return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
    }

    // 通常のmacOSタイトルバーでは、左上の赤・黄・緑ボタンを手掛かりに
    // 本文の開始位置を求める。白背景でもタイトルバーを識別できる。
    var trafficLightBottom: Int? = nil
    var foundRed = false
    var foundYellow = false
    var foundGreen = false
    var coloredPixelMaxY = -1
    for y in 0..<min(height, 60) {
        for x in 0..<min(width, 100) {
            let color = colorAt(x, y)
            let isRed = color.red > 170 && color.red > color.green + 55 && color.red > color.blue + 55
            let isYellow = color.red > 160 && color.green > 110 && color.blue < 130 && abs(color.red - color.green) < 100
            let isGreen = color.green > 120 && color.green > color.red + 45 && color.green > color.blue + 25
            if isRed || isYellow || isGreen {
                foundRed = foundRed || isRed
                foundYellow = foundYellow || isYellow
                foundGreen = foundGreen || isGreen
                coloredPixelMaxY = max(coloredPixelMaxY, y)
            }
        }
    }
    if foundRed && foundYellow && foundGreen {
        trafficLightBottom = min(height - 1, coloredPixelMaxY + 10)
    }

    // まず黒余白に挟まれたページの左右を求める。タイトルバーや
    // ウィンドウ隅の装飾を拾わないよう、縦方向に十分な数の明るい
    // 画素が連なる列だけをページとして扱う。
    let minimumBrightPixelsPerColumn = max(20, (height - scanStartY) / 5)
    for x in 0..<width {
        var brightPixelCount = 0
        for y in scanStartY..<height where isNonBlack(x, y) {
            brightPixelCount += 1
        }
        if brightPixelCount >= minimumBrightPixelsPerColumn {
            minX = min(minX, x)
            maxX = max(maxX, x)
        }
    }

    guard maxX > minX, (maxX - minX) > 100 else { throw CropError.pageNotFound }

    // ページの外側が黒くなり始める行をタイトルバー直下とみなす。
    // Kindleの細いタイトルバーまで画像に残るのを避けるための処理。
    let leftFlankX = max(0, minX - 8)
    let rightFlankX = min(width - 1, maxX + 8)
    var topContentStart = trafficLightBottom ?? 0
    var consecutiveDarkRows = 0
    if trafficLightBottom == nil {
        for y in 0..<min(height, 80) {
            if !isNonBlack(leftFlankX, y) && !isNonBlack(rightFlankX, y) {
                consecutiveDarkRows += 1
                if consecutiveDarkRows == 3 {
                    topContentStart = max(0, y - 2)
                    break
                }
            } else {
                consecutiveDarkRows = 0
            }
        }
    }
    // 求めたページ幅の内側で上下端を求める。一部の文字やアイコン
    // だけがある行ではなく、ページ幅にわたって明るい行を採用する。
    let minimumBrightPixelsPerRow = max(20, (maxX - minX + 1) / 5)
    for y in topContentStart..<height {
        var brightPixelCount = 0
        for x in minX...maxX where isNonBlack(x, y) {
            brightPixelCount += 1
        }
        if brightPixelCount >= minimumBrightPixelsPerRow {
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }

    guard maxY > minY, (maxY - minY) > 100 else { throw CropError.pageNotFound }

    // 境界の欠けを避けるため数ピクセルだけ外側を残す。
    let padding = 2
    if titlebarOnly {
        minX = 0
        maxX = width - 1
        minY = topContentStart
        maxY = height - 1
    } else {
        minX = max(0, minX - padding)
        if trafficLightBottom == nil {
            minY = max(0, minY - padding)
        } else {
            minY = max(minY, topContentStart)
        }
        maxX = min(width - 1, maxX + padding)
        maxY = min(height - 1, maxY + padding)
    }

    let cropRect = CGRect(
        x: minX,
        y: minY,
        width: maxX - minX + 1,
        height: maxY - minY + 1
    )

    guard let cropped = image.cropping(to: cropRect) else { throw CropError.pageNotFound }
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { throw CropError.cannotCreateOutput }

    CGImageDestinationAddImage(destination, cropped, nil)
    guard CGImageDestinationFinalize(destination) else { throw CropError.cannotWriteOutput }
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
