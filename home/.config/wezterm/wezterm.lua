local wezterm = require("wezterm")
local act = wezterm.action

local FONT_SIZE = 16.0

-- ─── Color Palette ── Rosé Pine Moon ─────────────────────────────────────────
-- 端末本体の配色（本文・ANSI16色）は組込みの color_scheme = "rose-pine-moon" に任せ、
-- ここでは組込みが面倒を見ない「タブバー」と、後述の選択色だけを明示する。
-- tmux(~/.config/tmux/tmux.conf の @thm_*) と nvim(rose-pine) も同じ公式パレット。
-- 3つのうち1つだけ変えると境目に継ぎ目が出るので、変えるときは必ず3つ揃えること。
local P = {
  base    = "#232136", -- 背景
  surface = "#2a273f",
  overlay = "#393552", -- アクティブなタブの背景
  muted   = "#6e6a86",
  subtle  = "#908caa", -- 非アクティブの文字（base とのコントラスト 4.9:1）
  text    = "#e0def4", -- 通常の文字
  iris    = "#c4a7e7", -- アクセント
  hl_med  = "#44415a", -- 選択範囲の背景
}

-- ─── Window Layout on Startup ────────────────────────────────────────────────
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  local gui = window:gui_window()
  local screens = wezterm.gui.screens()
  local s = screens.active or screens[1]
  local w = s.width
  local h = s.height
  local inner_w = math.floor(w * 0.4)
  local inner_h = math.floor(h * 0.5)
  local x = math.floor(w - inner_w)
  local y = math.floor((h - inner_h) / 2 - (h * 0.08))
  if y < 0 then y = 0 end
  gui:set_position(x, y)
  gui:set_inner_size(inner_w, inner_h)
end)

-- ─── Maximize / Fullscreen on demand (中で動くアプリから発火) ────────────────
-- tmux や herdr の中からは外側の WezTerm 窓を直接操作できないため、内側から
-- user-var を立て（OSC 1337 SetUserVar / tmux passthrough 経由）、ここで受ける。
-- 値は使わず名前一致だけ見る（値は nonce。同じ値だとイベントが発火しないため）。
--   WEZTERM_MAXIMIZE            窓を最大化する
--                               発火元: ~/.config/tmux/scripts/claude-layout.sh（Ctrl-a → W）
--   WEZTERM_FULLSCREEN          窓をフルスクリーンにする
--   WEZTERM_FULLSCREEN_RESTORE  ↑で入れたフルスクリーンを解除して元の窓に戻す
--                               発火元: ~/.zshrc の herdr ラッパ（TUI の開始/終了）
-- フルスクリーンは set 系の API が無く toggle しかないので、いまの状態を見て
-- 目的と違うときだけ切り替える（二度押しで裏返らないように）。
-- 「自分が入れたのか」は wezterm.GLOBAL に窓ごとに記録する。ローカル変数だと
-- config 保存＝リロードのたびに消えて復帰できないが、GLOBAL は跨いで残る。
-- 手でフルスクリーンにしていた窓には記録が無いので、herdr を閉じても解除しない。
wezterm.on("user-var-changed", function(window, pane, name, value)
  if window == nil then
    return
  end
  local key = "fullscreen_entered_by_app_" .. tostring(window:window_id())
  if name == "WEZTERM_MAXIMIZE" then
    window:maximize()
  elseif name == "WEZTERM_FULLSCREEN" then
    if not window:get_dimensions().is_full_screen then
      window:toggle_fullscreen()
      wezterm.GLOBAL[key] = true
    end
  elseif name == "WEZTERM_FULLSCREEN_RESTORE" then
    if wezterm.GLOBAL[key] then
      wezterm.GLOBAL[key] = false
      if window:get_dimensions().is_full_screen then
        window:toggle_fullscreen()
      end
    end
  end
end)

-- ─── Tab Title (tmux セッション名を表示) ─────────────────────────────────────
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tab.active_pane.title
  -- tmux が "session:window" 形式のタイトルをセットする場合に対応
  local session = title:match("^([^:]+):")
  local display = session and (" " .. session) or title
  if #display > max_width - 2 then
    display = display:sub(1, max_width - 3) .. "…"
  end
  if tab.is_active then
    return {
      { Background = { Color = P.overlay } },
      { Foreground = { Color = P.iris } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. display .. " " },
    }
  end
  return {
    { Background = { Color = P.base } },
    { Foreground = { Color = P.subtle } },
    { Text = " " .. display .. " " },
  }
end)

return {
  -- ─── Font ────────────────────────────────────────────────────────────────
  font = wezterm.font_with_fallback({
    "MesloLGS NF",
    "MesloLGS Nerd Font Mono",
    "MesloLGS Nerd Font",
    -- 日本語は明示的に Hiragino を指定する。
    -- 未指定だと中国語フォント(PingFang SC / Hiragino Sans GB)へ誤フォールバックし、
    -- 句読点(。、)が中央寄せ＝中国語組版になってしまうため。
    "Hiragino Sans",
    "Hiragino Kaku Gothic ProN",
    "Menlo",
  }),
  font_size = FONT_SIZE,

  -- ─── Color ───────────────────────────────────────────────────────────────
  color_scheme = "rose-pine-moon",

  -- ─── Tab Bar ─────────────────────────────────────────────────────────────
  enable_tab_bar = true,
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  tab_max_width = 30,
  colors = {
    -- 組込みの rose-pine-moon は selection_bg を背景と同じ #232136 で定義しており、
    -- そのままだとマウス選択した範囲が見た目に一切変わらない（選択が不可視）。
    -- 公式パレットの highlightMed に差し替えて選択が見えるようにする。
    selection_bg = P.hl_med,
    selection_fg = P.text,
    tab_bar = {
      background = P.base,
      active_tab = {
        bg_color = P.overlay,
        fg_color = P.iris,
        intensity = "Bold",
      },
      inactive_tab = {
        bg_color = P.base,
        fg_color = P.subtle,
      },
      inactive_tab_hover = {
        bg_color = P.surface,
        fg_color = P.text,
      },
      new_tab = {
        bg_color = P.base,
        fg_color = P.muted,
      },
    },
  },

  -- ─── Window ──────────────────────────────────────────────────────────────
  window_decorations = "TITLE | RESIZE",
  window_padding = { left = 4, right = 4, top = 4, bottom = 0 },
  macos_window_background_blur = 0,

  -- ─── Keybindings ─────────────────────────────────────────────────────────
  keys = {
    -- タブ管理
    { key = "t", mods = "CMD",       action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "CMD",       action = act.CloseCurrentTab({ confirm = true }) },
    { key = "1", mods = "CMD",       action = act.ActivateTab(0) },
    { key = "2", mods = "CMD",       action = act.ActivateTab(1) },
    { key = "3", mods = "CMD",       action = act.ActivateTab(2) },
    { key = "4", mods = "CMD",       action = act.ActivateTab(3) },
    { key = "5", mods = "CMD",       action = act.ActivateTab(4) },
    { key = "[", mods = "CMD|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "]", mods = "CMD|SHIFT", action = act.ActivateTabRelative(1) },

    -- クリップボード
    { key = "c", mods = "CMD", action = act.CopyTo("Clipboard") },
    { key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },

    -- 改行: Shift+Return で改行文字(LF)を送る。Claude Code はこの LF を
    -- プロンプト内の改行として扱う。以前は tmux の "C-j → ペイン移動" が
    -- この LF を横取りしていたが、その Ctrl+hjkl ブロックを廃止したので衝突しない。
    { key = "Enter", mods = "SHIFT", action = act.SendString("\n") },

    -- フォントサイズ
    { key = "+", mods = "CMD",       action = act.IncreaseFontSize },
    { key = "-", mods = "CMD",       action = act.DecreaseFontSize },
    { key = "0", mods = "CMD",       action = act.ResetFontSize },
  },
}
