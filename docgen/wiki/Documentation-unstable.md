Documentation for `crates.nvim` `unstable`

# Features
- Complete crate names, versions and features using one of:
    - In-process language server (`lsp`)
    - [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source (`completion.cmp`)
    - [coq.nvim](https://github.com/ms-jpq/coq_nvim) source (`completion.coq`)
- Code actions using one of:
    - In-process language server (`lsp`)
    - [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim)/[none-ls.nvim](https://github.com/nvimtools/none-ls.nvim)
- Update crates to newest compatible version
- Upgrade crates to newest version
- Respect existing version requirements and update them in an elegant way (`smart_insert`)
- Show version and upgrade candidates
    - Show if compatible version is a pre-release or yanked
    - Show if no version is compatible
- Open popup with crate info
    - Open documentation, crates.io, repository and homepage urls
- Open popup with crate versions
    - Select a version by pressing enter (`popup.keys.select`)
- Open popup with crate features
    - Navigate the feature hierarchy
    - Enable/disable features
    - Indicate if a feature is enabled directly or transitively
- Open popup with crate dependencies
    - Navigate the dependency hierarchy
    - Show `normal`, `build` and `dev` dependencies
    - Show optional dependencies
- Project-local configuration via [Neoconf](https://github.com/folke/neoconf.nvim)

# Setup

## In-process language server
This is the recommended way to enable completion and code actions.

Enable the in-process language server in the setup and select whether to enable
code actions, auto completion and hover.
```lua
require("crates").setup {
    ...
    lsp = {
        enabled = true,
        on_attach = function(client, bufnr)
            -- the same on_attach function as for your other lsp's
        end,
        actions = true,
        completion = true,
        hover = true,
    },
}
```

## Auto completion
Completion is supported in a few different ways, either by the [in-process language server](#in-process-language-server),
which also supports code actions, or by one of the following sources.

### [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source

Enable it in the setup.
```lua
require("crates").setup {
    ...
    completion = {
        ...
        cmp = {
            enabled = true,
        },
    },
}
```

And add it to your list of sources.
```lua
require("cmp").setup {
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

<details>
<summary>Or add it lazily.</summary>

```lua
vim.api.nvim_create_autocmd("BufRead", {
    group = vim.api.nvim_create_augroup("CmpSourceCargo", { clear = true }),
    pattern = "Cargo.toml",
    callback = function()
        cmp.setup.buffer({ sources = { { name = "crates" } } })
    end,
})
```
</details>

<details>
<summary>Custom nvim-cmp completion kinds</summary>

Enable custom completion kind in the config.
```lua
require("crates").setup {
    ...
    completion = {
        ...
        cmp = {
            use_custom_kind = true,
            -- optionally change the text and highlight groups
            kind_text = {
                version = "Version",
                feature = "Feature",
            },
            kind_highlight = {
                version = "CmpItemKindVersion",
                feature = "CmpItemKindFeature",
            },
        },
    },
}
```
This will set a custom completion `cmp.kind_text` and `cmp.kind_hl_group` attributes
to completion items for `nvim-cmp`.

Depending on how you've set up [the nvim-cmp menu](https://github.com/hrsh7th/nvim-cmp/wiki/Menu-Appearance#basic-customisations)
you'll have to handle these explicitly.
If you haven't changed `nvim-cmp`s `formatting` configuration everything should work out of the box.

Here's an example of how add custom icons.
```lua
local kind_icons = {
    ["Class"] = "🅒 ",
    ["Interface"] = "🅘 ",
    ["TypeParameter"] = "🅣 ",
    ["Struct"] = "🅢 ",
    ["Enum"] = "🅔 ",
    ["Unit"] = "🅤 ",
    ["EnumMember"] = "🅔 ",
    ["Constant"] = "🅒 ",
    ["Field"] = "🅕 ",
    ["Property"] = "🅟 ",
    ["Variable"] = "🅥 ",
    ["Reference"] = "🅡 ",
    ["Function"] = "🅕 ",
    ["Method"] = "🅜 ",
    ["Constructor"] = "🅒 ",
    ["Module"] = "🅜 ",
    ["File"] = "🅕 ",
    ["Folder"] = "🅕 ",
    ["Keyword"] = "🅚 ",
    ["Operator"] = "🅞 ",
    ["Snippet"] = "🅢 ",
    ["Value"] = "🅥 ",
    ["Color"] = "🅒 ",
    ["Event"] = "🅔 ",
    ["Text"] = "🅣 ",

    -- crates.nvim extensions
    ["Version"] = "🅥 ",
    ["Feature"] = "🅕 ",
}

require("cmp").setup({
    formatting = {
        fields = { "abbr", "kind" },
        format = function(_, vim_item)
            vim_item.kind = kind_icons[vim_item.kind] or "  "
            return vim_item
        end,
    },
})
```
</details>

### [coq.nvim](https://github.com/ms-jpq/coq_nvim) source
Enable it in the setup, and optionally change the display name.
```lua
require("crates").setup {
    ...
    completion = {
        ...
        coq = {
            enabled = true,
            name = "crates.nvim",
        },
    },
}
```

### Crate name completion

Crate names in dependencies can be completed from searches on `crates.io`. This has to be
enabled seperately:

```lua
require("crates").setup {
    ...
    completion = {
        crates = {
            enabled = true -- disabled by default
            max_results = 8 -- The maximum number of search results to display
            min_chars = 3 -- The minimum number of charaters to type before completions begin appearing
        }
    }
}
```

## Code actions
Code actions are supported in a few different ways, either by the [in-process language server](#in-process-language-server),
which also supports completion, or by the null-ls/none-ls source.

### [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim)/[none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) source
Enable it in the setup, and optionally change the display name.
```lua
require("crates").setup {
    ...
    null_ls = {
        enabled = true,
        name = "crates.nvim",
    },
}
```

# Config

For more information about the config types have a look at the vimdoc or [`lua/crates/config/types.lua`](https://github.com/Saecki/crates.nvim/blob/main/lua/crates/config/types.lua).

## Default

The icons in the default configuration require a patched font.<br>
Any [Nerd Font](https://www.nerdfonts.com/font-downloads) should work.
```lua
require("crates").setup {
    smart_insert = true,
    insert_closing_quote = true,
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    search_indicator = true,
    date_format = "%Y-%m-%d",
    thousands_separator = ".",
    notification_title = "crates.nvim",
    curl_args = { "-sL", "--retry", "1" },
    max_parallel_requests = 80,
    expand_crate_moves_cursor = true,
    enable_update_available_warning = true,
    on_attach = function(bufnr) end,
    text = {
        searching = "   Searching",
        loading = "   Loading",
        version = "   %s",
        prerelease = "   %s",
        yanked = "   %s",
        nomatch = "   No match",
        upgrade = "   %s",
        error = "   Error fetching crate",
    },
    highlight = {
        searching = "CratesNvimSearching",
        loading = "CratesNvimLoading",
        version = "CratesNvimVersion",
        prerelease = "CratesNvimPreRelease",
        yanked = "CratesNvimYanked",
        nomatch = "CratesNvimNoMatch",
        upgrade = "CratesNvimUpgrade",
        error = "CratesNvimError",
    },
    popup = {
        autofocus = false,
        hide_on_select = false,
        copy_register = '"',
        style = "minimal",
        border = "none",
        show_version_date = false,
        show_dependency_version = true,
        max_height = 30,
        min_width = 20,
        padding = 1,
        text = {
            title = " %s",
            pill_left = "",
            pill_right = "",
            description = "%s",
            created_label = " created        ",
            created = "%s",
            updated_label = " updated        ",
            updated = "%s",
            downloads_label = " downloads      ",
            downloads = "%s",
            homepage_label = " homepage       ",
            homepage = "%s",
            repository_label = " repository     ",
            repository = "%s",
            documentation_label = " documentation  ",
            documentation = "%s",
            crates_io_label = " crates.io      ",
            crates_io = "%s",
            lib_rs_label = " lib.rs         ",
            lib_rs = "%s",
            categories_label = " categories     ",
            keywords_label = " keywords       ",
            version = "  %s",
            prerelease = " %s",
            yanked = " %s",
            version_date = "  %s",
            feature = "  %s",
            enabled = " %s",
            transitive = " %s",
            normal_dependencies_title = " Dependencies",
            build_dependencies_title = " Build dependencies",
            dev_dependencies_title = " Dev dependencies",
            dependency = "  %s",
            optional = " %s",
            dependency_version = "  %s",
            loading = "  ",
        },
        highlight = {
            title = "CratesNvimPopupTitle",
            pill_text = "CratesNvimPopupPillText",
            pill_border = "CratesNvimPopupPillBorder",
            description = "CratesNvimPopupDescription",
            created_label = "CratesNvimPopupLabel",
            created = "CratesNvimPopupValue",
            updated_label = "CratesNvimPopupLabel",
            updated = "CratesNvimPopupValue",
            downloads_label = "CratesNvimPopupLabel",
            downloads = "CratesNvimPopupValue",
            homepage_label = "CratesNvimPopupLabel",
            homepage = "CratesNvimPopupUrl",
            repository_label = "CratesNvimPopupLabel",
            repository = "CratesNvimPopupUrl",
            documentation_label = "CratesNvimPopupLabel",
            documentation = "CratesNvimPopupUrl",
            crates_io_label = "CratesNvimPopupLabel",
            crates_io = "CratesNvimPopupUrl",
            lib_rs_label = "CratesNvimPopupLabel",
            lib_rs = "CratesNvimPopupUrl",
            categories_label = "CratesNvimPopupLabel",
            keywords_label = "CratesNvimPopupLabel",
            version = "CratesNvimPopupVersion",
            prerelease = "CratesNvimPopupPreRelease",
            yanked = "CratesNvimPopupYanked",
            version_date = "CratesNvimPopupVersionDate",
            feature = "CratesNvimPopupFeature",
            enabled = "CratesNvimPopupEnabled",
            transitive = "CratesNvimPopupTransitive",
            normal_dependencies_title = "CratesNvimPopupNormalDependenciesTitle",
            build_dependencies_title = "CratesNvimPopupBuildDependenciesTitle",
            dev_dependencies_title = "CratesNvimPopupDevDependenciesTitle",
            dependency = "CratesNvimPopupDependency",
            optional = "CratesNvimPopupOptional",
            dependency_version = "CratesNvimPopupDependencyVersion",
            loading = "CratesNvimPopupLoading",
        },
        keys = {
            hide = { "q", "<esc>" },
            open_url = { "<cr>" },
            select = { "<cr>" },
            select_alt = { "s" },
            toggle_feature = { "<cr>" },
            copy_value = { "yy" },
            goto_item = { "gd", "K", "<C-LeftMouse>" },
            jump_forward = { "<c-i>" },
            jump_back = { "<c-o>", "<C-RightMouse>" },
        },
    },
    completion = {
        insert_closing_quote = true,
        text = {
            prerelease = "  pre-release ",
            yanked = "  yanked ",
        },
        cmp = {
            enabled = false,
            use_custom_kind = true,
            kind_text = {
                version = "Version",
                feature = "Feature",
            },
            kind_highlight = {
                version = "CmpItemKindVersion",
                feature = "CmpItemKindFeature",
            },
        },
        coq = {
            enabled = false,
            name = "crates.nvim",
        },
        crates = {
            enabled = false,
            min_chars = 3,
            max_results = 8,
        },
    },
    null_ls = {
        enabled = false,
        name = "crates.nvim",
    },
    lsp = {
        enabled = false,
        name = "crates.nvim",
        on_attach = function(client, bufnr) end,
        actions = false,
        completion = false,
        hover = false,
    },
}
```

## Plain text

Replace these fields if you don"t have a patched font.
```lua
require("crates").setup {
    text = {
        loading = "  Loading...",
        version = "  %s",
        prerelease = "  %s",
        yanked = "  %s yanked",
        nomatch = "  Not found",
        upgrade = "  %s",
        error = "  Error fetching crate",
    },
    popup = {
        text = {
            title = "# %s",
            pill_left = "",
            pill_right = "",
            created_label = "created        ",
            updated_label = "updated        ",
            downloads_label = "downloads      ",
            homepage_label = "homepage       ",
            repository_label = "repository     ",
            documentation_label = "documentation  ",
            crates_io_label = "crates.io      ",
            lib_rs_label = "lib.rs         ",
            categories_label = "categories     ",
            keywords_label = "keywords       ",
            version = "%s",
            prerelease = "%s pre-release",
            yanked = "%s yanked",
            enabled = "* s",
            transitive = "~ s",
            normal_dependencies_title = "  Dependencies",
            build_dependencies_title = "  Build dependencies",
            dev_dependencies_title = "  Dev dependencies",
            optional = "? %s",
            loading = " ...",
        },
    },
    completion = {
        text = {
            prerelease = " pre-release ",
            yanked = " yanked ",
        },
    },
}
```

## Functions
```lua
-- Setup config and auto commands.
require("crates").setup(cfg: crates.UserConfig)

-- Disable UI elements (virtual text and diagnostics).
require("crates").hide()
-- Enable UI elements (virtual text and diagnostics).
require("crates").show()
-- Enable or disable UI elements (virtual text and diagnostics).
require("crates").toggle()
-- Update data. Optionally specify which `buf` to update.
require("crates").update(buf: integer?)
-- Reload data (clears cache). Optionally specify which `buf` to reload.
require("crates").reload(buf: integer?)

-- Upgrade the crate on the current line.
-- If the `alt` flag is passed as true, the opposite of the `smart_insert` config
-- option will be used to insert the version.
require("crates").upgrade_crate(alt: boolean?)
-- Upgrade the crates on the lines visually selected.
-- See `crates.upgrade_crate()`.
require("crates").upgrade_crates(alt: boolean?)
-- Upgrade all crates in the buffer.
-- See `crates.upgrade_crate()`.
require("crates").upgrade_all_crates(alt: boolean?)

-- Update the crate on the current line.
-- See `crates.upgrade_crate()`.
require("crates").update_crate(alt: boolean?)
-- Update the crates on the lines visually selected.
-- See `crates.upgrade_crate()`.
require("crates").update_crates(alt: boolean?)
-- Update all crates in the buffer.
-- See `crates.upgrade_crate()`.
require("crates").update_all_crates(alt: boolean?)

-- Expand a plain crate declaration into an inline table.
require("crates").expand_plain_crate_to_inline_table()
-- Extract an crate declaration from a dependency section into a table.
require("crates").extract_crate_into_table()
-- Convert crate dependency to use a git source instead of version number.
require("crates").use_git_source()

-- Open the homepage of the crate on the current line.
require("crates").open_homepage()
-- Open the repository page of the crate on the current line.
require("crates").open_repository()
-- Open the documentation page of the crate on the current line.
require("crates").open_documentation()
-- Open the `crates.io` page of the crate on the current line.
require("crates").open_crates_io()
-- Open the `lib.rs` page of the crate on the current line.
require("crates").open_lib_rs()

-- Returns whether there is information to show in a popup.
require("crates").popup_available(): boolean
-- Show/hide popup with crate details, all versions, all features or details about one feature.
-- If `popup.autofocus` is disabled calling this again will focus the popup.
require("crates").show_popup()
-- Same as `crates.show_popup()` but always show crate details.
require("crates").show_crate_popup()
-- Same as `crates.show_popup()` but always show versions.
require("crates").show_versions_popup()
-- Same as `crates.show_popup()` but always show features or features details.
require("crates").show_features_popup()
-- Same as `crates.show_popup()` but always show dependencies.
require("crates").show_dependencies_popup()
-- Focus the popup (jump into the floating window).
-- Optionally specify the line to jump to, inside the popup.
require("crates").focus_popup(line: integer?)
-- Hide the popup.
require("crates").hide_popup()

```

## Command
```vim
:Crates <subcmd>
```
Run a crates.nvim `<subcmd>`. All `<subcmd>`s are just wrappers around the
corresponding functions. These are the functions available as commands:
- `hide()`
- `show()`
- `toggle()`
- `update()`
- `reload()`
- `upgrade_crate()`
- `upgrade_crates()`
- `upgrade_all_crates()`
- `update_crate()`
- `update_crates()`
- `update_all_crates()`
- `use_git_source()`
- `expand_plain_crate_to_inline_table()`
- `extract_crate_into_table()`
- `open_homepage()`
- `open_repository()`
- `open_documentation()`
- `open_cratesio()`
- `popup_available()`
- `show_popup()`
- `show_crate_popup()`
- `show_versions_popup()`
- `show_features_popup()`
- `show_dependencies_popup()`
- `focus_popup()`
- `hide_popup()`

## Key mappings
Some examples of key mappings.
```lua
local crates = require("crates")
local opts = { silent = true }

vim.keymap.set("n", "<leader>ct", crates.toggle, opts)
vim.keymap.set("n", "<leader>cr", crates.reload, opts)

vim.keymap.set("n", "<leader>cv", crates.show_versions_popup, opts)
vim.keymap.set("n", "<leader>cf", crates.show_features_popup, opts)
vim.keymap.set("n", "<leader>cd", crates.show_dependencies_popup, opts)

vim.keymap.set("n", "<leader>cu", crates.update_crate, opts)
vim.keymap.set("v", "<leader>cu", crates.update_crates, opts)
vim.keymap.set("n", "<leader>ca", crates.update_all_crates, opts)
vim.keymap.set("n", "<leader>cU", crates.upgrade_crate, opts)
vim.keymap.set("v", "<leader>cU", crates.upgrade_crates, opts)
vim.keymap.set("n", "<leader>cA", crates.upgrade_all_crates, opts)

vim.keymap.set("n", "<leader>cx", crates.expand_plain_crate_to_inline_table, opts)
vim.keymap.set("n", "<leader>cX", crates.extract_crate_into_table, opts)

vim.keymap.set("n", "<leader>cH", crates.open_homepage, opts)
vim.keymap.set("n", "<leader>cR", crates.open_repository, opts)
vim.keymap.set("n", "<leader>cD", crates.open_documentation, opts)
vim.keymap.set("n", "<leader>cC", crates.open_crates_io, opts)
vim.keymap.set("n", "<leader>cL", crates.open_lib_rs, opts)
```

<details>
<summary>In vimscript</summary>

```vim
nnoremap <silent> <leader>ct :lua require("crates").toggle()<cr>
nnoremap <silent> <leader>cr :lua require("crates").reload()<cr>

nnoremap <silent> <leader>cv :lua require("crates").show_versions_popup()<cr>
nnoremap <silent> <leader>cf :lua require("crates").show_features_popup()<cr>
nnoremap <silent> <leader>cd :lua require("crates").show_dependencies_popup()<cr>

nnoremap <silent> <leader>cu :lua require("crates").update_crate()<cr>
vnoremap <silent> <leader>cu :lua require("crates").update_crates()<cr>
nnoremap <silent> <leader>ca :lua require("crates").update_all_crates()<cr>
nnoremap <silent> <leader>cU :lua require("crates").upgrade_crate()<cr>
vnoremap <silent> <leader>cU :lua require("crates").upgrade_crates()<cr>
nnoremap <silent> <leader>cA :lua require("crates").upgrade_all_crates()<cr>

nnoremap <silent> <leader>cx :lua require("crates").expand_plain_crate_to_inline_table()<cr>
nnoremap <silent> <leader>cX :lua require("crates").extract_crate_into_table()<cr>

nnoremap <silent> <leader>cH :lua require("crates").open_homepage()<cr>
nnoremap <silent> <leader>cR :lua require("crates").open_repository()<cr>
nnoremap <silent> <leader>cD :lua require("crates").open_documentation()<cr>
nnoremap <silent> <leader>cC :lua require("crates").open_crates_io()<cr>
nnoremap <silent> <leader>cL :lua require("crates").open_lib_rs()<cr>
```
</details>

## Show appropriate documentation in `Cargo.toml`
> [!NOTE]
> If you're using the in-process language server and `lsp.hover` is enabled, this isn't necessary.

How you might integrate `show_popup` into your `init.lua`.
```lua
local function show_documentation()
    local filetype = vim.bo.filetype
    if filetype == "vim" or filetype == "help" then
        vim.cmd('h '..vim.fn.expand('<cword>'))
    elseif filetype == "man" then
        vim.cmd('Man '..vim.fn.expand('<cword>'))
    elseif vim.fn.expand('%:t') == 'Cargo.toml' and require('crates').popup_available() then
        require('crates').show_popup()
    else
        vim.lsp.buf.hover()
    end
end

vim.keymap.set('n', 'K', show_documentation, { silent = true })
```

<details>
<summary>How you might integrate `show_popup` into your `init.vim`.</summary>

```vim
nnoremap <silent> K :call <SID>show_documentation()<cr>
function! s:show_documentation()
    if (index(["vim","help"], &filetype) >= 0)
        execute "h ".expand("<cword>")
    elseif (&filetype == "man")
        execute "Man ".expand("<cword>")
    elseif (expand("%:t") == "Cargo.toml" && luaeval("require('crates').popup_available()"))
        lua require("crates").show_popup()
    else
        lua vim.lsp.buf.hover()
    endif
endfunction
```
</details>

## Neoconf Integration

You can also set project-local settings if you have [Neoconf](https://github.com/folke/neoconf.nvim)
installed; all settings are exactly the same, but are under the "crates"
namespace.

Example:

```jsonc
// .neoconf.json

{
    //...
    "crates": {
        "smart_insert": false,
        "max_parallel_requests": 50,
        "completion": {
            "crates": {
                "enabled": false
            }
        }
    }
}
```
