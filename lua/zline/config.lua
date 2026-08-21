--- Configuration management for zline.nvim
--- @module 'zline.config'

local M = {}

--- @class ZlineIcons
--- @field git string
--- @field error string
--- @field warn string
--- @field add string
--- @field change string
--- @field delete string
--- @field search string
--- @field warn_fmt string
--- @field cmd string
--- @field dap string
--- @field spell string

--- @class ZlineFilenameOpts
--- @field margin_right integer Safety margin subtracted from available horizontal width

--- @class ZlineShowOpts
--- @field mode? boolean Whether to render mode indicator badge
--- @field selection? boolean Whether to render visual selection metrics
--- @field macro? boolean Whether to render macro recording register indicator
--- @field search? boolean Whether to render active search match counter
--- @field git? boolean Whether to render git branch and diff summary
--- @field diagnostics? boolean Whether to render LSP diagnostics summary
--- @field filename? boolean Whether to render file path component
--- @field dap? boolean Whether to render active DAP debugger status
--- @field spell? boolean Whether to render active spell checking indicator
--- @field format_warn? boolean Whether to render format and encoding warning badges
--- @field lsp? boolean Whether to render active LSP client names
--- @field filetype? boolean Whether to render filetype badge
--- @field position? boolean Whether to render cursor position and line counts

--- @class ZlineOpts
--- @field use_icons boolean Whether to display mini.icons or Nerd Font symbols
--- @field coloured_diff boolean Whether to render git diff counters in green, yellow, and red
--- @field cmdline_in_statusline boolean Whether to embed command-line input into statusline
--- @field cmdline_prompt_bg boolean Whether to display a solid background badge for command prompts
--- @field disabled_filetypes string[] List of filetypes where the statusline is hidden
--- @field disabled_buftypes string[] List of buffer types where the statusline is hidden
--- @field show ZlineShowOpts Component visibility toggles
--- @field icons ZlineIcons Icon glyph mappings
--- @field filename_opts ZlineFilenameOpts Path truncation parameters

--- Default configuration options
--- @type ZlineOpts
M.defaults = {
	use_icons = true,
	coloured_diff = true,
	cmdline_in_statusline = true,
	cmdline_prompt_bg = false,
	disabled_filetypes = {
		"ministarter",
		"starter",
		"dashboard",
		"alpha",
		"snacks_dashboard",
		"snacks_starter",
	},
	disabled_buftypes = {},
	show = {
		mode = true,
		selection = true,
		macro = true,
		search = true,
		git = true,
		diagnostics = true,
		filename = true,
		dap = true,
		spell = true,
		format_warn = true,
		lsp = false,
		filetype = true,
		position = true,
	},
	icons = {
		git = "",
		error = "󰅚",
		warn = "󰀦",
		add = "+",
		change = "~",
		delete = "-",
		search = "󰍉",
		warn_fmt = "⚠",
		cmd = ">",
		dap = "󰃤",
		spell = "󰓆",
	},
	filename_opts = {
		margin_right = 6,
	},
}

--- Active runtime configuration options
--- @type ZlineOpts
M.options = vim.deepcopy(M.defaults)

--- Merge user configuration into active runtime options
--- @param user_options? table User configuration overrides
function M.setup(user_options)
	if not user_options then return end
	M.options = vim.tbl_deep_extend("force", M.options, user_options)
end

return M
