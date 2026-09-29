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

--- Accumulated context lines for a command-line block (e.g. interactive `:function`)
local block_lines = {}

--- Pending redraw flag to coalesce multiple schedule calls within the same event loop tick
local redraw_pending = false

--- Schedule a statusline redraw safely from fast UI-attach callback contexts
local function schedule_redraw()
	if redraw_pending then
		return
	end
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

--- Extract the plain text from a list of ext_cmdline content chunks
--- @param chunks? table List of `[attrs, text, hl_id]` chunks
--- @return string
local function extract_text(chunks)
	local segments = {}
	for _, chunk in ipairs(chunks or {}) do
		if type(chunk) == "table" and chunk[2] then
			table.insert(segments, chunk[2])
		end
	end
	return table.concat(segments)
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
	if current_character == "" then
		current_character = " "
	end
	local right_part = vim.fn.strcharpart(line_content, char_pos + 1)

	-- A special char (e.g. after <C-V>) is shown at the cursor until the next
	-- cmdline_show event. It overwrites the cursor char unless `shift` is set.
	local cursor_display = escape_stl(current_character)
	local special_char = active_data.special_char
	if special_char and special_char ~= "" then
		if active_data.special_shift then
			cursor_display = escape_stl(special_char) .. escape_stl(current_character)
		else
			cursor_display = escape_stl(special_char)
		end
	end

	local icon_symbol = (config.options.icons and config.options.icons.cmd) or ">"
	local type_label = "COMMAND"
	local highlight_group = config.options.cmdline_prompt_bg and "StlModeC" or "StlCmdPrompt"

	if prompt_character == "/" or prompt_character == "?" then
		icon_symbol = config.options.use_icons and (config.options.icons and config.options.icons.search or "󰍉")
			or prompt_character
		highlight_group = config.options.cmdline_prompt_bg and "StlSearch" or "StlSearchPrompt"

		-- Compute live search match count for the pattern being typed
		local direction_label = prompt_character == "/" and "FWD" or "BWD"
		if line_content ~= "" then
			local is_ok, search_result =
				pcall(vim.fn.searchcount, { pattern = line_content, maxcount = 999, timeout = 25 })
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

	-- Surface the number of context lines when a command-line block is active
	if #block_lines > 0 then
		type_label = type_label .. " [" .. #block_lines .. "L]"
	end

	local prompt_segment = "%#" .. highlight_group .. "# " .. escape_stl(icon_symbol) .. " %#StlCmdText#"
	local content_segment = " "
		.. escape_stl(left_part)
		.. "%#StlCmdPos#"
		.. cursor_display
		.. "%#StlCmdText#"
		.. escape_stl(right_part)
		.. "%#StlBar#"
	local info_segment = "%#StlCmdInfo# " .. escape_stl(type_label) .. " %#StlBar#"

	-- `%<` truncates the typed content (not the prompt or the right-aligned info)
	return "%#StlBar#" .. prompt_segment .. "%<" .. content_segment .. "%=" .. info_segment
end

--- Detach vim.ui_attach ext_cmdline listener
function M.teardown()
	if not is_attached then
		return
	end
	pcall(vim.ui_detach, namespace_id)
	is_attached = false
	is_cmdline_active = false
	cmdline_stack = {}
	block_lines = {}
	active_level = 0
end

--- Initialise vim.ui_attach ext_cmdline listener for command-line interception
function M.setup()
	if is_attached then
		return
	end

	--- @param event_name string
	local function on_ui_event(event_name, ...)
		if event_name == "cmdline_show" then
			local content_chunks = select(1, ...)
			local level = select(6, ...) or 1
			local firstc = select(3, ...)
			local prompt = select(4, ...)

			cmdline_stack[level] = {
				content = extract_text(content_chunks),
				pos = select(2, ...) or 0,
				firstc = (firstc and firstc ~= "") and firstc or ":",
				prompt = prompt,
				special_char = nil,
				special_shift = false,
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
		elseif event_name == "cmdline_special_char" then
			local level = select(3, ...) or active_level
			local entry = cmdline_stack[level]
			if entry then
				entry.special_char = select(1, ...)
				entry.special_shift = select(2, ...) and true or false
			end
			schedule_redraw()
		elseif event_name == "cmdline_block_show" then
			local lines = select(1, ...)
			block_lines = {}
			for _, line in ipairs(lines or {}) do
				table.insert(block_lines, extract_text(line))
			end
			schedule_redraw()
		elseif event_name == "cmdline_block_append" then
			table.insert(block_lines, extract_text(select(1, ...)))
			schedule_redraw()
		elseif event_name == "cmdline_block_hide" then
			block_lines = {}
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
	end

	local attached_ok, attach_error = pcall(vim.ui_attach, namespace_id, { ext_cmdline = true }, on_ui_event)
	is_attached = attached_ok
	if not attached_ok then
		vim.notify("zline.nvim: failed to attach cmdline listener: " .. tostring(attach_error), vim.log.levels.WARN)
	end
end

return M
