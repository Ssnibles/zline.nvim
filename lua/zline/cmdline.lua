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

	if prompt_character == "/" then
		icon_symbol = config.options.use_icons and (config.options.icons and config.options.icons.search or "󰍉") or "/"
		type_label = "SEARCH FORWARD"
		highlight_group = config.options.cmdline_prompt_bg and "StlSearch" or "StlSearchPrompt"
	elseif prompt_character == "?" then
		icon_symbol = config.options.use_icons and (config.options.icons and config.options.icons.search or "󰍉") or "?"
		type_label = "SEARCH BACKWARD"
		highlight_group = config.options.cmdline_prompt_bg and "StlSearch" or "StlSearchPrompt"
	elseif prompt_character == "=" then
		icon_symbol = "="
		type_label = "EXPRESSION"
	elseif prompt_character == "@" then
		icon_symbol = "@"
		type_label = "INPUT"
	end

	local prompt_segment = "%#" .. highlight_group .. "# " .. icon_symbol .. " %*"
	local content_segment = " " .. left_part .. "%#StlCmdPos#" .. current_character .. "%* %#StlCmdText#" .. right_part .. "%*"
	local info_segment = "%#StlCmdInfo# " .. type_label .. " %*"

	return prompt_segment .. content_segment .. "%=" .. info_segment
end

--- Initialise vim.ui_attach ext_cmdline listener for command-line interception
function M.setup()
	local namespace_id = vim.api.nvim_create_namespace("zline_cmdline")
	pcall(vim.ui_attach, namespace_id, { ext_cmdline = true }, function(event_name, ...)
		local event_arguments = { ... }
		if event_name == "cmdline_show" then
			local content_chunks = event_arguments[1] or {}
			local text_segments = {}
			for _, chunk in ipairs(content_chunks) do
				if type(chunk) == "table" and chunk[2] then
					table.insert(text_segments, chunk[2])
				end
			end
			cmdline_data.content = table.concat(text_segments)
			cmdline_data.pos = (event_arguments[2] or 0) + 1
			cmdline_data.firstc = (event_arguments[3] and event_arguments[3] ~= "") and event_arguments[3] or ":"
			is_cmdline_active = true
			vim.cmd("redrawstatus")
		elseif event_name == "cmdline_pos" then
			cmdline_data.pos = (event_arguments[1] or 0) + 1
			vim.cmd("redrawstatus")
		elseif event_name == "cmdline_hide" then
			is_cmdline_active = false
			vim.cmd("redrawstatus")
		end
	end)
end

return M
