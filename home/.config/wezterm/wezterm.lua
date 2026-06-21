local wezterm = require("wezterm")
local act = wezterm.action

local FONT_SIZE = 16.0

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
      { Background = { Color = "#313244" } },
      { Foreground = { Color = "#cba6f7" } },
      { Attribute = { Intensity = "Bold" } },
      { Text = " " .. display .. " " },
    }
  end
  return {
    { Background = { Color = "#1e1e2e" } },
    { Foreground = { Color = "#6c7086" } },
    { Text = " " .. display .. " " },
  }
end)

return {
  -- ─── Font ────────────────────────────────────────────────────────────────
  font = wezterm.font_with_fallback({
    "MesloLGS NF",
    "MesloLGS Nerd Font Mono",
    "MesloLGS Nerd Font",
    "Menlo",
  }),
  font_size = FONT_SIZE,

  -- ─── Color ───────────────────────────────────────────────────────────────
  color_scheme = "Catppuccin Mocha",

  -- ─── Tab Bar ─────────────────────────────────────────────────────────────
  enable_tab_bar = true,
  use_fancy_tab_bar = false,
  tab_bar_at_bottom = true,
  tab_max_width = 30,
  colors = {
    tab_bar = {
      background = "#1e1e2e",
      active_tab = {
        bg_color = "#313244",
        fg_color = "#cba6f7",
        intensity = "Bold",
      },
      inactive_tab = {
        bg_color = "#1e1e2e",
        fg_color = "#6c7086",
      },
      inactive_tab_hover = {
        bg_color = "#181825",
        fg_color = "#a6adc8",
      },
      new_tab = {
        bg_color = "#1e1e2e",
        fg_color = "#585b70",
      },
    },
  },

  -- ─── Window ──────────────────────────────────────────────────────────────
  window_decorations = "RESIZE",
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

    -- Claude ワークスペース起動 (新タブで cc-workspace 実行)
    -- Cmd+Shift+K: 現在ディレクトリでワークスペース起動
    {
      key = "k",
      mods = "CMD|SHIFT",
      action = act.SpawnCommandInNewTab({
        args = { "/bin/zsh", "-lc", "$HOME/.config/tmux/scripts/cc-workspace.sh" },
      }),
    },

    -- クリップボード
    { key = "c", mods = "CMD", action = act.CopyTo("Clipboard") },
    { key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },

    -- フォントサイズ
    { key = "+", mods = "CMD",       action = act.IncreaseFontSize },
    { key = "-", mods = "CMD",       action = act.DecreaseFontSize },
    { key = "0", mods = "CMD",       action = act.ResetFontSize },
  },
}
