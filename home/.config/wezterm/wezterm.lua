local wezterm = require("wezterm")

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	local gui = window:gui_window()

	local screens = wezterm.gui.screens()
	local s = screens.active or screens[1]

	local w = s.width
	local h = s.height

	-- サイズ：幅 2/5、高さ 1/2
	local inner_w = math.floor(w * 2 / 5)
	local inner_h = math.floor(h * 1 / 2)

	-- 位置：右寄せ,右端は少し空間,縦は中央より少し上
	local RIGHT_MARGIN = 24
	local x = math.floor(w - inner_w - RIGHT_MARGIN)

	-- 「少し上」をオフセットで表現（画面高の 8% 上げる）
	local y = math.floor((h - inner_h) / 2 - (h * 0.08))
	if x < 0 then
		x = 0
	end
	if y < 0 then
		y = 0
	end

	gui:set_position(x, y)
	gui:set_inner_size(inner_w, inner_h)
end)

return {
	font = wezterm.font("MesloLGS NF"),
	font_size = 18.0,

	color_scheme = "Builtin Solarized Dark",
	enable_tab_bar = true,
	use_fancy_tab_bar = false,

	window_decorations = "RESIZE",
	macos_window_background_blur = 0,

	keys = {
		{ key = "t", mods = "CMD", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
		{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
	},
}
