// page_click.swift
// 画面のグローバル座標（ポイント単位・左上原点）に本物のマウス左クリックを送るヘルパー。
// legend-capture が Libry ビューアのページ送り（余白クリック）に使う。
// ビルド: swiftc -O page_click.swift -o page_click
// 使い方: page_click <x> <y>

import Cocoa

let args = CommandLine.arguments
guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else {
    FileHandle.standardError.write("usage: page_click <x> <y>\n".data(using: .utf8)!)
    exit(2)
}

let point = CGPoint(x: x, y: y)

func post(_ type: CGEventType) {
    guard let ev = CGEvent(mouseEventSource: nil,
                           mouseType: type,
                           mouseCursorPosition: point,
                           mouseButton: .left) else { return }
    ev.post(tap: .cghidEventTap)
}

// カーソルを移動 → 押下 → 離す。アプリ側のクリック判定を確実に通すため間隔を空ける。
post(.mouseMoved)
usleep(40_000)
post(.leftMouseDown)
usleep(40_000)
post(.leftMouseUp)
