local edit = require("crates.edit")
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local DepKind = toml.DepKind
local TomlSectionKind = toml.TomlSectionKind
local types = require("crates.types")
local CratesDiagnostic = types.CratesDiagnostic
local CratesDiagnosticKind = types.CratesDiagnosticKind
local MatchKind = types.MatchKind
local util = require("crates.util")

local M = {}

---@enum SectionScope
local SectionScope = {
    HEADER = 1,
}

---@enum CrateScope
local CrateScope = {
    VERS = 1,
    DEF = 2,
    FEAT = 3,
    PACKAGE = 4,
}

---@param section TomlSection
---@param kind CratesDiagnosticKind
---@param severity integer
---@param scope SectionScope|nil
---@param data table<string,any>|nil
---@return CratesDiagnostic
local function section_diagnostic(section, kind, severity, scope, data)
    local d = CratesDiagnostic.new({
        lnum = section.lines.s,
        end_lnum = section.lines.e - 1,
        col = 0,
        end_col = 999,
        severity = severity,
        kind = kind,
        data = data,
    })

    if scope == SectionScope.HEADER then
        d.end_lnum = d.lnum + 1
    end

    return d
end

---@param crate TomlCrate
---@param kind CratesDiagnosticKind
---@param severity integer
---@param scope CrateScope|nil
---@param data table<string,any>|nil
---@return CratesDiagnostic
local function crate_diagnostic(crate, kind, severity, scope, data)
    local d = CratesDiagnostic.new({
        lnum = crate.lines.s,
        end_lnum = crate.lines.e - 1,
        col = 0,
        end_col = 999,
        severity = severity,
        kind = kind,
        data = data,
    })

    if not scope then
        return d
    end

    if scope == CrateScope.VERS then
        if crate.vers then
            d.lnum = crate.vers.line
            d.end_lnum = crate.vers.line
            d.col = crate.vers.col.s
            d.end_col = crate.vers.col.e
        end
    elseif scope == CrateScope.DEF then
        if crate.def then
            d.lnum = crate.def.line
            d.end_lnum = crate.def.line
            d.col = crate.def.col.s
            d.end_col = crate.def.col.e
        end
    elseif scope == CrateScope.FEAT then
        if crate.feat then
            d.lnum = crate.feat.line
            d.end_lnum = crate.feat.line
            d.col = crate.feat.col.s
            d.end_col = crate.feat.col.e
        end
    elseif scope == CrateScope.PACKAGE then
        local pkg_line, pkg_col = crate:package_pos()
        d.lnum = pkg_line
        d.end_lnum = pkg_line
        d.col = pkg_col.s
        d.end_col = pkg_col.e
    end

    return d
end

---@param crate TomlCrate
---@param feat TomlFeature
---@param kind CratesDiagnosticKind
---@param severity integer
---@param data table<string,any>|nil
---@return CratesDiagnostic
local function feat_diagnostic(crate, feat, kind, severity, data)
    return CratesDiagnostic.new({
        lnum = crate.feat.line,
        end_lnum = crate.feat.line,
        col = crate.feat.col.s + feat.col.s,
        end_col = crate.feat.col.s + feat.col.e,
        severity = severity,
        kind = kind,
        data = data,
    })
end

---@param sections TomlSection[]
---@param crates TomlCrate[]
---@return table<string,TomlCrate>
---@return CratesDiagnostic[]
function M.process_crates(sections, crates)
    ---@type CratesDiagnostic[]
    local diagnostics = {}
    ---@type table<string,TomlSection>
    local s_cache = {}
    ---@type table<string,TomlCrate>
    local cache = {}

    for _, s in ipairs(sections) do
        local key = s.text:gsub("%s+", "")

        if s.workspace and s.kind ~= TomlSectionKind.DEFAULT then
            table.insert(diagnostics, section_diagnostic(
                s,
                CratesDiagnosticKind.WORKSPACE_SECTION_NOT_DEFAULT,
                vim.diagnostic.severity.WARN
            ))
        elseif s.workspace and s.target ~= nil then
            table.insert(diagnostics, section_diagnostic(
                s,
                CratesDiagnosticKind.WORKSPACE_SECTION_HAS_TARGET,
                vim.diagnostic.severity.ERROR
            ))
        elseif s.invalid then
            table.insert(diagnostics, section_diagnostic(
                s,
                CratesDiagnosticKind.SECTION_INVALID,
                vim.diagnostic.severity.WARN
            ))
        elseif s_cache[key] then
            table.insert(diagnostics, section_diagnostic(
                s_cache[key],
                CratesDiagnosticKind.SECTION_DUP_ORIG,
                vim.diagnostic.severity.HINT,
                SectionScope.HEADER,
                { lines = s_cache[key].lines }
            ))
            table.insert(diagnostics, section_diagnostic(
                s,
                CratesDiagnosticKind.SECTION_DUP,
                vim.diagnostic.severity.ERROR
            ))
        else
            s_cache[key] = s
        end
    end

    for _, c in ipairs(crates) do
        local key = c:cache_key()
        if c.section.invalid then
            goto continue
        end

        if cache[key] then
            table.insert(diagnostics, crate_diagnostic(
                cache[key],
                CratesDiagnosticKind.CRATE_DUP_ORIG,
                vim.diagnostic.severity.HINT
            ))
            table.insert(diagnostics, crate_diagnostic(
                c,
                CratesDiagnosticKind.CRATE_DUP,
                vim.diagnostic.severity.ERROR
            ))
        else
            cache[key] = c

            if c.def then
                if c.def.text ~= "false" and c.def.text ~= "true" then
                    table.insert(diagnostics, crate_diagnostic(
                        c,
                        CratesDiagnosticKind.DEF_INVALID,
                        vim.diagnostic.severity.ERROR,
                        CrateScope.DEF
                    ))
                end
            end

            ---@type table<string,TomlFeature>
            local feats = {}
            for _, f in ipairs(c:feats()) do
                local orig = feats[f.name]
                if orig then
                    table.insert(diagnostics, feat_diagnostic(
                        c,
                        feats[f.name],
                        CratesDiagnosticKind.FEAT_DUP_ORIG,
                        vim.diagnostic.severity.HINT,
                        { feat = orig }
                    ))
                    table.insert(diagnostics, feat_diagnostic(
                        c,
                        f,
                        CratesDiagnosticKind.FEAT_DUP,
                        vim.diagnostic.severity.WARN,
                        { feat = f }
                    ))
                else
                    feats[f.name] = f
                end
            end
        end

        ::continue::
    end

    return cache, diagnostics
end

---@param crate TomlCrate
---@param api_crate ApiCrate|nil
---@return CrateInfo
---@return CratesDiagnostic[]
function M.process_api_crate(crate, api_crate)
    local versions = api_crate and api_crate.versions
    local newest, newest_pre, newest_yanked = util.get_newest(versions, nil)
    newest = newest or newest_pre or newest_yanked

    ---@type CrateInfo
    local info = {
        lines = crate.lines,
        vers_line = crate.vers and crate.vers.line or crate.lines.s,
        match_kind = MatchKind.NOMATCH,
    }
    local diagnostics = {}

    if crate.dep_kind == DepKind.REGISTRY then
        if api_crate then
            if api_crate.name ~= crate:package() then
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    CratesDiagnosticKind.CRATE_NAME_CASE,
                    vim.diagnostic.severity.ERROR,
                    CrateScope.PACKAGE,
                    { crate = crate, crate_name = api_crate.name }
                ))
            end
        end

        if newest then
            if semver.matches_requirements(newest.parsed, crate:vers_reqs()) then
                -- version matches, no upgrade available
                info.vers_match = newest
                info.match_kind = MatchKind.VERSION

                if crate.vers and crate.vers.text ~= edit.version_text(crate, newest.parsed) then
                    info.vers_update = newest
                end
            else
                -- version does not match, upgrade available
                local match, match_pre, match_yanked = util.get_newest(versions, crate:vers_reqs())
                info.vers_match = match or match_pre or match_yanked
                info.vers_upgrade = newest

                if info.vers_match then
                    if crate.vers and crate.vers.text ~= edit.version_text(crate, info.vers_match.parsed) then
                        info.vers_update = info.vers_match
                    end
                end

                if state.cfg.enable_update_available_warning then
                    table.insert(diagnostics, crate_diagnostic(
                        crate,
                        CratesDiagnosticKind.VERS_UPGRADE,
                        vim.diagnostic.severity.WARN,
                        CrateScope.VERS
                    ))
                end

                if match then
                    -- found a match
                    info.match_kind = MatchKind.VERSION
                elseif match_pre then
                    -- found a pre-release match
                    info.match_kind = MatchKind.PRERELEASE
                    table.insert(diagnostics, crate_diagnostic(
                        crate,
                        CratesDiagnosticKind.VERS_PRE,
                        vim.diagnostic.severity.ERROR,
                        CrateScope.VERS
                    ))
                elseif match_yanked then
                    -- found a yanked match
                    info.match_kind = MatchKind.YANKED
                    table.insert(diagnostics, crate_diagnostic(
                        crate,
                        CratesDiagnosticKind.VERS_YANKED,
                        vim.diagnostic.severity.ERROR,
                        CrateScope.VERS
                    ))
                else
                    -- no match found
                    local kind = CratesDiagnosticKind.VERS_NOMATCH
                    if not crate.vers then
                        kind = CratesDiagnosticKind.CRATE_NOVERS
                    end
                    table.insert(diagnostics, crate_diagnostic(
                        crate,
                        kind,
                        vim.diagnostic.severity.ERROR,
                        CrateScope.VERS
                    ))
                end
            end

            -- invalid features diagnostics
            if info.vers_match then
                for _, f in ipairs(crate:feats()) do
                    if string.sub(f.name, 1, 4) == "dep:" then
                        table.insert(diagnostics, feat_diagnostic(
                            crate,
                            f,
                            CratesDiagnosticKind.FEAT_EXPLICIT_DEP,
                            vim.diagnostic.severity.ERROR,
                            { feat = f }
                        ))
                    elseif not info.vers_match.features:get_feat(f.name) then
                        table.insert(diagnostics, feat_diagnostic(
                            crate,
                            f,
                            CratesDiagnosticKind.FEAT_INVALID,
                            vim.diagnostic.severity.ERROR,
                            { feat = f }
                        ))
                    end
                end
            end
        else
            table.insert(diagnostics, crate_diagnostic(
                crate,
                CratesDiagnosticKind.CRATE_ERROR_FETCHING,
                vim.diagnostic.severity.ERROR,
                CrateScope.VERS
            ))
        end
    end

    return info, diagnostics
end

return M
