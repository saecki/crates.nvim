# crates.nvim
A neovim plugin that helps managing crates.io dependencies.

This project is still in it's infancy, so you might encounter some bugs.
Feel free to open issues.

<details>
<summary style="font-size: 1.4em">!!! Breaking changes !!!</summary>

- `ab8b2d6` Don't automatically call setup anymore
- `8ecb36d` Renamed `update` text and highlight groups to `upgrade`

</details>

## Features
- Completion source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
    - Complete crate versions and features
- Update crates to newest compatible version
- Upgrade crates to newest version
- Respect existing version requirements and update them in an elegant way (`smart_insert`)
- Automatically load when opening a Cargo.toml file (`autoload`)
- Live update while editing (`autoupdate`)
- Show compatible version
    - Indicate if compatible version is a pre-release
    - Indicate if compatible version is yanked
    - Indicate if no version is compatible
- Show best upgrade candidate
- Open floating window with all versions
    - Select a version by pressing enter (`popup.keys.select`)
- Open floating window with all features
    - Navigate through the feature history
    - Indicate if a feature is enabled directly
    - Indicate if a feature is enabled transitively

![image](https://user-images.githubusercontent.com/43008152/134776663-aae0d50a-ee6e-4539-a766-8cccc629c21a.png)

### Popup
![image](https://user-images.githubusercontent.com/43008152/134776682-c995b48a-cad5-43d4-80e8-ee3637a5a78a.png)

### Completion
![image](https://user-images.githubusercontent.com/43008152/134776687-c1359967-4b96-460b-b5f2-2d80b6a09208.png)

## Setup

### Installation
[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'nvim-lua/plenary.nvim'
Plug 'saecki/crates.nvim'
```

[__packer.nvim__](https://github.com/wbthomason/packer.nvim)
```lua
use { 'Saecki/crates.nvim', requires = { 'nvim-lua/plenary.nvim' } }
```

For lazy loading:
```lua
use {
    'Saecki/crates.nvim',
    event = { "BufRead Cargo.toml" },
    requires = { { 'nvim-lua/plenary.nvim' } },
    config = function()
        require('crates').setup()
    end,
}
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

For more information about the type of some fields see [`lua/crates/config.lua`](lua/crates/config.lua).

__Default__

The icons in the default configuration require a patched font:
```lua
require('crates').setup {
    smart_insert = true, -- try to be smart about inserting versions
    avoid_prerelease = true, -- don't select a prerelease if the requirement does not have a suffix
    autoload = true, -- automatically run update when opening a Cargo.toml
    autoupdate = true, -- atomatically update when editing text
    loading_indicator = true, -- show a loading indicator while fetching crate versions
    date_format = "%Y-%m-%d", -- the date format passed to os.date
    text = {
        loading    = "   Loading",
        version    = "   %s",
        prerelease = "   %s",
        yanked     = "   %s",
        nomatch    = "   No match",
        upgrade    = "   %s",
        error      = "   Error fetching crate",
    },
    highlight = {
        loading    = "CratesNvimLoading",
        version    = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked     = "CratesNvimYanked",
        nomatch    = "CratesNvimNoMatch",
        upgrade    = "CratesNvimUpgrade",
        error      = "CratesNvimError",
    },
    popup = {
        autofocus = false, -- focus the versions popup when opening it
        copy_register = '"', -- the register into which the version will be copied
        style = "minimal", -- same as nvim_open_win config.style
        border = "none", -- same as nvim_open_win config.border
        version_date = false, -- display when a version was released
        max_height = 30,
        min_width = 20,
        text = {
            title      = "  %s ",
            -- versions
            version    = "   %s ",
            prerelease = "  %s ",
            yanked     = "  %s ",
            -- features
            feature    = "   %s ",
            enabled    = "  %s ",
            transitive = "  %s ",
            date       = " %s ",
        },
        highlight = {
            title      = "CratesNvimPopupTitle",
            -- versions
            version    = "CratesNvimPopupVersion",
            prerelease = "CratesNvimPopupPreRelease",
            yanked     = "CratesNvimPopupYanked",
            -- features
            feature    = "CratesNvimPopupFeature",
            enabled    = "CratesNvimPopupEnabled",
            transitive = "CratesNvimPopupTransitive",
        },
        keys = {
            hide = { "q", "<esc>" },
            -- versions
            select = { "<cr>" },
            select_dumb = { "s" },
            copy_version = { "yy" },
            -- features
            goto_feature = { "K", "<c-i>" },
            goback_feature = { "<c-o>" },
        },
    },
    cmp = {
        text = {
            prerelease = "  pre-release ",
            yanked     = "  yanked ",
        },
    },
}
```

__Plain text__

Replace these sections if you don't have a patched font:
```lua
require('crates').setup {
    text = {
        loading    = "  Loading...",
        version    = "  %s",
        prerelease = "  %s",
        yanked     = "  %s yanked",
        nomatch    = "  Not found",
        upgrade    = "  %s",
        error      = "  Error fetching crate",
    },
    popup = {
        text = {
            title      = " # %s ",
            -- versions
            version    = " %s ",
            prerelease = " %s ",
            yanked     = " %s yanked ",
            -- features
            feature    = "   %s ",
            enabled    = " + %s ",
            transitive = " - %s ",
        },
    },
    cmp = {
        text = {
            prerelease = " pre-release ",
            yanked     = " yanked ",
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

-- update crates to newest compatible version
-- all of these take an optional `smart` flag that will override the `smart_insert` config option
require('crates').update_crate() -- current line
require('crates').update_crates() -- visually selected
require('crates').update_all_crates() -- all in current buffer

-- upgrade crates to newest version
-- all of these take an optional `smart` flag that will override the `smart_insert` config option
require('crates').upgrade_crate() -- current line
require('crates').upgrade_crates() -- visually selected
require('crates').upgrade_all_crates() -- all in current buffer

-- show/hide popup with all versions or features
-- (if `popup.autofocus` is disabled calling this again will focus the popup)
require('crates').show_popup()
-- same as `show_popup` but always show versions
require('crates').show_versions_popup()
-- same as `show_popup` but always show features
require('crates').show_features_popup()
-- focus the popup (jump into the window)
require('crates').focus_popup()
-- hide the popup
require('crates').hide_popup()
```
### Key mappings

Some examples of key mappings:
```viml
nnoremap <silent> <leader>vt :lua require('crates').toggle()<cr>
nnoremap <silent> <leader>vr :lua require('crates').reload()<cr>
nnoremap <silent> <leader>vu :lua require('crates').update_crate()<cr>
vnoremap <silent> <leader>vu :lua require('crates').update_crates()<cr>
nnoremap <silent> <leader>va :lua require('crates').update_all_crates()<cr>
nnoremap <silent> <leader>vU :lua require('crates').upgrade_crate()<cr>
vnoremap <silent> <leader>vU :lua require('crates').upgrade_crates()<cr>
nnoremap <silent> <leader>vA :lua require('crates').upgrade_all_crates()<cr>
```

### Show appropriate documentation in `Cargo.toml`
How you might integrate `show_popup` into your `init.vim`:
```viml
nnoremap <silent> K :call <SID>show_documentation()<cr>
function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
        execute 'h '.expand('<cword>')
    elseif (index(['man'], &filetype) >= 0)
        execute 'Man '.expand('<cword>')
    elseif (expand('%:t') == 'Cargo.toml')
        lua require('crates').show_popup()
    else
        lua vim.lsp.buf.hover()
    endif
endfunction
```

How you might integrate `show_popup` into your `init.lua`:
```lua
vim.api.nvim_set_keymap('n', 'K', ':lua show_documentation()', { noremap = true, silent = true })
function show_documentation()
    local filetype = vim.bo.filetype
    if vim.tbl_contains({ 'vim','help' }, filetype) then
        vim.cmd('h '..vim.fn.expand('<cword>'))
    elseif vim.tbl_contains({ 'man' }, filetype) then
        vim.cmd('Man '..vim.fn.expand('<cword>'))
    elseif vim.fn.expand('%:t') == 'Cargo.toml' then
        require('crates').show_popup()
    else
        vim.lsp.buf.hover()
    end
end
```

## TODO
- make `<c-i>` work as expected (jump forward not goto)
- better cmp documentation for features
- maybe fetch dependencies (optional dependencies are automatically promoted to features)

## Similar projects
- [mhinz/vim-crates](https://github.com/mhinz/vim-crates)
- [shift-d/crates.nvim](https://github.com/shift-d/crates.nvim)
- [kahgeh/ls-crates.nvim](https://github.com/kahgeh/ls-crates.nvim)

