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
    text = {
        loading = "Loading...",
        version = "%s",
        update = "  %s",
        error = "Error fetching version",
        yanked = "%s yanked",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        update = "CratesNvimUpdate",
        error = "CratesNvimError",
        yanked = "CratesNvimYanked"
    },
    popup = {
        text = {
            yanked = "yanked"
        },
        highlight = {
            yanked = "CratesNvimPopupYanked"
        },
        keys = {
            hide = { "q", "<esc>" },
            copy_version = { "yy" },
        },
        style = "minimal",
        border = "none",
        max_height = 30,
        min_width = 20,
    },
}
```

## TODO
- possibly port to teal?
- completion source for nivm-cmp

