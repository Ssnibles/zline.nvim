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

--- @class ZlineOpts
--- @field use_icons boolean Whether to display mini.icons or Nerd Font symbols
--- @field coloured_diff boolean Whether to render git diff counters in green, yellow, and red
--- @field cmdline_in_statusline boolean Whether to embed command-line input into statusline
--- @field cmdline_prompt_bg boolean Whether to display a solid background badge for command prompts
--- @field icons ZlineIcons Icon glyph mappings
--- @field filename_opts ZlineFilenameOpts Path truncation parameters

--- Default configuration options
--- @type ZlineOpts
M.defaults = {
	use_icons = true,
	coloured_diff = true,
	cmdline_in_statusline = true,
	cmdline_prompt_bg = false,
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
