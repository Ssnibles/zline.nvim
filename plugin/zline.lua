if vim.g.loaded_zline then
	return
end
vim.g.loaded_zline = true

local zline = require("zline")
zline.setup()

