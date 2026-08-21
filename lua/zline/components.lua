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

--- Mode indicator component
M.mode = create_component(
	function()
		if not is_enabled("mode") then return nil end
		local active_mode = vim.api.nvim_get_mode().mode
		return " " .. (mode_map[active_mode] or "?") .. " "
	end,
	function()
		local active_mode = vim.api.nvim_get_mode().mode
		return highlight_map[active_mode] or "StlModeN"
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
		local is_ok, search_result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
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
		local git_dict = vim.b.gitsigns_status_dict
		if config.options.coloured_diff and git_dict then
			local added_lines = git_dict.added or 0
			local changed_lines = git_dict.changed or 0
			local removed_lines = git_dict.removed or 0

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

		return " " .. icon_prefix .. branch_name .. diff_summary
	end,
	function() return "StlGit" end
)

--- LSP diagnostics summary component
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
		if error_count > 0 then table.insert(count_parts, error_icon .. " " .. error_count) end
		if warning_count > 0 then table.insert(count_parts, warning_icon .. " " .. warning_count) end
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
				local qf_list = vim.fn.getqflist({ idx = 0, size = 0 })
				if qf_list and qf_list.size > 0 then
					return " [QUICKFIX " .. qf_list.idx .. "/" .. qf_list.size .. "] "
				end
			end
			local header_title = special_buftypes[buffer_type] or (file_type ~= "" and file_type or buffer_type)
			return " [" .. header_title:upper() .. "] "
		end

		if special_filetypes[file_type] then
			return " [" .. special_filetypes[file_type]:upper() .. "] "
		end

		local target_width = math.max(10, options.avail - (options.margin_right or 0))
		local buffer_name = vim.api.nvim_buf_get_name(0)

		if buffer_name == "" then return " [No Name] " end

		local is_modified = vim.bo.modified and " +" or ""
		local is_readonly = vim.bo.readonly and " =" or ""
		local file_suffix = is_modified .. is_readonly

		local file_icon = icons.get_icon("file", buffer_name) or icons.get_icon("filetype", vim.bo.filetype)
		local icon_prefix = file_icon and (file_icon .. " ") or ""

		local relative_path = vim.fs.normalize(vim.fn.fnamemodify(buffer_name, ":."))

		-- Use full relative path if it fits within target width
		if vim.fn.strwidth(icon_prefix .. relative_path) + #file_suffix <= target_width then
			return " " .. icon_prefix .. relative_path .. file_suffix .. " "
		end

		-- Progressive truncation: reconstruct path backwards segment by segment
		local path_segments = vim.split(relative_path, "/")
		local truncated_path = ""
		for i = #path_segments, 1, -1 do
			local candidate_path = path_segments[i] .. (truncated_path ~= "" and "/" or "") .. truncated_path
			local candidate_prefix = i > 1 and "…/" or ""
			if vim.fn.strwidth(icon_prefix .. candidate_prefix .. candidate_path .. file_suffix) <= target_width then
				truncated_path = candidate_path
			else
				break
			end
		end

		local has_parents = #path_segments > 1 and truncated_path ~= relative_path
		local prefix = has_parents and "…/" or ""
		local display_path = truncated_path ~= "" and truncated_path or path_segments[#path_segments]

		return " " .. icon_prefix .. prefix .. display_path .. file_suffix .. " "
	end,
	function() return "StlFile" end
)

--- Active DAP debugger status component
M.dap_status = create_component(
	function()
		if not is_enabled("dap") then return nil end
		if not package.loaded["dap"] then return nil end
		local is_available, dap_module = pcall(require, "dap")
		if not is_available or not dap_module then return nil end
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
		local warning_parts = {}

		if file_format ~= "" and file_format ~= "unix" then
			table.insert(warning_parts, file_format:upper())
		end
		if file_encoding ~= "" and file_encoding ~= "utf-8" and file_encoding ~= "utf8" then
			table.insert(warning_parts, file_encoding:upper())
		end
		if #warning_parts == 0 then return nil end

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

		local client_names = {}
		for _, client in ipairs(active_clients) do
			table.insert(client_names, client.name)
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
