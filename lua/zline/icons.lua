--- Safe icon resolution wrapper for mini.icons
--- @module 'zline.icons'

local config = require("zline.config")

local M = {}

local mini_icons_module = nil
local is_mini_loaded = false
local devicons_module = nil
local is_devicons_loaded = false

--- Safely retrieve an icon and highlight group from mini.icons or nvim-web-devicons
--- @param category string Category identifier ("file", "filetype", "extension", "directory")
--- @param name string Target identifier name
--- @return string|nil icon The resolved icon glyph, or nil if unassigned
--- @return string|nil hl The associated highlight group name, or nil
function M.get_icon(category, name)
	if not config.options.use_icons or not name or name == "" then
		return nil, nil
	end

	-- 1. Try mini.icons
	if not is_mini_loaded then
		local is_available, module = pcall(require, "mini.icons")
		if is_available and type(module) == "table" and type(module.get) == "function" then
			mini_icons_module = module
		end
		is_mini_loaded = true
	end

	if mini_icons_module then
		local is_successful, icon_glyph, highlight_group, is_default = pcall(mini_icons_module.get, category, name)
		-- A generic default icon is treated as "no icon" so nvim-web-devicons gets a
		-- chance to provide a more specific glyph (when installed).
		if is_successful and icon_glyph and icon_glyph ~= "" and not is_default then
			return icon_glyph, highlight_group
		end
	end

	-- 2. Fallback to nvim-web-devicons
	if not is_devicons_loaded then
		local is_available, module = pcall(require, "nvim-web-devicons")
		if is_available and type(module) == "table" then
			devicons_module = module
		end
		is_devicons_loaded = true
	end

	if devicons_module then
		local icon, hl
		if category == "file" then
			local filename = vim.fs.basename(name)
			local ext = vim.fn.fnamemodify(filename, ":e")
			icon, hl = devicons_module.get_icon(filename, ext, { default = false })
		elseif category == "filetype" and devicons_module.get_icon_by_filetype then
			icon, hl = devicons_module.get_icon_by_filetype(name, { default = false })
		end
		if icon and icon ~= "" then
			return icon, hl
		end
	end

	return nil, nil
end

return M
