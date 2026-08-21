--- Highlight group initialisation and colour palette management
--- @module 'zline.highlights'

local M = {}

--- Default fallback highlight group link definitions
--- @type table<string, string>
local default_highlight_links = {
	StlBar = "StatusLine",
	StlBarNC = "StatusLineNC",
	StlModeN = "StatusLine",
	StlModeI = "ModeMsg",
	StlModeV = "Visual",
	StlModeC = "Command",
	StlModeS = "Select",
	StlModeT = "Terminal",
	StlModeR = "Replace",
	StlGit = "StlBar",
	StlGitAdd = "GitSignsAdd",
	StlGitChange = "GitSignsChange",
	StlGitDelete = "GitSignsDelete",
	StlDiag = "DiagnosticError",
	StlSearch = "IncSearch",
	StlWarn = "WarningMsg",
	StlFile = "StlBar",
	StlFT = "StlBar",
	StlPos = "StlBar",
	StlMacro = "WarningMsg",
	StlSelection = "Visual",
	StlDap = "DiagnosticWarn",
	StlCmdPos = "Cursor",
	StlCmdText = "StlBar",
	StlCmdInfo = "Comment",
}

local is_autocmd_setup = false
local last_bar_bg = nil

--- Synchronise normal statusline module backgrounds with StlBar background
function M.sync_bar_background()
	local bar_hl = vim.api.nvim_get_hl(0, { name = "StlBar", link = false })
	if bar_hl.bg and bar_hl.bg ~= last_bar_bg then
		local bar_linked_groups = {
			"StlGit",
			"StlGitAdd",
			"StlGitChange",
			"StlGitDelete",
			"StlFile",
			"StlFT",
			"StlPos",
			"StlCmdText",
			"StlCmdPrompt",
			"StlSearchPrompt",
			"StlCmdInfo",
		}
		for _, hl_name in ipairs(bar_linked_groups) do
			local hl_def = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
			hl_def.bg = bar_hl.bg
			hl_def.default = nil
			vim.api.nvim_set_hl(0, hl_name, hl_def)
		end
		last_bar_bg = bar_hl.bg
	end
end

--- Initialise highlight groups and derive foreground colours for prompt icons
function M.setup()
	last_bar_bg = nil
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

	M.sync_bar_background()

	if not is_autocmd_setup then
		is_autocmd_setup = true
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("ZlineHighlights", { clear = true }),
			callback = function()
				M.setup()
			end,
		})
	end
end

return M
