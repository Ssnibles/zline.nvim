if vim.g.loaded_zline then
	return
end
vim.g.loaded_zline = true

local zline = require("zline")
-- Only apply defaults when no one has configured the plugin yet. This lets a
-- user's `require("zline").setup(opts)` in init.lua win (init.lua is sourced
-- before plugin/ scripts), while still working out-of-the-box and with lazy
-- managers that call `setup(opts)` after loading the plugin.
if not vim.g.zline_configured then
	zline.setup()
end
