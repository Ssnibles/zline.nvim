--- Git status resolution and zero-subprocess branch detection
--- @module 'zline.git'

local M = {}

--- Cache storing root directories keyed by directory path
--- @type table<string, string|false>
local dir_to_root = {}

--- Cache storing branch names keyed by git root path
--- @type table<string, string|false>
local root_branch_cache = {}

--- Clear git branch and root filesystem cache
function M.clear_cache()
	dir_to_root = {}
	root_branch_cache = {}
end

--- Resolve Git branch name using buffer variables or non-blocking .git/HEAD inspection
--- @return string|nil branch_name Resolved Git branch identifier, or nil if untracked
function M.get_branch()
	-- 1. Use buffer variables from git plugins if available
	local head = vim.b.gitsigns_head
	if head and head ~= "" then
		return head
	end

	local mini_summary = vim.b.minigit_summary
	if mini_summary and mini_summary.head_name and mini_summary.head_name ~= "" then
		return mini_summary.head_name
	end

	local b_branch = vim.b.git_branch
	if b_branch and b_branch ~= "" then
		return b_branch
	end

	-- 2. Fast fallback via direct .git/HEAD file reading
	local buffer_name = vim.api.nvim_buf_get_name(0)
	local directory = buffer_name ~= "" and vim.fs.dirname(buffer_name) or vim.uv.cwd()
	if not directory then return nil end

	local root = dir_to_root[directory]
	if root == nil then
		root = vim.fs.root(directory, ".git") or false
		dir_to_root[directory] = root
	end

	if not root then
		return nil
	end

	if root_branch_cache[root] ~= nil then
		return root_branch_cache[root] ~= false and root_branch_cache[root] or nil
	end

	local git_path = root .. "/.git"
	local head_file_path = git_path .. "/HEAD"
	local filesystem_stat = vim.uv.fs_stat(git_path)

	-- Handle git worktrees or submodules pointing to a gitdir file
	if filesystem_stat and filesystem_stat.type == "file" then
		local file_handle = io.open(git_path, "r")
		if file_handle then
			local first_line = (file_handle:read("*l") or ""):gsub("\r", ""):gsub("%s*$", "")
			file_handle:close()
			local gitdir_path = first_line:match("gitdir:%s*(.+)")
			if gitdir_path then
				if not gitdir_path:match("^/") and not gitdir_path:match("^%a+:") then
					gitdir_path = vim.fs.normalize(root .. "/" .. gitdir_path)
				end
				head_file_path = gitdir_path .. "/HEAD"
			end
		end
	end

	local file_handle = io.open(head_file_path, "r")
	if file_handle then
		local raw_line = file_handle:read("*l") or ""
		file_handle:close()
		local line_content = raw_line:gsub("\r", ""):gsub("%s*$", "")
		local branch_name = line_content:match("ref: refs/heads/(%S+)") or (line_content ~= "" and line_content:sub(1, 7) or nil)
		root_branch_cache[root] = branch_name or false
		return branch_name
	end

	root_branch_cache[root] = false
	return nil
end

return M
