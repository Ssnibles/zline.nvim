--- Fast, modular statusline plugin for Neovim
--- @module 'zline'

local config = require("zline.config")
local highlights = require("zline.highlights")
local git = require("zline.git")
local cmdline = require("zline.cmdline")
local components = require("zline.components")

local M = {}

--- Expose configuration options table
M.opts = config.options

--- Evaluates a component group, constructing formatted statusline items and calculating visual width.
--- @param section_components StatuslineComponent[]
--- @return string formatted_segment The concatenated statusline segment string
--- @return integer visual_width Total visual display width in cells
local function evaluate_section(section_components)
	local rendered_items = {}
	local visual_width = 0
	for _, component in ipairs(section_components) do
		local component_text = component.render()
		if component_text then
			local highlight_group = component.hl()
			table.insert(rendered_items, "%#" .. highlight_group .. "#" .. component_text .. "%#StlBar#")
			local clean_text = component_text
			if component_text:find("%", 1, true) then
				clean_text = component_text:gsub("%%#[^#]*#", ""):gsub("%%%*", ""):gsub("%%%%", "%%")
			end
			visual_width = visual_width + vim.api.nvim_strwidth(clean_text)
		end
	end
	return table.concat(rendered_items), visual_width
end

--- Main statusline evaluation entry point called per window draw cycle
--- @return string formatted_statusline Statusline expression string
function M.statusline()
	-- Intercept active command-line mode (e.g. typing : command or / search)
	if config.options.cmdline_in_statusline and cmdline.is_active() then
		return cmdline.render()
	end

	local current_window = vim.api.nvim_get_current_win()
	local target_window = vim.g.statusline_winid

	-- Check for disabled filetypes or buffer types with O(1) set lookups
	local active_buf = (target_window and target_window ~= current_window and vim.api.nvim_win_is_valid(target_window))
			and vim.api.nvim_win_get_buf(target_window)
		or 0
	local file_type = vim.bo[active_buf].filetype
	local buffer_type = vim.bo[active_buf].buftype

	if config.disabled_filetypes_set[file_type] or config.disabled_buftypes_set[buffer_type] then
		return "%#StlBar#"
	end

	-- Handle inactive window splits with a clean, minimal statusline
	if target_window and target_window ~= current_window and vim.api.nvim_win_is_valid(target_window) then
		local buffer_name = vim.api.nvim_buf_get_name(active_buf)
		local relative_path = buffer_name ~= "" and vim.fs.normalize(vim.fn.fnamemodify(buffer_name, ":~:."))
			or "[No Name]"
		local current_line = vim.api.nvim_win_get_cursor(target_window)[1]
		local total_lines = vim.api.nvim_buf_line_count(active_buf)
		return "%#StlBarNC#%< "
			.. relative_path:gsub("%%", "%%%%")
			.. "%= "
			.. current_line
			.. "/"
			.. total_lines
			.. " %#StlBarNC#"
	end

	local left_segment, left_width = evaluate_section(components.left_components)
	local right_segment, right_width = evaluate_section(components.right_components)

	-- Calculate space remaining for filename component
	local non_filename_width = left_width + right_width
	-- `vim.g.statusline_winid` can be stale during window teardown; fall back to
	-- the current window rather than passing an invalid window id to the API.
	local window_width
	if target_window and vim.api.nvim_win_is_valid(target_window) then
		window_width = vim.api.nvim_win_get_width(target_window)
	else
		window_width = vim.api.nvim_win_get_width(current_window)
	end

	-- Calculate smooth available width for path truncation
	local available_width = math.max(10, window_width - non_filename_width - 1)
	local margin_right = (config.options.filename_opts and config.options.filename_opts.margin_right) or 6

	local filename_options = { avail = available_width, margin_right = margin_right }
	local filename_text = "%#StlFile#" .. components.filename.render(filename_options) .. "%#StlBar#"

	return "%#StlBar#" .. left_segment .. "%<" .. filename_text .. "%=" .. right_segment
end

--- Initialise zline statusline plugin
--- @param user_options? ZlineOpts Configuration overrides
function M.setup(user_options)
	if vim.fn.has("nvim-0.11") == 0 then
		vim.notify("zline.nvim requires Neovim 0.11 or newer", vim.log.levels.ERROR)
		return
	end

	config.setup(user_options)
	M.opts = config.options
	vim.g.zline_configured = true
	highlights.setup()

	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained", "BufWritePost", "TermClose", "ShellCmdPost" }, {
		group = vim.api.nvim_create_augroup("ZlineGitCache", { clear = true }),
		callback = function()
			git.clear_cache()
		end,
	})

	vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
		group = vim.api.nvim_create_augroup("ZlineMacro", { clear = true }),
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})

	if config.options.cmdline_in_statusline then
		cmdline.setup()
	else
		cmdline.teardown()
	end

	vim.o.statusline = "%!v:lua.require('zline').statusline()"
end

return M
