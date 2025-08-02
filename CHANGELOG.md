# Changelog

## Unreleased

### Breaking Changes
- deprecate the nvim-cmp, coq_nvim, and null-ls sources (#172)

### Bug Fixes
- missing crates in completion (#170)
- prevent lsp request from beeing endlesly pending (#167)
- handle winborder:get return correctly (#165)

### Features
- support nvim 0.11 winborder as popup.border (#163)

## v0.7.1

### Bug Fixes
- api: make crate id lowercase (#164)

## v0.7.0

### Features
- custom custom blink.cmp kind name, highlight, and icon
- update blink.cmp kind icons
- add remove_enabled_default_features config option
- add remove_empty_features config option

### Bug Fixes
- sort fetched crate versions (#156)
- invalid dependency section warnings (#160)
- set edit range completing crate versions (#161)
- prevent update diagnostics from showing for matching pre-releases (#162)
