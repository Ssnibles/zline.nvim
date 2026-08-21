--- Git status resolution and zero-subprocess branch detection
--- @module 'zline.git'

local M = {}

--- Cache storing branch names keyed by directory path
--- @type table<string, string|false>
local branch_cache = {}

--- Clear git branch filesystem cache
function M.clear_cache()
	branch_cache = {}
end

--- Resolve Git branch name using gitsigns variables or non-blocking .git/HEAD inspection
--- @return string|nil branch_name Resolved Git branch identifier, or nil if untracked
function M.get_branch()
	-- 1. Use gitsigns buffer variable if available
	local head = vim.b.gitsigns_head
	if head and head ~= "" then
		return head
	end

	-- 2. Fast fallback via direct .git/HEAD file reading
	local buffer_name = vim.api.nvim_buf_get_name(0)
	local directory = buffer_name ~= "" and vim.fs.dirname(buffer_name) or vim.uv.cwd()
	if not directory then return nil end

	if branch_cache[directory] ~= nil then
		return branch_cache[directory] ~= false and branch_cache[directory] or nil
	end

	local git_root = vim.fs.find(".git", { upward = true, path = directory })[1]
	if not git_root then
		branch_cache[directory] = false
		return nil
	end

	local head_file_path = git_root .. "/HEAD"
	local filesystem_stat = vim.uv.fs_stat(git_root)

	-- Handle git worktrees or submodules pointing to a gitdir file
	if filesystem_stat and filesystem_stat.type == "file" then
		local file_handle = io.open(git_root, "r")
		if file_handle then
			local first_line = file_handle:read("*l") or ""
			file_handle:close()
			local gitdir_path = first_line:match("gitdir:%s*(.+)")
			if gitdir_path then
				if not gitdir_path:match("^/") then
					gitdir_path = vim.fs.normalize(git_root:sub(1, -6) .. "/" .. gitdir_path)
				end
				head_file_path = gitdir_path .. "/HEAD"
			end
		end
	end

	local file_handle = io.open(head_file_path, "r")
	if file_handle then
		local line_content = file_handle:read("*l") or ""
		file_handle:close()
		local branch_name = line_content:match("ref: refs/heads/(.+)") or (line_content ~= "" and line_content:sub(1, 7) or nil)
		branch_cache[directory] = branch_name or false
		return branch_name
	end

	branch_cache[directory] = false
	return nil
end

return M
