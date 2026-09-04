--- Individual statusline component renderers
--- @module 'zline.components'

local config = require("zline.config")
local icons = require("zline.icons")
local git = require("zline.git")

local M = {}

--- Special window and buffer type title mappings
--- @type table<string, string>
local special_buftypes = {
	quickfix = "Quickfix",
	help = "Help",
	terminal = "Terminal",
	prompt = "Prompt",
}

--- @type table<string, string>
local special_filetypes = {
	qf = "Quickfix",
	help = "Help",
	checkhealth = "Health",
	lazy = "Lazy",
	mason = "Mason",
	oil = "Oil",
	NvimTree = "NvimTree",
	trouble = "Trouble",
}

--- Map Neovim raw mode strings to concise statusline display indicators
--- @type table<string, string>
local mode_map = {
	n = "N", niI = "N", niR = "N", niV = "N",
	nt = "T-N", ntT = "T-N",
	no = "O-P", nov = "O-P", noV = "O-P", ["no\x22"] = "O-P",
	i = "I", ic = "I", ix = "I",
	v = "V", V = "V", ["\x16"] = "V",
	s = "S", S = "S", ["\x13"] = "S",
	c = "C", cv = "C", ce = "C",
	t = "T",
	R = "R", r = "R", rm = "R", Rc = "R", Rx = "R", Rv = "R", Rvc = "R", Rvr = "R",
	["!"] = "!",
}

--- Map Neovim raw mode strings directly to custom highlight groups
--- @type table<string, string>
local highlight_map = {
	n = "StlModeN", niI = "StlModeN", niR = "StlModeN", niV = "StlModeN",
	nt = "StlModeT", ntT = "StlModeT",
	no = "StlModeN", nov = "StlModeN", noV = "StlModeN", ["no\x22"] = "StlModeN",
	i = "StlModeI", ic = "StlModeI", ix = "StlModeI",
	v = "StlModeV", V = "StlModeV", ["\x16"] = "StlModeV",
	s = "StlModeS", S = "StlModeS", ["\x13"] = "StlModeS",
	c = "StlModeC", cv = "StlModeC", ce = "StlModeC",
	t = "StlModeT",
	R = "StlModeR", r = "StlModeR", rm = "StlModeR", Rc = "StlModeR", Rx = "StlModeR", Rv = "StlModeR", Rvc = "StlModeR", Rvr = "StlModeR",
	["!"] = "StlModeC",
}

--- @class StatuslineComponent
--- @field render fun(opts?: table): string|nil Component evaluation function returning formatted string
--- @field hl fun(): string Highlight group resolution function

--- Component constructor helper
--- @param render_fn fun(opts?: table): string|nil
--- @param hl_fn fun(): string
--- @return StatuslineComponent
local function create_component(render_fn, hl_fn)
	return { render = render_fn, hl = hl_fn }
end

--- Check whether component key is enabled in configuration options
--- @param component_key string Component toggle identifier
--- @return boolean is_enabled
local function is_enabled(component_key)
	return not (config.options.show and config.options.show[component_key] == false)
end

--- Cached mode string shared between render() and hl() to avoid duplicate C-API calls
local cached_mode = "n"

--- Mode indicator component
M.mode = create_component(
	function()
		if not is_enabled("mode") then return nil end
		cached_mode = vim.api.nvim_get_mode().mode
		return " " .. (mode_map[cached_mode] or "?") .. " "
	end,
	function()
		return highlight_map[cached_mode] or "StlModeN"
	end
)

--- Visual selection metrics component (lines/characters)
M.selection = create_component(
	function()
		if not is_enabled("selection") then return nil end
		local mode_code = vim.api.nvim_get_mode().mode
		if mode_code ~= "v" and mode_code ~= "V" and mode_code ~= "\x16" then return nil end

		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		local start_vcol = vim.fn.virtcol("v")
		local end_vcol = vim.fn.virtcol(".")

		local line_count = math.abs(end_line - start_line) + 1

		if mode_code == "V" then
			return " " .. line_count .. "L "
		elseif mode_code == "\x16" then
			local col_count = math.abs(end_vcol - start_vcol) + 1
			return " " .. line_count .. "L×" .. col_count .. "C "
		else
			if line_count == 1 then
				local char_count = math.abs(end_vcol - start_vcol) + 1
				return " " .. char_count .. "c "
			else
				return " " .. line_count .. "L "
			end
		end
	end,
	function() return "StlSelection" end
)

--- Macro recording register indicator component
M.macro = create_component(
	function()
		if not is_enabled("macro") then return nil end
		local active_register = vim.fn.reg_recording()
		if active_register == "" then return nil end
		local icon_glyph = config.options.use_icons and "󰑋 " or "REC "
		return " " .. icon_glyph .. "@" .. active_register .. " "
	end,
	function() return "StlMacro" end
)

--- Search match counter component
M.search = create_component(
	function()
		if not is_enabled("search") then return nil end
		if vim.v.hlsearch ~= 1 then return nil end
		local is_ok, search_result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 25 })
		if not is_ok or not search_result or not search_result.total or search_result.total == 0 then return nil end

		local icon_glyph = config.options.use_icons and (config.options.icons and config.options.icons.search or "󰍉") or ""
		local icon_prefix = icon_glyph ~= "" and (icon_glyph .. " ") or ""
		return " " .. icon_prefix .. search_result.current .. "/" .. search_result.total .. " "
	end,
	function() return "StlSearch" end
)

--- Git status and diff component
M.git = create_component(
	function()
		if not is_enabled("git") then return nil end
		local branch_name = git.get_branch()
		if not branch_name or branch_name == "" then return nil end

		local icon_glyph = config.options.use_icons and (config.options.icons and config.options.icons.git or "") or ""
		local icon_prefix = icon_glyph ~= "" and (icon_glyph .. " ") or ""

		local diff_summary = ""
		local added_lines = 0
		local changed_lines = 0
		local removed_lines = 0
		local has_diff = false

		local git_dict = vim.b.gitsigns_status_dict
		if git_dict then
			added_lines = git_dict.added or 0
			changed_lines = git_dict.changed or 0
			removed_lines = git_dict.removed or 0
			has_diff = true
		elseif vim.b.minidiff_summary then
			local summary = vim.b.minidiff_summary
			added_lines = summary.add or 0
			changed_lines = summary.change or 0
			removed_lines = summary.delete or 0
			has_diff = true
		end

		if config.options.coloured_diff and has_diff then
			local diff_parts = {}
			if added_lines > 0 then
				local add_symbol = (config.options.icons and config.options.icons.add) or "+"
				table.insert(diff_parts, "%#StlGitAdd#" .. add_symbol .. added_lines .. "%#StlGit#")
			end
			if changed_lines > 0 then
				local change_symbol = (config.options.icons and config.options.icons.change) or "~"
				table.insert(diff_parts, "%#StlGitChange#" .. change_symbol .. changed_lines .. "%#StlGit#")
			end
			if removed_lines > 0 then
				local delete_symbol = (config.options.icons and config.options.icons.delete) or "-"
				table.insert(diff_parts, "%#StlGitDelete#" .. delete_symbol .. removed_lines .. "%#StlGit#")
			end
			if #diff_parts > 0 then
				diff_summary = " " .. table.concat(diff_parts, " ")
			end
		else
			local status_text = vim.b.gitsigns_status
			if status_text and status_text ~= "" then
				diff_summary = " " .. status_text
			end
		end

		return " " .. icon_prefix .. branch_name:gsub("%%", "%%%%") .. diff_summary
	end,
	function() return "StlGit" end
)

--- LSP diagnostics summary component with per-severity colouring
M.diagnostics = create_component(
	function()
		if not is_enabled("diagnostics") then return nil end
		local diagnostic_counts = vim.diagnostic.count(0)
		local error_count = diagnostic_counts[vim.diagnostic.severity.ERROR] or 0
		local warning_count = diagnostic_counts[vim.diagnostic.severity.WARN] or 0

		if error_count == 0 and warning_count == 0 then return nil end

		local error_icon, warning_icon
		if config.options.use_icons then
			error_icon = (config.options.icons and config.options.icons.error) or "󰅚"
			warning_icon = (config.options.icons and config.options.icons.warn) or "󰀦"
		else
			error_icon = "×"
			warning_icon = "▲"
		end

		local count_parts = {}
		if error_count > 0 then
			table.insert(count_parts, "%#StlDiagError#" .. error_icon .. " " .. error_count .. "%#StlDiag#")
		end
		if warning_count > 0 then
			table.insert(count_parts, "%#StlDiagWarn#" .. warning_icon .. " " .. warning_count .. "%#StlDiag#")
		end
		return " " .. table.concat(count_parts, " ")
	end,
	function() return "StlDiag" end
)

--- Dynamic filename and special window header component
M.filename = create_component(
	function(options)
		if not is_enabled("filename") then return "" end
		options = options or { avail = 30, margin_right = 6 }
		local buffer_type = vim.bo.buftype
		local file_type = vim.bo.filetype

		-- Handle special non-file buffer windows
		if buffer_type ~= "" then
			if buffer_type == "quickfix" then
				local is_loclist = false
				local is_ok, win_info = pcall(vim.fn.getwininfo, vim.api.nvim_get_current_win())
				if is_ok and win_info and win_info[1] and win_info[1].loclist == 1 then
					is_loclist = true
				end
				local qf_list = is_loclist and vim.fn.getloclist(0, { idx = 0, size = 0 }) or vim.fn.getqflist({ idx = 0, size = 0 })
				if qf_list and qf_list.size > 0 then
					local label = is_loclist and "LOCLIST" or "QUICKFIX"
					return " [" .. label .. " " .. qf_list.idx .. "/" .. qf_list.size .. "] "
				end
			end
			-- Terminal buffer: extract running command name from channel info
			if buffer_type == "terminal" then
				local is_ok, chan_info = pcall(vim.api.nvim_get_chan_info, vim.bo.channel or 0)
				if is_ok and chan_info and chan_info.argv and chan_info.argv[1] then
					local cmd_name = vim.fn.fnamemodify(chan_info.argv[1], ":t")
					return " [" .. cmd_name:upper() .. "] "
				end
			end
			local header_title = special_buftypes[buffer_type] or (file_type ~= "" and file_type or buffer_type)
			return " [" .. header_title:upper() .. "] "
		end

		if special_filetypes[file_type] then
			return " [" .. special_filetypes[file_type]:upper() .. "] "
		end

		local is_modified = vim.bo.modified and " +" or ""
		local is_readonly = vim.bo.readonly and " =" or ""
		local file_suffix = is_modified .. is_readonly

		local buffer_name = vim.api.nvim_buf_get_name(0)
		if buffer_name == "" then return " [No Name]" .. file_suffix .. " " end

		local target_width = math.max(10, options.avail - (options.margin_right or 0))

		local file_icon = icons.get_icon("file", buffer_name) or icons.get_icon("filetype", file_type)
		local icon_prefix = file_icon and (file_icon .. " ") or ""
		local icon_w = vim.api.nvim_strwidth(icon_prefix)
		local suffix_w = #file_suffix

		local relative_path = vim.fs.normalize(vim.fn.fnamemodify(buffer_name, ":~:."))

		-- Use full relative path if it fits within target width
		if icon_w + vim.api.nvim_strwidth(relative_path) + suffix_w <= target_width then
			return " " .. icon_prefix .. relative_path:gsub("%%", "%%%%") .. file_suffix .. " "
		end

		-- Progressive truncation: compute segment budgets with integer math
		local path_segments = vim.split(relative_path, "/")
		local prefix_w = 2 -- display width of "…/"
		local base_w = icon_w + suffix_w
		local acc_w = 0
		local count = 0

		for i = #path_segments, 1, -1 do
			local seg_w = vim.api.nvim_strwidth(path_segments[i])
			local extra_slash = count > 0 and 1 or 0
			local needed = base_w + (i > 1 and prefix_w or 0) + acc_w + seg_w + extra_slash
			if needed <= target_width then
				acc_w = acc_w + seg_w + extra_slash
				count = count + 1
			else
				break
			end
		end

		local display_path
		if count == 0 then
			display_path = path_segments[#path_segments]
		elseif count < #path_segments then
			display_path = "…/" .. table.concat(path_segments, "/", #path_segments - count + 1, #path_segments)
		else
			display_path = relative_path
		end

		return " " .. icon_prefix .. display_path:gsub("%%", "%%%%") .. file_suffix .. " "
	end,
	function() return "StlFile" end
)

--- Active DAP debugger status component
M.dap_status = create_component(
	function()
		if not is_enabled("dap") then return nil end
		local dap_module = package.loaded["dap"]
		if not dap_module or type(dap_module.status) ~= "function" then return nil end
		local status_text = dap_module.status()
		if not status_text or status_text == "" then return nil end
		local icon_glyph = config.options.use_icons and (config.options.icons and config.options.icons.dap or "󰃤") or "DBG"
		return " " .. icon_glyph .. " " .. status_text .. " "
	end,
	function() return "StlDap" end
)

--- Spell checking indicator component
M.spell = create_component(
	function()
		if not is_enabled("spell") then return nil end
		if not vim.wo.spell then return nil end
		local icon_glyph = config.options.use_icons and (config.options.icons and config.options.icons.spell or "󰓆") or ""
		local icon_prefix = icon_glyph ~= "" and (icon_glyph .. " ") or ""
		return " " .. icon_prefix .. "SPELL "
	end,
	function() return "StlWarn" end
)

--- Format and encoding warning component
M.format_warn = create_component(
	function()
		if not is_enabled("format_warn") then return nil end
		local file_format = vim.bo.fileformat
		local file_encoding = vim.bo.fileencoding

		local has_ff = file_format ~= "" and file_format ~= "unix"
		local has_fe = file_encoding ~= "" and file_encoding ~= "utf-8" and file_encoding ~= "utf8"
		if not has_ff and not has_fe then return nil end

		local warning_parts = {}
		if has_ff then
			table.insert(warning_parts, file_format:upper())
		end
		if has_fe then
			table.insert(warning_parts, file_encoding:upper())
		end

		local icon_glyph = config.options.use_icons and (config.options.icons and config.options.icons.warn_fmt or "⚠") or ""
		local icon_prefix = icon_glyph ~= "" and (icon_glyph .. " ") or ""
		return " " .. icon_prefix .. table.concat(warning_parts, " ") .. " "
	end,
	function() return "StlWarn" end
)

--- Active LSP clients component
M.lsp = create_component(
	function()
		if not is_enabled("lsp") then return nil end
		local active_clients = vim.lsp.get_clients({ bufnr = 0 })
		if #active_clients == 0 then return nil end

		local seen = {}
		local client_names = {}
		for _, client in ipairs(active_clients) do
			if not seen[client.name] then
				seen[client.name] = true
				table.insert(client_names, client.name)
			end
		end
		return " " .. table.concat(client_names, ",") .. " "
	end,
	function() return "StlLSP" end
)

--- Filetype indicator component
M.filetype = create_component(
	function()
		if not is_enabled("filetype") then return nil end
		local current_filetype = vim.bo.filetype
		if current_filetype == "" then return nil end
		local file_icon = icons.get_icon("filetype", current_filetype)
		local icon_prefix = file_icon and (file_icon .. " ") or ""
		return " " .. icon_prefix .. current_filetype .. " "
	end,
	function() return "StlFT" end
)

--- Cursor position component
M.position = create_component(
	function()
		if not is_enabled("position") then return nil end
		local current_line = vim.api.nvim_win_get_cursor(0)[1]
		local total_lines = vim.api.nvim_buf_line_count(0)
		return " " .. current_line .. "/" .. total_lines .. " "
	end,
	function() return "StlPos" end
)

--- Left-aligned statusline components
--- @type StatuslineComponent[]
M.left_components = { M.mode, M.selection, M.macro, M.search, M.git, M.diagnostics }

--- Right-aligned statusline components
--- @type StatuslineComponent[]
M.right_components = { M.dap_status, M.spell, M.format_warn, M.lsp, M.filetype, M.position }

return M
