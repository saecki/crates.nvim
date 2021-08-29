# crates.nvim
A neovim plugin that helps managing crates.io versions.

This project is still in it's infancy, so you might encounter some bugs.
Feel free to open issues.

![](res/example.png)

## Features
- Completion source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- Upgrade crate on current line
- Automatically load when opening a Cargo.toml file (`autoload`)
- Live update while editing (`autoupdate`)
- Show currently usable version
    - indicate if usable version is a pre-release
    - indicate if usable version is yanked
    - indicate if no version is usable
- Show best upgrade candidate
- Open floating window with all versions
    - Select a version by pressing enter (`popup.keys.select`)

## Setup

### Installation
[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'nvim-lua/plenary.nvim'
Plug 'saecki/crates.nvim'
```

[__packer.nvim__](https://github.com/wbthomason/packer.nvim)
```
use { 'Saecki/crates.nvim', requires = { 'nvim-lua/plenary.nvim' } }
```

### [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source
Just add it to your list of sources:
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

Or add it lazily:
```viml
autocmd FileType toml lua require('cmp').setup.buffer { sources = { { name = 'crates' } } }
```

## Config

__Default__

The icons in the default configuration require a patched font:
```lua
require("crates").setup {
    avoid_prerelease = true, -- don't select a prerelease if the requirement does not have a suffix
    autoload = true, -- automatically run update when opening a Cargo.toml
    autoupdate = true, -- atomatically update when editing text
    loading_indicator = true, -- show a loading indicator while fetching crate versions
    text = {
        loading    = "   Loading",
        version    = "   %s",
        prerelease = "   %s",
        yanked     = "   %s",
        nomatch    = "   No match",
        update     = "   %s",
        error      = "   Error fetching crate",
    },
    highlight = {
        loading    = "CratesNvimLoading",
        version    = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked     = "CratesNvimYanked",
        nomatch    = "CratesNvimNoMatch",
        update     = "CratesNvimUpdate",
        error      = "CratesNvimError",
    },
    popup = {
        autofocus = false, -- focus the versions popup when opening it
        copy_register = '"', -- the register into which the version will be copied
        style = "minimal", -- same as nvim_open_win opts.style
        border = "none", -- same as nvim_open_win opts.border
        max_height = 30,
        min_width = 20,
        text = {
            title   = "  %s ",
            version = "   %s ",
            yanked  = "  %s ",
        },
        highlight = {
            title   = "CratesNvimPopupTitle",
            version = "CratesNvimPopupVersion",
            yanked  = "CratesNvimPopupYanked",
        },
        keys = {
            hide = { "q", "<esc>" },
            select = { "<cr>" },
            copy_version = { "yy" },
        },
    },
}
```

__Plain text__

Replace these sections if you don't have a patched font:
```lua
require("crates").setup {
    text = {
        loading    = "  Loading...",
        version    = "  %s",
        prerelease = "  %s",
        yanked     = "  %s yanked",
        nomatch    = "  Not found",
        update     = "  %s",
        error      = "  Error fetching version",
    },
    popup = {
        text = {
            title   = " # %s ",
            version = " %s ",
            yanked  = " %s yanked",
        },
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

-- update crate on current line to newest compatible version
require('crates').update_crate()

-- update crates on lines visually selected to newest compatible version
require('crates').update_crates()

-- upgrade crate on current line to newest version
require('crates').upgrade_crate()

-- upgrade crates on lines visually selected to newest version
require('crates').upgrade_crates()

-- show popup with all versions (if `popup.autofocus` is disabled calling this again will focus the popup)
require('crates').show_versions_popup()

-- hide popup with all versions
require('crates').hide_versions_popup()
```
### Key mappings

Some examples of key mappings:
```viml
nnoremap <silent> <leader>vt :lua require('crates').toggle()<cr>
nnoremap <silent> <leader>vr :lua require('crates').reload()<cr>
nnoremap <silent> <leader>vu :lua require('crates').update_crate()<cr>
vnoremap <silent> <leader>vu :lua require('crates').update_crates()<cr>
nnoremap <silent> <leader>vU :lua require('crates').upgrade_crate()<cr>
vnoremap <silent> <leader>vU :lua require('crates').upgrade_crates()<cr>
```

### Show appropriate documentation in `Cargo.toml`
How you might integrate `show_versions` into your `init.vim`:
```viml
nnoremap <silent> K :call <SID>show_documentation()<cr>
function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
    elseif ('Cargo.toml' == expand('%:t'))
        lua require('crates').show_versions_popup()
    else
        lua vim.lsp.buf.hover()
    endif
endfunction
```

## TODO
- Don't replace conditions in version requirements (`^`, `~`, `=`, ...)

## Similar projects
- [vim-crates](https://github.com/mhinz/vim-crates)

