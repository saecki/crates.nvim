# crates.nvim
[![CI](https://github.com/saecki/crates.nvim/actions/workflows/CI.yml/badge.svg)](https://github.com/saecki/crates.nvim/actions/workflows/CI.yml)
![LOC](https://tokei.rs/b1/github/saecki/crates.nvim?category=code)

A neovim plugin that helps managing crates.io dependencies.

Feel free to open issues.

[Screencast from 2023-03-11 05-29-22.webm](https://user-images.githubusercontent.com/43008152/224464963-9810110f-2923-4346-a442-9d4f2723bdff.webm)

## Setup

### Installation
To use a stable release.

[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'saecki/crates.nvim', { 'tag': 'stable' }

lua require('crates').setup()
```

[__lazy.nvim__](https://github.com/folke/lazy.nvim)
```lua
{
    'saecki/crates.nvim',
    tag = 'stable',
    config = function()
        require('crates').setup()
    end,
}
```

<details>
<summary>If you're feeling adventurous and want to use the newest features.</summary>

[__vim-plug__](https://github.com/junegunn/vim-plug)
```
Plug 'saecki/crates.nvim'

lua require('crates').setup()
```

[__lazy.nvim__](https://github.com/folke/lazy.nvim)
```lua
{
    'saecki/crates.nvim',
    config = function()
        require('crates').setup()
    end,
}
```
</details>


<details>
<summary>For lazy loading.</summary>

```lua
{
    'saecki/crates.nvim',
    event = { "BufRead Cargo.toml" },
    config = function()
        require('crates').setup()
    end,
}
```
</details>

## [Documentation](https://github.com/Saecki/crates.nvim/wiki)
- [Stable](https://github.com/Saecki/crates.nvim/wiki/Documentation-unstable)
- [Unstable](https://github.com/Saecki/crates.nvim/wiki/Documentation-v0.4.0)

## Related projects
- [simrat39/rust-tools.nvim](https://github.com/simrat39/rust-tools.nvim)
- [mhinz/vim-crates](https://github.com/mhinz/vim-crates)
- [shift-d/crates.nvim](https://github.com/shift-d/crates.nvim)
- [kahgeh/ls-crates.nvim](https://github.com/kahgeh/ls-crates.nvim)

