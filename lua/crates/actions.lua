local edit = require("crates.edit")
local util = require("crates.util")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local types = require("crates.types")
local CratesDiagnosticKind = types.CratesDiagnosticKind

local M = {}

---@class CratesAction
---@field name string
---@field action function

function M.use_git_source()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)

    if crate and crate.vers and not crate.git then
        local api_crate = state.api_cache[crate:package()]
        if api_crate and api_crate.repository then
            edit.use_git_source(buf, crate, api_crate.repository)
        else
            util.notify(vim.log.levels.WARN, "No repository URL found for crate: %s", crate:package())
        end
    end
end

---@param alt boolean?
function M.upgrade_crate(alt)
    local buf = util.current_buf()
    local key, crate = util.get_crate_on_line(buf)
    local info = util.get_buf_info(buf)
    if crate and info then
        edit.upgrade_crates(buf, { [key] = crate }, info, alt)
    end
end

---@param alt boolean?
function M.upgrade_crates(alt)
    local buf = util.current_buf()
    local lines = util.selected_lines()
    local crates = util.get_crates_on_line_span(buf, lines)
    local info = util.get_buf_info(buf)
    if next(crates) and info then
        edit.upgrade_crates(buf, crates, info, alt)
    end
end

---@param alt boolean?
function M.upgrade_all_crates(alt)
    local buf = util.current_buf()
    local cache = state.buf_cache[buf]
    if cache.crates and cache.info then
        edit.upgrade_crates(buf, cache.crates, cache.info, alt)
    end
end

---@param alt boolean?
function M.update_crate(alt)
    local buf = util.current_buf()
    local key, crate = util.get_crate_on_line(buf)
    local info = util.get_buf_info(buf)
    if crate and info then
        edit.update_crates(buf, { [key] = crate }, info, alt)
    end
end

function M.update_crates(alt)
    local buf = util.current_buf()
    local lines = util.selected_lines()
    local crates = util.get_crates_on_line_span(buf, lines)
    local info = util.get_buf_info(buf)
    if next(crates) and info then
        edit.update_crates(buf, crates, info, alt)
    end
end

---@param alt boolean?
function M.update_all_crates(alt)
    local buf = util.current_buf()
    local cache = state.buf_cache[buf]
    if cache.crates and cache.info then
        edit.update_crates(buf, cache.crates, cache.info, alt)
    end
end

function M.expand_plain_crate_to_inline_table()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        edit.expand_plain_crate_to_inline_table(buf, crate)
    end
end

function M.extract_crate_into_table()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        edit.extract_crate_into_table(buf, crate)
    end
end

function M.open_homepage()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        local api_crate = state.api_cache[crate:package()]
        if api_crate and api_crate.homepage then
            util.open_url(api_crate.homepage)
        else
            util.notify(vim.log.levels.INFO, "The crate '%s' has no homepage specified", crate:package())
        end
    end
end

function M.open_repository()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        local api_crate = state.api_cache[crate:package()]
        if api_crate and api_crate.repository then
            util.open_url(api_crate.repository)
        else
            util.notify(vim.log.levels.INFO, "The crate '%s' has no repository specified", crate:package())
        end
    end
end

function M.open_documentation()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        local api_crate = state.api_cache[crate:package()]
        local url = api_crate and api_crate.documentation
        url = url or util.docs_rs_url(crate:package())
        util.open_url(url)
    end
end

function M.open_crates_io()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        util.open_url(util.crates_io_url(crate:package()))
    end
end

function M.open_lib_rs()
    local buf = util.current_buf()
    local _, crate = util.get_crate_on_line(buf)
    if crate then
        util.open_url(util.lib_rs_url(crate:package()))
    end
end

---@param buf integer
---@param crate TomlCrate
---@param name string
---@return fun()
local function rename_crate_package_action(buf, crate, name)
    return function()
        edit.rename_crate_package(buf, crate, name)
    end
end

---@param buf integer
---@param d CratesDiagnostic
---@return fun()
local function remove_diagnostic_range_action(buf, d)
    return function()
        vim.api.nvim_buf_set_text(buf, d.lnum, d.col, d.end_lnum, d.end_col, {})
    end
end

---@param buf integer
---@param lines Span
---@return fun()
local function remove_lines_action(buf, lines)
    return function()
        vim.api.nvim_buf_set_lines(buf, lines.s, lines.e, false, {})
    end
end

---@param buf integer
---@param crate TomlCrate
---@param feat TomlFeature
---@return fun()
local function remove_feature_action(buf, crate, feat)
    return function()
        edit.disable_feature(buf, crate, feat)
    end
end

---@param buf integer
---@param crate TomlCrate
---@param feat TomlFeature
---@return fun()
local function remove_feature_dep_prefix_action(buf, crate, feat)
    return function()
        local line = crate.feat.line
        local col_start = crate.feat.col.s + feat.col.s
        local col_end = col_start + 4
        vim.api.nvim_buf_set_text(buf, line, col_start, line, col_end, {})
    end
end

---@return CratesAction[]
function M.get_actions()
    ---@type CratesAction[]
    local actions = {}

    local buf = util.current_buf()
    local buf_cache = state.buf_cache[buf]
    local line, col = util.cursor_pos()
    local key, crate = util.get_crate_on_line(buf, line)

    local diagnostics = util.get_buf_diagnostics(buf) or {}
    for _, d in ipairs(diagnostics) do
        if not d:contains(line, col) then
            goto continue
        end

        if d.kind == CratesDiagnosticKind.SECTION_DUP then
            table.insert(actions, {
                name = "remove duplicate section",
                action = remove_diagnostic_range_action(buf, d),
            })
        elseif d.kind == CratesDiagnosticKind.SECTION_DUP_ORIG then
            table.insert(actions, {
                name = "remove original section",
                action = remove_lines_action(buf, d.data["lines"]),
            })
        elseif d.kind == CratesDiagnosticKind.SECTION_INVALID then
            table.insert(actions, {
                name = "remove invalid dependency section",
                action = remove_diagnostic_range_action(buf, d),
            })
        elseif d.kind == CratesDiagnosticKind.CRATE_DUP then
            table.insert(actions, {
                name = "remove duplicate crate",
                action = remove_diagnostic_range_action(buf, d),
            })
        elseif d.kind == CratesDiagnosticKind.CRATE_DUP_ORIG then
            table.insert(actions, {
                name = "remove original crate",
                action = remove_diagnostic_range_action(buf, d),
            })
        elseif d.kind == CratesDiagnosticKind.CRATE_NAME_CASE then
            table.insert(actions, {
                name = "rename crate",
                action = rename_crate_package_action(buf, d.data["crate"], d.data["crate_name"]),
            })
        elseif crate and d.kind == CratesDiagnosticKind.FEAT_DUP then
            table.insert(actions, {
                name = "remove duplicate feature",
                action = remove_feature_action(buf, crate, d.data["feat"]),
            })
        elseif crate and d.kind == CratesDiagnosticKind.FEAT_DUP_ORIG then
            table.insert(actions, {
                name = "remove original feature",
                action = remove_feature_action(buf, crate, d.data["feat"]),
            })
        elseif crate and d.kind == CratesDiagnosticKind.FEAT_INVALID then
            table.insert(actions, {
                name = "remove invalid feature",
                action = remove_feature_action(buf, crate, d.data["feat"]),
            })
        elseif crate and d.kind == CratesDiagnosticKind.FEAT_EXPLICIT_DEP then
            table.insert(actions, {
                name = "remove `dep:` prefix",
                action = remove_feature_dep_prefix_action(buf, crate, d.data["feat"]),
            })
        end

        ::continue::
    end

    if key and crate then
        local info = buf_cache.info[key]
        if info then
            if info.vers_update then
                table.insert(actions, {
                    name = "update crate",
                    action = M.update_crate,
                })
            end
            if info.vers_upgrade then
                table.insert(actions, {
                    name = "upgrade crate",
                    action = M.upgrade_crate,
                })
            end
        end

        -- refactorings
        if crate.syntax == TomlCrateSyntax.PLAIN then
            table.insert(actions, {
                name = "expand crate to inline table",
                action = M.expand_plain_crate_to_inline_table,
            })
        end
        if crate.syntax ~= TomlCrateSyntax.TABLE then
            table.insert(actions, {
                name = "extract crate into table",
                action = M.extract_crate_into_table,
            })
        end

        if crate.vers and not crate.git then
            table.insert(actions, {
                name = "use git source",
                action = M.use_git_source,
            })
        end

        table.insert(actions, {
            name = "open documentation",
            action = M.open_documentation,
        })
        table.insert(actions, {
            name = "open crates.io",
            action = M.open_crates_io,
        })
        table.insert(actions, {
            name = "open lib.rs",
            action = M.open_lib_rs,
        })
    end

    local has_update = false
    local has_upgrade = false
    for _, info in pairs(buf_cache.info) do
        has_update = has_update or (info.vers_update ~= nil)
        has_upgrade = has_upgrade or (info.vers_upgrade ~= nil)
    end
    if has_update then
        table.insert(actions, {
            name = "update all crates",
            action = M.update_all_crates,
        })
    end
    if has_upgrade then
        table.insert(actions, {
            name = "upgrade all crates",
            action = M.upgrade_all_crates,
        })
    end

    return actions
end

return M
