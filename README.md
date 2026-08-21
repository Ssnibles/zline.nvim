# zline.nvim

A lightweight, fast, pure Lua statusline plugin for Neovim with `mini.icons` integration, dynamic path truncation, mode indicators, git status, diagnostics, attached LSP clients, and line count indicators.

## Features

- **Icon Support**: Automatic integration with `mini.icons` for file, filetype, LSP, and git icons (with sensible fallbacks).
- **Mode Indicators**: Mode display with customizable highlight groups (`StlModeN`, `StlModeI`, etc.).
- **Git Status**: Direct integration with Gitsigns buffer variables (`vim.b.gitsigns_*`).
- **LSP Diagnostics**: Native summary using `vim.diagnostic.count`.
- **Attached LSP Clients**: Dynamic listing of attached language servers.
- **Smart Path Truncation**: Dynamic relative path truncation based on window width.
- **Fast Performance**: Pure Lua using fast C-API calls avoiding VimScript evaluation overhead.

## Usage

```lua
require("zline").setup({
  use_icons = true, -- Enable mini.icons support (default: true)
})
```
