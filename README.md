# crates.nvim
A neovim plugin show available crates.io versions

This is quite young software, so you might encounter some bugs.
Feel free to open issues.

## Features
- Show all available versions in a floating window

## Setup
```lua
require("crates").setup {
    autoload = true,
    autoupdate = true,
    loading_indicator = true,
    popup_hide_keys = { "q", "<esc>" },
    text = {
        loading = "Loading...",
        version = "%s",
        update = "  %s",
        error = "Error fetching version",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        update = "CratesNvimUpdate",
        error = "CratesNvimError",
    },
    win_style = "minimal",
    win_border = "none",
}
```

## TODO
- possibly port to teal?
- completion source for nivm-cmp

