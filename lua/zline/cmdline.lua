--- Embedded command-line and search input renderer using Neovim UI attachment
--- @module 'zline.cmdline'

local config = require("zline.config")

local M = {}

local is_cmdline_active = false
local is_attached = false
local namespace_id = vim.api.nvim_create_namespace("zline_cmdline")

--- @class CmdlineData
--- @field firstc string Prompt character (:, /, ?, =, @)
--- @field prompt? string Input prompt text (e.g. for input())
--- @field content string Current typed text content
--- @field pos integer 0-indexed cursor byte position
local cmdline_stack = {}
local active_level = 0

--- Pending redraw flag to coalesce multiple schedule calls within the same event loop tick
local redraw_pending = false

--- Schedule a statusline redraw safely from fast UI-attach callback contexts
local function schedule_redraw()
	if redraw_pending then return end
	redraw_pending = true
	vim.schedule(function()
		redraw_pending = false
		vim.cmd("redrawstatus")
	end)
end

--- Escape percent symbols for safe statusline interpolation
--- @param str string
--- @return string
local function escape_stl(str)
	return (str:gsub("%%", "%%%%"))
end

--- Check whether command-line mode is currently active
--- @return boolean is_active
function M.is_active()
	return is_cmdline_active
end

--- Render embedded command-line or search input bar for statusline
--- @return string formatted_statusline
function M.render()
	local active_data = cmdline_stack[active_level] or {}
	local prompt_character = active_data.firstc or ":"
	local custom_prompt = active_data.prompt
	local line_content = active_data.content or ""
	local byte_pos = active_data.pos or 0

	-- Convert byte offset to character index for multibyte UTF-8 cursor positioning
	local char_pos = vim.fn.charidx(line_content, byte_pos)
	if char_pos < 0 then
		char_pos = vim.fn.strchars(line_content)
	end

	local left_part = vim.fn.strcharpart(line_content, 0, char_pos)
	local current_character = vim.fn.strcharpart(line_content, char_pos, 1)
	if current_character == "" then current_character = " " end
	local right_part = vim.fn.strcharpart(line_content, char_pos + 1)

	local icon_symbol = (config.options.icons and config.options.icons.cmd) or ">"
	local type_label = "COMMAND"
	local highlight_group = config.options.cmdline_prompt_bg and "StlModeC" or "StlCmdPrompt"

	if prompt_character == "/" or prompt_character == "?" then
		icon_symbol = config.options.use_icons
			and (config.options.icons and config.options.icons.search or "󰍉")
			or prompt_character
		highlight_group = config.options.cmdline_prompt_bg and "StlSearch" or "StlSearchPrompt"

		-- Compute live search match count for the pattern being typed
		local direction_label = prompt_character == "/" and "FWD" or "BWD"
		if line_content ~= "" then
			local is_ok, search_result = pcall(vim.fn.searchcount, { pattern = line_content, maxcount = 999, timeout = 25 })
			if is_ok and search_result and search_result.total then
				if search_result.total > 0 then
					type_label = search_result.current .. "/" .. search_result.total .. " " .. direction_label
				else
					type_label = "NO MATCH"
				end
			else
				type_label = "SEARCH " .. direction_label
			end
		else
			type_label = "SEARCH " .. direction_label
		end
	elseif prompt_character == "=" then
		icon_symbol = "="
		type_label = "EXPRESSION"
	elseif prompt_character == "@" then
		icon_symbol = "@"
		type_label = "INPUT"
	elseif (prompt_character == "" or prompt_character == ":") and custom_prompt and custom_prompt ~= "" then
		icon_symbol = vim.trim(custom_prompt)
		type_label = "PROMPT"
	end

	local prompt_segment = "%#" .. highlight_group .. "# " .. escape_stl(icon_symbol) .. " %#StlCmdText#"
	local content_segment = " " .. escape_stl(left_part) .. "%#StlCmdPos#" .. escape_stl(current_character) .. "%#StlCmdText#" .. escape_stl(right_part) .. "%#StlBar#"
	local info_segment = "%#StlCmdInfo# " .. escape_stl(type_label) .. " %#StlBar#"

	return "%#StlBar#" .. prompt_segment .. content_segment .. "%=" .. info_segment
end

--- Detach vim.ui_attach ext_cmdline listener
function M.teardown()
	if not is_attached then return end
	pcall(vim.ui_detach, namespace_id)
	is_attached = false
	is_cmdline_active = false
	cmdline_stack = {}
	active_level = 0
end

--- Initialise vim.ui_attach ext_cmdline listener for command-line interception
function M.setup()
	if is_attached then return end
	is_attached = true

	pcall(vim.ui_attach, namespace_id, { ext_cmdline = true }, function(event_name, ...)
		if event_name == "cmdline_show" then
			local content_chunks = select(1, ...)
			local text_segments = {}
			for _, chunk in ipairs(content_chunks or {}) do
				if type(chunk) == "table" and chunk[2] then
					table.insert(text_segments, chunk[2])
				end
			end
			local level = select(6, ...) or 1
			local firstc = select(3, ...)
			local prompt = select(4, ...)

			cmdline_stack[level] = {
				content = table.concat(text_segments),
				pos = select(2, ...) or 0,
				firstc = (firstc and firstc ~= "") and firstc or ":",
				prompt = prompt,
			}
			active_level = level
			is_cmdline_active = true
			schedule_redraw()
		elseif event_name == "cmdline_pos" then
			local level = select(2, ...) or active_level
			if cmdline_stack[level] then
				cmdline_stack[level].pos = select(1, ...) or 0
			end
			schedule_redraw()
		elseif event_name == "cmdline_hide" then
			local level = select(1, ...) or active_level
			cmdline_stack[level] = nil

			local max_level = 0
			for lvl in pairs(cmdline_stack) do
				if lvl > max_level then
					max_level = lvl
				end
			end

			if max_level > 0 then
				active_level = max_level
			else
				is_cmdline_active = false
				active_level = 0
			end
			schedule_redraw()
		end
	end)
end

return M
