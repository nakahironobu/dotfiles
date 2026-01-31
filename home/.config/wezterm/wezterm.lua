local wezterm = require("wezterm")

-- BEGIN OAI MANAGED: WEZTERM LAYOUT
local FONT_SIZE = 16.0

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
-- END OAI MANAGED: WEZTERM LAYOUT
local FONT_SIZE = 16.0

return {
	font = wezterm.font_with_fallback({
    "MesloLGS NF",
    "MesloLGS Nerd Font Mono",
    "MesloLGS Nerd Font",
    "MesloLGS NF",
    "Menlo",
  }),
	font_size = FONT_SIZE,

	color_scheme = "Catppuccin Mocha",
	enable_tab_bar = true,
	use_fancy_tab_bar = false,

	window_decorations = "RESIZE",
	macos_window_background_blur = 0,

	keys = {
		{ key = "t", mods = "CMD", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
		{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
	},
}
