std = "luajit"
max_line_length = 120

-- Neovim exposes its API through the `vim` global, which is both read and
-- written (e.g. `vim.o.statusline = ...`).
globals = { "vim" }
