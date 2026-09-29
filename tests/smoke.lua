--- Headless smoke test for zline.nvim.
---
--- Run locally with:
---   nvim --headless --clean -u NONE -c "luafile tests/smoke.lua"
---
--- Exits with a non-zero status if any check fails.

local repo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(repo_root)

local failures = 0

--- @param label string
--- @param fn fun()
local function check(label, fn)
	local ok, err = pcall(fn)
	if ok then
		io.stdout:write(string.format("ok   %s\n", label))
	else
		failures = failures + 1
		io.stderr:write(string.format("FAIL %s: %s\n", label, tostring(err)))
	end
end

check("setup marks plugin configured", function()
	require("zline").setup({ use_icons = false })
	assert(vim.g.zline_configured == true, "vim.g.zline_configured was not set")
end)

check("statusline renders for current window", function()
	local line = require("zline").statusline()
	assert(type(line) == "string" and line ~= "", "empty statusline")
end)

check("statusline survives a stale statusline_winid", function()
	local previous = vim.g.statusline_winid
	vim.g.statusline_winid = 999999
	local ok, line = pcall(require("zline").statusline)
	vim.g.statusline_winid = previous
	assert(ok, line)
end)

check("inactive split uses StlBarNC", function()
	vim.cmd("vsplit")
	local current = vim.api.nvim_get_current_win()
	local other
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if win ~= current then
			other = win
		end
	end
	vim.g.statusline_winid = other
	local ok, line = pcall(require("zline").statusline)
	vim.g.statusline_winid = current
	vim.cmd("only")
	assert(ok, line)
	assert(line:find("StlBarNC", 1, true), "expected inactive highlight: " .. line)
end)

check("quickfix window header", function()
	vim.fn.setqflist({ { filename = "/tmp/zline_smoke.lua", lnum = 1, text = "a" } })
	vim.cmd("copen")
	vim.g.statusline_winid = vim.api.nvim_get_current_win()
	local line = require("zline").statusline()
	vim.cmd("cclose")
	assert(line:find("QUICKFIX", 1, true), "missing quickfix label: " .. line)
end)

check("filename stays within its width budget", function()
	vim.cmd("enew")
	vim.bo.swapfile = false
	local long_path = string.format("/tmp/zline_smoke_%d/very/long/nested/path/some_long_filename.lua", vim.uv.hrtime())
	vim.api.nvim_buf_set_name(0, long_path)
	local rendered = require("zline.components").filename.render({ avail = 20, margin_right = 4 })
	assert(vim.api.nvim_strwidth(rendered) <= 20, "filename overflowed: " .. rendered)
end)

check("literal percent signs are escaped", function()
	require("zline").setup({ use_icons = false, coloured_diff = false })
	vim.b.gitsigns_head = "main"
	vim.b.gitsigns_status = "50% done"
	local rendered = require("zline.components").git.render()
	assert(rendered:find("50%% done", 1, true), "percent not escaped: " .. tostring(rendered))
end)

check("search counter renders and reuses its cache", function()
	require("zline").setup({ use_icons = false })
	vim.cmd("enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo", "bar", "foo" })
	vim.o.hlsearch = true
	vim.fn.setreg("/", "foo")
	local components = require("zline.components")
	local first = components.search.render()
	assert(type(first) == "string" and first:find("/", 1, true), "no search count: " .. tostring(first))
	-- A redraw with no state change should hit the cache and still render.
	local second = components.search.render()
	assert(first == second, "cache changed the rendered count")
	-- Editing the buffer must not produce a stale/erroring result.
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo", "bar", "baz" })
	local third = components.search.render()
	assert(type(third) == "string" or third == nil, "unexpected search render: " .. tostring(third))
end)

if failures > 0 then
	io.stderr:write(string.format("\n%d check(s) failed\n", failures))
	vim.cmd("cquit 1")
else
	io.stdout:write("\nall checks passed\n")
	vim.cmd("qa!")
end
