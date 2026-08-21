--- Highlight group initialisation and colour palette management
--- @module 'zline.highlights'

local M = {}

--- Default fallback highlight group link definitions
--- @type table<string, string>
local default_highlight_links = {
	StlModeN = "StatusLine",
	StlModeI = "ModeMsg",
	StlModeV = "Visual",
	StlModeC = "Command",
	StlModeS = "Select",
	StlModeT = "Terminal",
	StlModeR = "Replace",
	StlGit = "StatusLine",
	StlGitAdd = "GitSignsAdd",
	StlGitChange = "GitSignsChange",
	StlGitDelete = "GitSignsDelete",
	StlDiag = "DiagnosticError",
	StlSearch = "IncSearch",
	StlWarn = "WarningMsg",
	StlFile = "StatusLine",
	StlFT = "StatusLine",
	StlPos = "StatusLine",
	StlMacro = "WarningMsg",
	StlSelection = "Visual",
	StlDap = "DiagnosticWarn",
	StlCmdPos = "Cursor",
	StlCmdText = "StatusLine",
	StlCmdInfo = "Comment",
}

--- Initialise highlight groups and derive foreground colours for prompt icons
function M.setup()
	for highlight_group, target_link in pairs(default_highlight_links) do
		vim.api.nvim_set_hl(0, highlight_group, { default = true, link = target_link })
	end

	-- Extract accent foreground colour for StlCmdPrompt from StlModeC without filled background block
	local command_mode_hl = vim.api.nvim_get_hl(0, { name = "StlModeC", link = false })
	local command_prompt_fg = command_mode_hl.bg or command_mode_hl.fg
	if command_prompt_fg then
		vim.api.nvim_set_hl(0, "StlCmdPrompt", { fg = command_prompt_fg, bold = true, default = true })
	else
		vim.api.nvim_set_hl(0, "StlCmdPrompt", { link = "Statement", default = true })
	end

	-- Extract accent foreground colour for StlSearchPrompt from StlSearch / IncSearch without filled background block
	local search_mode_hl = vim.api.nvim_get_hl(0, { name = "StlSearch", link = false })
	if not search_mode_hl.bg and not search_mode_hl.fg then
		search_mode_hl = vim.api.nvim_get_hl(0, { name = "IncSearch", link = false })
	end
	local search_prompt_fg = search_mode_hl.bg or search_mode_hl.fg
	if search_prompt_fg then
		vim.api.nvim_set_hl(0, "StlSearchPrompt", { fg = search_prompt_fg, bold = true, default = true })
	else
		vim.api.nvim_set_hl(0, "StlSearchPrompt", { link = "IncSearch", default = true })
	end
end

return M
