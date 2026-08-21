--- Safe icon resolution wrapper for mini.icons
--- @module 'zline.icons'

local config = require("zline.config")

local M = {}

local mini_icons_module = nil
local is_mini_loaded = false

--- Safely retrieve an icon and highlight group from mini.icons
--- @param category string Category identifier ("file", "filetype", "extension", "directory")
--- @param name string Target identifier name
--- @return string|nil icon The resolved icon glyph, or nil if unassigned
--- @return string|nil hl The associated highlight group name, or nil
function M.get_icon(category, name)
	if not config.options.use_icons or not name or name == "" then
		return nil, nil
	end

	if not is_mini_loaded then
		local is_available, module = pcall(require, "mini.icons")
		if is_available and type(module) == "table" and type(module.get) == "function" then
			mini_icons_module = module
		end
		is_mini_loaded = true
	end

	if mini_icons_module then
		local is_successful, icon_glyph, highlight_group = pcall(mini_icons_module.get, category, name)
		if is_successful and icon_glyph and icon_glyph ~= "" then
			-- Filter out generic default symbol returned by mini.icons when category key is absent
			local default_glyph = mini_icons_module.config and mini_icons_module.config.default
			if type(default_glyph) == "string" and icon_glyph == default_glyph then
				return nil, nil
			end
			return icon_glyph, highlight_group
		end
	end

	return nil, nil
end

return M
