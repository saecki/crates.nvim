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
__Do not edit the `README.md`, `doc/crates.txt` or wiki files.__

To update the README, vimdoc or wiki edit the files in `docgen/templates/*`
instead of their generated counter parts.

The generation finds placeholders inside the templates and uses either
some custom generation logic, or a file inside `docgen/shared/*` as a replacement.
For example
```
<SHARED:DEFAULT_CONFIGURATION>
```
would be replaced by the generated default configuration, but 
```
    <SHARED:keymaps.lua>
```
is replaced by the contents of the `docgen/shared/keymaps.lua` file.\
The indentation of the placeholder has to be a multiple of 4 spaces
and will be applied to the replacement file.


Documentation is automatically updated by github actions, but you can also
generate it yourself by running:
```
make doc
```

## Testing
There are currently only a few tests.
Execute them by running this command:
```
make test
```
