--- Embedded command-line and search input renderer using Neovim UI attachment
--- @module 'zline.cmdline'

local config = require("zline.config")

local M = {}

local is_cmdline_active = false

--- @class CmdlineData
--- @field firstc string Prompt character (:, /, ?, =, @)
--- @field content string Current typed text content
--- @field pos integer 1-indexed cursor character position
local cmdline_data = {
	firstc = ":",
	content = "",
	pos = 1,
}

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

--- Check whether command-line mode is currently active
--- @return boolean is_active
function M.is_active()
	return is_cmdline_active
end

--- Render embedded command-line or search input bar for statusline
--- @return string formatted_statusline
function M.render()
	local prompt_character = cmdline_data.firstc or ":"
	local line_content = cmdline_data.content or ""
	local cursor_position = cmdline_data.pos or 1

	local left_part = vim.fn.strcharpart(line_content, 0, cursor_position - 1)
	local current_character = vim.fn.strcharpart(line_content, cursor_position - 1, 1)
	if current_character == "" then current_character = " " end
	local right_part = vim.fn.strcharpart(line_content, cursor_position)

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
			local is_ok, search_result = pcall(vim.fn.searchcount, { pattern = line_content, maxcount = 999, timeout = 50 })
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
	end

	local prompt_segment = "%#" .. highlight_group .. "# " .. icon_symbol .. " %#StlCmdText#"
	local content_segment = " " .. left_part .. "%#StlCmdPos#" .. current_character .. "%#StlCmdText#" .. right_part .. "%#StlBar#"
	local info_segment = "%#StlCmdInfo# " .. type_label .. " %#StlBar#"

	return "%#StlBar#" .. prompt_segment .. content_segment .. "%=" .. info_segment
end

--- Initialise vim.ui_attach ext_cmdline listener for command-line interception
function M.setup()
	local namespace_id = vim.api.nvim_create_namespace("zline_cmdline")
	pcall(vim.ui_attach, namespace_id, { ext_cmdline = true }, function(event_name, ...)
		if event_name == "cmdline_show" then
			local content_chunks = select(1, ...)
			local text_segments = {}
			for _, chunk in ipairs(content_chunks or {}) do
				if type(chunk) == "table" and chunk[2] then
					table.insert(text_segments, chunk[2])
				end
			end
			cmdline_data.content = table.concat(text_segments)
			cmdline_data.pos = (select(2, ...) or 0) + 1
			local firstc = select(3, ...)
			cmdline_data.firstc = (firstc and firstc ~= "") and firstc or ":"
			is_cmdline_active = true
			schedule_redraw()
		elseif event_name == "cmdline_pos" then
			cmdline_data.pos = (select(1, ...) or 0) + 1
			schedule_redraw()
		elseif event_name == "cmdline_hide" then
			is_cmdline_active = false
			schedule_redraw()
		end
	end)
end

return M
