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
__Do not edit files in the `lua` directory.__

Instead edit the files inside the `teal` directory
and compile all teal files to lua by running:
```
make build
```

## Documentation
__Do not edit the `README.md` or `doc/crates.txt` files.__

To update the README or vimdoc edit the `scripts/README.md.in` and
`scripts/crates.txt.in` files instead of their generated counter parts.

After editing one of the above, the configuration schema in
`lua/crates/config.tl` or public api functions in `lua/crates.tl` update the
docs by running this command:
```
make doc
```

## Testing
There are currently only a few tests.
Execute them by running this command:
```
make test
```
