# Contributing

## Writing Code

> [!IMPORTANT]
> `lua/crates/config/types.lua` is automatically generated.

__To update it:__
1. Edit the schema in `lua/crates/config/init.lua`
2. Generate it by running `make types`

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

> [!IMPORTANT]
> Do not edit the `README.md`, `doc/crates.txt` or wiki files.\
> They are automatically generated.

__To update them:__
1. Edit the files in `docgen/templates` or `docgen/shared`
2. Optionally run `make doc` or let github actions do it

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
