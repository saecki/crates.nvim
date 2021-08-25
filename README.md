# crates.nvim
A neovim plugin show available crates.io versions

## Setup
```lua
require("crates").setup {
    autoload = true,
    autoupdate = true,
    loading_indicator = true,
    popup_hide_keys = { "q", "<esc>" },
    text = {
        version = "%s",
        loading = "Loading...",
        error = "Error fetching version",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        error = "CratesNvimError",
    },
    win_style = "minimal",
    win_border = "none",
}
```

## TODO
- [ ] semantic versioning and show update candidates
- [ ] completion source for nivm-cmp

