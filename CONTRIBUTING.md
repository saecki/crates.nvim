# Contributing

## Writing Code

### How `core.update()` works
```
     ┌─────────┐
     │  Toml   │
     │ Parsing │
     └────┬────┘
          ├───────────────┐
          ▼               ▼
    ┌────────────┐ ┌─────────────┐   ┌────────┐
    │   Fetch    │ │   Offline   │   │   Ui   │
    │ Crate Data │ │ Diagnostics ├──▶│ Update │
    └─────┬──────┘ └─────────────┘   └────────┘
          ├─────────────────┐
          ▼                 ▼
    ┌──────────────┐ ┌─────────────┐   ┌────────┐
    │    Fetch     │ │    Crate    │   │   Ui   │
    │ Dependencies │ │ Diagnostics ├──▶│ Update │
    └──────────────┘ └─────────────┘   └────────┘
          │
          ▼
    ┌──────────────┐   ┌────────┐
    │   Feature    │   │   Ui   │
    │ Diagnostics  ├──▶│ Update │
    └──────────────┘   └────────┘
```

## Testing

### Requirements
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
    - Placed inside the root of this repository

There are currently only a few tests.
Execute them by running this command:
```
make test
```

## Writing Documentation

### Requirements
- [Luarocks](https://luarocks.org/)
    - macos: `brew install luarocks`
    - fedora: `dnf install luarocks`
    - ubuntu: `apt install luarocks`
    - arch: `pacman -S install luarocks`
- [Inspect](https://github.com/kikito/inspect.lua)
    - `luarocks install inspect`

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
