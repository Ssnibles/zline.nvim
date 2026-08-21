local M = {}

M.opts = {
	use_icons = true,
	colored_diff = true,
	icons = {
		git = "",
		error = "󰅚",
		warn = "󰀦",
		add = "+",
		change = "~",
		delete = "-",
	},
	filename_opts = { margin_right = 6 },
}

local MiniIcons = nil
local mini_loaded = false

--- Safely retrieve icon from mini.icons
---@param category string Category name ("file", "filetype", "extension", "directory", etc.)
---@param name string Name/identifier
---@return string|nil icon
---@return string|nil hl
local function get_icon(category, name)
	if not M.opts.use_icons or not name or name == "" then
		return nil, nil
	end
	if not mini_loaded then
		local ok, mod = pcall(require, "mini.icons")
		if ok and type(mod) == "table" and type(mod.get) == "function" then
			MiniIcons = mod
		end
		mini_loaded = true
	end
	if MiniIcons then
		local ok, icon, hl = pcall(MiniIcons.get, category, name)
		if ok and icon and icon ~= "" then
			-- Filter out generic default symbol returned by mini.icons when key is not found
			local default = MiniIcons.config and MiniIcons.config.default
			if type(default) == "string" and icon == default then
				return nil, nil
			end
			return icon, hl
		end
	end
	return nil, nil
end

local git_cache = {}

--- Fast resolution of Git branch name with zero-process .git/HEAD fallback
---@return string|nil branch_name
local function get_git_head()
	-- 1. Use gitsigns buffer variable if available
	local head = vim.b.gitsigns_head
	if head and head ~= "" then return head end

	-- 2. Fast fallback via .git/HEAD reading
	local bufname = vim.api.nvim_buf_get_name(0)
	local dir = bufname ~= "" and vim.fs.dirname(bufname) or vim.uv.cwd()
	if not dir then return nil end

	if git_cache[dir] ~= nil then
		return git_cache[dir] ~= false and git_cache[dir] or nil
	end

	local git_root = vim.fs.find(".git", { upward = true, path = dir })[1]
	if not git_root then
		git_cache[dir] = false
		return nil
	end

	local head_file = git_root .. "/HEAD"
	local attr = vim.uv.fs_stat(git_root)
	if attr and attr.type == "file" then
		local f = io.open(git_root, "r")
		if f then
			local first_line = f:read("*l") or ""
			f:close()
			local gitdir = first_line:match("gitdir:%s*(.+)")
			if gitdir then
				if not gitdir:match("^/") then
					gitdir = vim.fs.normalize(git_root:sub(1, -6) .. "/" .. gitdir)
				end
				head_file = gitdir .. "/HEAD"
			end
		end
	end

	local f = io.open(head_file, "r")
	if f then
		local line = f:read("*l") or ""
		f:close()
		local branch = line:match("ref: refs/heads/(.+)") or (line ~= "" and line:sub(1, 7) or nil)
		git_cache[dir] = branch or false
		return branch
	end

	git_cache[dir] = false
	return nil
end

---@class StatuslineComponent
---@field render function(opts?: table): string|nil Function that returns formatted component text or nil if hidden
---@field hl function(): string Function returning the highlight group name for the component

--- Map Neovim raw mode strings to concise statusline display indicators.
--- Note: '\x16' is Ctrl-V (Visual Block) and '\x13' is Ctrl-S (Select Block).
---@type table<string, string>
local mode_map = {
	n = "N", i = "I", v = "V", V = "V",
	["\x16"] = "V", c = "C", s = "S", S = "S",
	["\x13"] = "S", t = "T", R = "R", r = "R",
	["!"] = "!", rm = "R",
}

--- Map Neovim raw mode strings directly to custom highlight groups.
---@type table<string, string>
local hl_map = {
	n = "StlModeN", i = "StlModeI", v = "StlModeV", V = "StlModeV",
	["\x16"] = "StlModeV", c = "StlModeC", s = "StlModeS", S = "StlModeS",
	["\x13"] = "StlModeS", t = "StlModeT", R = "StlModeR", r = "StlModeR",
	["!"] = "StlModeC", rm = "StlModeR",
}

--- Constructor helper for statusline components.
---@param render_fn fun(opts?: table): string|nil
---@param hl_fn fun(): string
---@return StatuslineComponent
local function component(render_fn, hl_fn)
	return { render = render_fn, hl = hl_fn }
end

local cached_mode = "n"
local mode = component(
	function()
		cached_mode = vim.api.nvim_get_mode().mode
		return " " .. (mode_map[cached_mode] or "?") .. " "
	end,
	function()
		return hl_map[cached_mode] or "StlModeN"
	end
)

--- Macro Recording Indicator Component
--- Displays active recording register when recording macros (e.g., 󰑋 @q)
local macro = component(
	function()
		local reg = vim.fn.reg_recording()
		if reg == "" then return nil end
		local icon = M.opts.use_icons and "󰑋 " or "REC "
		return " " .. icon .. "@" .. reg .. " "
	end,
	function() return "StlMacro" end
)

--- Git Status Component
--- Integrates directly with Gitsigns buffer variables (`vim.b.gitsigns_*`) with instant .git/HEAD fallback.
--- Supports colored diff indicators (green for added, yellow for changed, red for deleted).
local git = component(
	function()
		local head = get_git_head()
		if not head or head == "" then return nil end

		local icon = M.opts.use_icons and (M.opts.icons and M.opts.icons.git or "") or ""
		local icon_str = icon ~= "" and (icon .. " ") or ""

		local diff_str = ""
		local gdict = vim.b.gitsigns_status_dict
		if M.opts.colored_diff and gdict then
			local added = gdict.added or 0
			local changed = gdict.changed or 0
			local removed = gdict.removed or 0

			local parts = {}
			if added > 0 then
				local add_symbol = (M.opts.icons and M.opts.icons.add) or "+"
				table.insert(parts, "%#StlGitAdd#" .. add_symbol .. added .. "%#StlGit#")
			end
			if changed > 0 then
				local change_symbol = (M.opts.icons and M.opts.icons.change) or "~"
				table.insert(parts, "%#StlGitChange#" .. change_symbol .. changed .. "%#StlGit#")
			end
			if removed > 0 then
				local delete_symbol = (M.opts.icons and M.opts.icons.delete) or "-"
				table.insert(parts, "%#StlGitDelete#" .. delete_symbol .. removed .. "%#StlGit#")
			end
			if #parts > 0 then
				diff_str = " " .. table.concat(parts, " ")
			end
		else
			local status = vim.b.gitsigns_status
			if status and status ~= "" then
				diff_str = " " .. status
			end
		end

		return " " .. icon_str .. head .. diff_str
	end,
	function() return "StlGit" end
)

--- LSP Diagnostics Summary Component
--- Counts errors and warnings using native `vim.diagnostic.count` and mini.icons.
local diagnostics = component(
	function()
		local counts = vim.diagnostic.count(0)
		local err = counts[vim.diagnostic.severity.ERROR] or 0
		local warn = counts[vim.diagnostic.severity.WARN] or 0

		if err == 0 and warn == 0 then return nil end

		local err_icon, warn_icon
		if M.opts.use_icons then
			err_icon = (M.opts.icons and M.opts.icons.error) or "󰅚"
			warn_icon = (M.opts.icons and M.opts.icons.warn) or "󰀦"
		else
			err_icon = "×"
			warn_icon = "▲"
		end

		local parts = {}
		if err > 0 then table.insert(parts, err_icon .. " " .. err) end
		if warn > 0 then table.insert(parts, warn_icon .. " " .. warn) end
		return " " .. table.concat(parts, " ")
	end,
	function() return "StlDiag" end
)

--- Dynamic Filename Component
--- Dynamically truncates path segments right-to-left if width exceeds available budget, with mini.icons support.
---@class FilenameOpts
---@field avail integer Available horizontal character width allocated for the filename
---@field margin_right? integer Safety margin subtracted from available width

local filename = component(
	---@param opts FilenameOpts
	function(opts)
		local target = math.max(10, opts.avail - (opts.margin_right or 0))
		local bufname = vim.api.nvim_buf_get_name(0)

		if bufname == "" then return " [No Name] " end

		local modified = vim.bo.modified and " +" or ""
		local readonly = vim.bo.readonly and " =" or ""
		local suf = modified .. readonly

		local icon = get_icon("file", bufname) or get_icon("filetype", vim.bo.filetype)
		local icon_str = icon and (icon .. " ") or ""

		-- Format absolute path to relative path using canonical forward slashes
		local rel = vim.fs.normalize(vim.fn.fnamemodify(bufname, ":."))

		-- Use full relative path if it fits within target width
		if vim.fn.strwidth(icon_str .. rel) + #suf <= target then
			return " " .. icon_str .. rel .. suf .. " "
		end

		-- Progressive truncation: reconstruct path backwards segment by segment
		local parts = vim.split(rel, "/")
		local result = ""
		for i = #parts, 1, -1 do
			local candidate = parts[i] .. (result ~= "" and "/" or "") .. result
			if vim.fn.strwidth(icon_str .. "…/" .. candidate .. suf) <= target then
				result = candidate
			else
				break
			end
		end

		-- Fallback to last segment (filename only) if even one parent folder doesn't fit
		return " " .. icon_str .. "…/" .. (result ~= "" and result or parts[#parts]) .. suf .. " "
	end,
	function() return "StlFile" end
)

--- Active LSP Clients Component
--- Lists attached language servers for current buffer.
local lsp = component(
	function()
		local clients = vim.lsp.get_clients({ bufnr = 0 })
		if #clients == 0 then return nil end

		local names = {}
		for _, client in ipairs(clients) do
			table.insert(names, client.name)
		end
		return " " .. table.concat(names, ",") .. " "
	end,
	function() return "StlLSP" end
)

--- Filetype Indicator Component
--- Displays filetype with mini.icons filetype icon.
local filetype = component(
	function()
		local ft = vim.bo.filetype
		if ft == "" then return nil end
		local icon = get_icon("filetype", ft)
		local icon_str = icon and (icon .. " ") or ""
		return " " .. icon_str .. ft .. " "
	end,
	function() return "StlFT" end
)

--- Cursor Position Component
--- Format: CurrentLine / TotalLines (e.g., 42/150)
local position = component(
	function()
		-- Fast C-API calls avoiding VimScript evaluation overhead
		local current_line = vim.api.nvim_win_get_cursor(0)[1]
		local total_lines = vim.api.nvim_buf_line_count(0)
		return " " .. current_line .. "/" .. total_lines .. " "
	end,
	function() return "StlPos" end
)

---@type StatuslineComponent[]
local left_bar = { mode, macro, git, diagnostics }

---@type StatuslineComponent[]
local right_bar = { lsp, filetype, position }

--- Ensure default fallback highlight groups exist without overriding user colors
local function setup_highlights()
	local default_links = {
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
		StlFile = "StatusLine",
		StlFT = "StatusLine",
		StlPos = "StatusLine",
		StlMacro = "WarningMsg",
	}
	for group, link in pairs(default_links) do
		vim.api.nvim_set_hl(0, group, { default = true, link = link })
	end
end

--- Main Statusline Evaluation Function
--- Called by Neovim per window draw cycle via `%!v:lua...` string setting.
---@return string Statusline expression string
function M.statusline()
	local cur_win = vim.api.nvim_get_current_win()
	local stl_win = vim.g.statusline_winid

	-- Handle inactive window splits with a clean, minimal statusline
	if stl_win and stl_win ~= cur_win then
		local bufname = vim.api.nvim_buf_get_name(0)
		local rel = bufname ~= "" and vim.fs.normalize(vim.fn.fnamemodify(bufname, ":.")) or "[No Name]"
		local current_line = vim.api.nvim_win_get_cursor(0)[1]
		local total_lines = vim.api.nvim_buf_line_count(0)
		return "%#StatusLineNC# " .. rel .. "%= " .. current_line .. "/" .. total_lines .. " %*"
	end

	--- Evaluates a component group, constructing formatted statusline items and calculating visual width.
	---@param section StatuslineComponent[]
	---@return string formatted_str The concatenated statusline segment string
	---@return integer width Visual width in display cells
	local function collect(section)
		local items = {}
		local width = 0
		for _, c in ipairs(section) do
			local text = c.render()
			if text then
				local hl = c.hl()
				-- Embed highlight group switch (%#Group#) and highlight reset (%*) directly
				table.insert(items, "%#" .. hl .. "#" .. text .. "%*")
				-- Strip embedded highlight codes before computing cell width
				local clean_text = (text:gsub("%%#[^#]*#", ""))
				width = width + vim.fn.strwidth(clean_text)
			end
		end
		return table.concat(items), width
	end

	local left_str, left_width = collect(left_bar)
	local right_str, right_width = collect(right_bar)

	-- Calculate space remaining for filename component
	local non_filename = left_width + right_width
	local win_width = vim.api.nvim_win_get_width(0)

	-- Quantize available space down to steps of 5 for visually predictable truncation shifts
	local avail = math.max(10, math.floor((win_width - non_filename - 1) / 5) * 5)

	local file_opts = vim.tbl_extend("keep", { avail = avail }, M.opts.filename_opts or { margin_right = 6 })
	local file_text = "%#StlFile#" .. filename.render(file_opts) .. "%*"

	-- %<: Truncate point if statusline overflows screen width
	-- %=: Right-align separation point
	return left_str .. "%<" .. file_text .. "%=" .. right_str
end

--- Configure zline statusline plugin
---@param opts? table
function M.setup(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", M.opts, opts)
	if opts.mode_map then
		mode_map = vim.tbl_extend("force", mode_map, opts.mode_map)
	end
	if opts.hl_map then
		hl_map = vim.tbl_extend("force", hl_map, opts.hl_map)
	end

	setup_highlights()

	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained" }, {
		group = vim.api.nvim_create_augroup("ZlineGitCache", { clear = true }),
		callback = function()
			git_cache = {}
		end,
	})

	vim.o.statusline = "%!v:lua.require('zline').statusline()"
end

return M
