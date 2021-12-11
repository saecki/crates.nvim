# Contributing

## Requirements

- [Neovim](https://github.com/neovim/neovim)
- [Luarocks](https://luarocks.org/)
    - macos: `brew install luarocks`
    - fedora: `dnf install luarocks`
    - ubuntu: `apt install luarocks`
    - arch: `pacman -S install luarocks`
- [Teal](https://github.com/teal-language/tl)
    - `luarocks install tl`
- [Inspect](https://github.com/kikito/inspect.lua)
    - `luarocks install inspect`

## Writing code
__Do not edit files in the `lua` dir.__

Instead edit the files inside the `teal` dir
and compile all teal files to lua by running:
```
tl build
```

## Documentation
__Do not edit the `README.md` or `doc/crates.txt` files.__

To update the README or vimdoc edit the `scripts/README.md.in` and
`scripts/crates.txt.in` files instead of their generated counter parts.

After editing one of the above, the configuration schema in
`lua/crates/config.tl` or public api functions in `lua/crates.tl` update the
docs by running this command:
```
./scripts/gen_doc.lua
```
