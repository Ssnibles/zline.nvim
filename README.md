# ⚡line.nvim

A blisteringly fast, modular, zero-dependency statusline plugin for Neovim written in pure Lua. Designed for performance, minimal distraction, and seamless integration with `cmdheight=0`.

---

## ✨ Features

- **Zero-Latency Render Loop**: Built with fast C-API calls (`vim.api.nvim_win_get_cursor`, `vim.api.nvim_buf_line_count`), lazy-loaded `mini.icons`, and cached git resolution.
- **Embedded Command-Line & Search Bar (`cmdheight=0`)**: Smoothly transforms the statusline into a styled command input bar when typing `:` commands or searching with `/` and `?`.
- **Smart Git Integration**: Instant `.git/HEAD` reader fallback with support for `gitsigns` variables and coloured diff counters (`+` green, `~` yellow, `-` red).
- **Search Counter**: Displays active match count (`󰍉 3/14`) only during active searches.
- **Visual Selection Metrics**: Shows line/character counts (`12c`, `4L`, `8L×24C`) when in Visual mode.
- **Format & Encoding Badges**: Highlights non-standard buffer configurations (`⚠ DOS`, `UTF-16`) while remaining hidden for standard `unix` `utf-8` files.
- **Adaptive Path Truncation**: Intelligently truncates buffer paths right-to-left based on available window width.
- **Special Window Headers**: Clean, uppercase headers for Quickfix (`[QUICKFIX 3/18]`), Help, Terminal, Oil, and tree buffers.
- **Configurable Starter & Buffer Hiding**: Automatically hides the statusline in starter screens (`mini.starter`, `snacks.dashboard`, `alpha`, `dashboard`) or custom filetypes/buftypes.
- **Spell & DAP Indicators**: Subtle badges for active spell checking (`:set spell`) and `nvim-dap` debugging sessions.

---

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "zline.nvim",
  dir = "~/zline.nvim", -- or your repo path
  event = "VeryLazy",
  opts = {
    use_icons = true,
    coloured_diff = true,
    cmdline_in_statusline = true,
    cmdline_prompt_bg = false,
  },
}
```

---

## ⚙️ Options & Defaults

```lua
require("zline").setup({
  use_icons = true,             -- Enable mini.icons / Nerd Font glyphs
  coloured_diff = true,         -- Colour-code Git additions (+), changes (~), and deletions (-)
  cmdline_in_statusline = true, -- Embed command-line and search input directly into the statusline
  cmdline_prompt_bg = false,    -- false: minimal accent prompt icon; true: solid background badge
  disabled_filetypes = {        -- Hide statusline in specific filetypes
    "ministarter",
    "starter",
    "dashboard",
    "alpha",
    "snacks_dashboard",
    "snacks_starter",
  },
  disabled_buftypes = {},       -- Hide statusline in specific buffer types (e.g. "nofile", "terminal")
  show = {                      -- Toggle individual components for an ultra-minimal bar
    mode = true,                -- Mode indicator badge
    selection = true,           -- Visual selection metrics
    macro = true,               -- Macro recording register
    search = true,              -- Search match counter
    git = true,                 -- Git branch & diff summary
    diagnostics = true,         -- LSP diagnostics summary
    filename = true,            -- File path component
    dap = true,                 -- Active DAP debugger status
    spell = true,               -- Active spell checking indicator
    format_warn = true,         -- Format/encoding warning badges
    lsp = false,                -- Active LSP client names
    filetype = true,            -- Filetype badge
    position = true,            -- Cursor line/total line position
  },
  icons = {
    git = "",
    error = "󰅚",
    warn = "󰀦",
    add = "+",
    change = "~",
    delete = "-",
    search = "󰍉",
    warn_fmt = "⚠",
    cmd = ">",
    dap = "󰃤",
    spell = "󰓆",
  },
  filename_opts = {
    margin_right = 6, -- Safety margin for dynamic path truncation
  },
})
```

---

## 🎨 Highlight Groups

`zline.nvim` automatically links its highlight groups to standard Neovim groups if unconfigured, allowing it to adapt to any colourscheme out of the box.

| Highlight Group   | Default Link      | Description                                                |
| :---------------- | :---------------- | :--------------------------------------------------------- |
| `StlModeN`        | `StatusLine`      | Normal Mode badge                                          |
| `StlModeI`        | `ModeMsg`         | Insert Mode badge                                          |
| `StlModeV`        | `Visual`          | Visual Mode badge                                          |
| `StlModeC`        | `Command`         | Command Mode badge                                         |
| `StlCmdPrompt`    | Accent colour     | Command prompt icon (`>`) when `cmdline_prompt_bg = false` |
| `StlSearchPrompt` | Search Accent     | Search prompt icon (`󰍉`) when `cmdline_prompt_bg = false`  |
| `StlGit`          | `StatusLine`      | Git branch indicator                                       |
| `StlGitAdd`       | `GitSignsAdd`     | Git added line count (`+3`)                                |
| `StlGitChange`    | `GitSignsChange`  | Git modified line count (`~2`)                             |
| `StlGitDelete`    | `GitSignsDelete`  | Git deleted line count (`-1`)                              |
| `StlDiag`         | `DiagnosticError` | LSP error & warning summary                                |
| `StlSearch`       | `IncSearch`       | Search match counter badge                                 |
| `StlWarn`         | `WarningMsg`      | Format/encoding warning badge                              |
| `StlSelection`    | `Visual`          | Visual selection range metrics                             |
| `StlDap`          | `DiagnosticWarn`  | Active DAP debugger status                                 |

---

## 📄 License

MIT
