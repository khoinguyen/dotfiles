local wezterm = require 'wezterm'

function compute_scheme()
  local hour = tonumber(wezterm.strftime("%H"));
  if hour >= 7 and hour <= 20 then
    return "Builtin Solarized Light";
  end
  return "Builtin Solarized Dark";
end

wezterm.on("update-right-status", function(window, pane)
  local overrides = window:get_config_overrides() or {}
  local color_scheme = compute_scheme()
  if overrides.color_scheme ~= color_scheme then
    overrides.color_scheme = color_scheme
    window:set_config_overrides(overrides)
  end
end)

return {
  color_scheme = compute_scheme()
}
