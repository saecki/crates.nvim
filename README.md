# crates.nvim
A neovim plugin that shows available crates.io versions.

This project is still in it's infancy, so you might encounter some bugs.
Feel free to open issues.

## Features
- Completion source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- Automatically load when opening a Cargo.toml file (`autoload`)
- Live update while editing (`autoupdate`)
- Show currently usable version
    - if usable version is a pre-release
    - if usable version is yanked
    - if no version is usable
- Show best upgrade candidate
- Open floating window with all versions

## Setup

### vim-plug
```
Plug 'nvim-lua/plenary.nvim'
Plug 'saecki/crates.nvim'
```

### nvim-cmp source
Just add it to your list of sources
```lua
require('cmp').setup {
    ...
    sources = {
        { name = "path" },
        { name = "buffer" },
        { name = "nvim_lsp" },
        ...
        { name = "crates" },
    },
}
```

## Config
```lua
require("crates").setup {
    avoid_prerelease = true,
    autoload = true,
    autoupdate = true,
    loading_indicator = true,
    text = {
        loading = "Loading...",
        version = "%s",
        prerelease = "%s",
        yanked = "%s yanked",
        nomatch = "No match",
        update = "  %s",
        error = "Error fetching version",
    },
    highlight = {
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked = "CratesNvimYanked",
        nomatch = "CratesNvimNoMatch",
        update = "CratesNvimUpdate",
        error = "CratesNvimError",
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
### Functions
```lua
-- load and display versions
require('crates').update()

-- force-reload and display versions (clears cache)
require('crates').reload()

-- hide versions
require('crates').hide()

-- show/hide versions
require('crates').toggle()


-- show popup with all versions (returns window id)
require('crates.popup').show_versions()

-- hide popup with all versions
require('crates.popup').hide_versions(win_id)
```

### Show appropriate documentation `Cargo.toml`
How you might integrate `show_versions` into your `init.vim`:
```viml
nnoremap <silent> K :call <SID>show_documentation()<cr>
function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
    elseif ('Cargo.toml' == expand('%:t'))
        lua require('crates.popup').show_versions()
    else
        lua vim.lsp.buf.hover()
    endif
endfunction
```

## TODO
- possibly port to teal?
- Enter to insert version in popup
- Update current line to displayed candidate

