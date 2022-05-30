local record M
    enum SectionScope
        "header"
    end

    enum CrateScope
        "vers"
        "def"
        "feat"
    end
end

local CrateScope = M.CrateScope
local SectionScope = M.SectionScope
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Dependency = types.Dependency
local Diagnostic = types.Diagnostic
local DiagnosticKind = types.DiagnosticKind
local Version = types.Version
local util = require("crates.util")

local function section_diagnostic(
    section: toml.Section,
    severity: integer,
    kind: DiagnosticKind,
    message: string,
    scope: SectionScope|nil,
    data: {string:any}
): Diagnostic
    local d = Diagnostic.new {
        lnum = section.lines.s,
        end_lnum = section.lines.e,
        col = 0,
        end_col = 0,
        severity = severity,
        kind = kind,
        message = message,
        data = data,
    }

    if scope == "header" then
        d.end_lnum = d.lnum + 1
    end

    return d
end

local function crate_diagnostic(
    crate: toml.Crate,
    severity: integer,
    kind: DiagnosticKind,
    message: string,
    scope: CrateScope|nil,
    data: {string:any}
): Diagnostic
    local d = Diagnostic.new {
        lnum = crate.lines.s,
        end_lnum = crate.lines.e,
        col = 0,
        end_col = 0,
        severity = severity,
        kind = kind,
        message = message,
        data = data,
    }

    if not scope then
        return d
    end

    if scope == "vers" then
        if crate.vers then
            d.lnum = crate.vers.line
            d.end_lnum = crate.vers.line
            d.col = crate.vers.col.s
            d.end_col = crate.vers.col.e
        end
    elseif scope == "def" then
        if crate.def then
            d.lnum = crate.def.line
            d.end_lnum = crate.def.line
            d.col = crate.def.col.s
            d.end_col = crate.def.col.e
        end
    elseif scope == "feat" then
        if crate.feat then
            d.lnum = crate.feat.line
            d.end_lnum = crate.feat.line
            d.col = crate.feat.col.s
            d.end_col = crate.feat.col.e
        end
    end

    return d
end

local function feat_diagnostic(
    crate: toml.Crate,
    feat: toml.Feature,
    severity: integer,
    kind: DiagnosticKind,
    message: string,
    data: {string:any}|nil
): Diagnostic
    return Diagnostic.new {
        lnum = crate.feat.line,
        end_lnum = crate.feat.line,
        col = crate.feat.col.s + feat.col.s,
        end_col = crate.feat.col.s + feat.col.e,
        severity = severity,
        kind = kind,
        message = message,
        data = data,
    }
end

function M.process_crates(sections: {toml.Section}, crates: {toml.Crate}): {string:toml.Crate}, {Diagnostic}
    local diagnostics = {}
    local s_cache: {string:toml.Section} = {}
    local cache: {string:toml.Crate} = {}

    for _,s in ipairs(sections) do
        local key = s.text:gsub("%s+", "")

        if s.invalid then
            table.insert(diagnostics, section_diagnostic(
                s,
                vim.diagnostic.severity.WARN,
                "section_invalid",
                state.cfg.diagnostic.section_invalid
            ))
        elseif s_cache[key] then
            table.insert(diagnostics, section_diagnostic(
                s_cache[key],
                vim.diagnostic.severity.HINT,
                "section_dup_orig",
                state.cfg.diagnostic.section_dup_orig,
                "header",
                { lines = s_cache[key].lines }
            ))
            table.insert(diagnostics, section_diagnostic(
                s,
                vim.diagnostic.severity.ERROR,
                "section_dup",
                state.cfg.diagnostic.section_dup
            ))
        else
            s_cache[key] = s
        end
    end

    for _,c in ipairs(crates) do
        local key = c:cache_key()
        if c.section.invalid then
            goto continue
        end

        if cache[key] then
            table.insert(diagnostics, crate_diagnostic(
                cache[key],
                vim.diagnostic.severity.HINT,
                "crate_dup_orig",
                state.cfg.diagnostic.crate_dup_orig
            ))
            table.insert(diagnostics, crate_diagnostic(
                c,
                vim.diagnostic.severity.ERROR,
                "crate_dup",
                state.cfg.diagnostic.crate_dup
            ))
        else
            cache[key] = c

            if c.def then
                if c.def.text ~= "false" and c.def.text ~= "true" then
                    table.insert(diagnostics, crate_diagnostic(
                        c,
                        vim.diagnostic.severity.ERROR,
                        "def_invalid",
                        state.cfg.diagnostic.def_invalid,
                        "def"
                    ))
                end
            end

            local feats: {string:toml.Feature} = {}
            for _,f in ipairs(c:feats()) do
                local orig = feats[f.name]
                if orig then
                    table.insert(diagnostics, feat_diagnostic(
                        c,
                        feats[f.name],
                        vim.diagnostic.severity.HINT,
                        "feat_dup_orig",
                        state.cfg.diagnostic.feat_dup_orig,
                        { feat = orig }
                    ))
                    table.insert(diagnostics, feat_diagnostic(
                        c,
                        f,
                        vim.diagnostic.severity.WARN,
                        "feat_dup",
                        state.cfg.diagnostic.feat_dup,
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

function M.process_crate_versions(crate: toml.Crate, versions: {Version}): CrateInfo, {Diagnostic}
    local avoid_pre = state.cfg.avoid_prerelease and not crate:vers_is_pre()
    local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
    newest = newest or newest_pre or newest_yanked

    local info: CrateInfo = {
        lines = crate.lines,
        vers_line = crate.vers and crate.vers.line or crate.lines.s,
    }
    local diagnostics = {}

    if newest then
        if semver.matches_requirements(newest.parsed, crate:vers_reqs()) then
            -- version matches, no upgrade available
            info.vers_match = newest
            info.match_kind = "version"

            if crate.vers and crate.vers.text ~= util.version_text(crate, newest.parsed) then
                info.match_kind = "update"
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.HINT,
                    "vers_update",
                    state.cfg.diagnostic.vers_update,
                    "vers"
                ))
            end
        else
            -- version does not match, possibly upgrade/downgrade available
            local match, match_pre, match_yanked = util.get_newest(versions, avoid_pre, crate:vers_reqs())
            local m = match or match_pre or match_yanked
            info.vers_match = m
            info.vers_change = newest

            if m then
                if semver.is_lower(m.parsed, newest.parsed) then
                    info.change_kind = "upgrade"
                else
                    info.change_kind = "downgrade"
                end
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.WARN,
                    "vers_upgrade",
                    state.cfg.diagnostic.vers_upgrade,
                    "vers"
                ))
            end

            if match then
                -- found a match
                if crate.vers and crate.vers.text ~= util.version_text(crate, match.parsed) then
                    info.match_kind = "update"
                    table.insert(diagnostics, crate_diagnostic(
                        crate,
                        vim.diagnostic.severity.HINT,
                        "vers_update",
                        state.cfg.diagnostic.vers_update,
                        "vers"
                    ))
                else
                    info.match_kind = "version"
                end
            elseif match_pre then
                -- found a pre-release match
                info.match_kind = "prerelease"

                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.WARN,
                    "vers_pre",
                    state.cfg.diagnostic.vers_pre,
                    "vers"
                ))
                local change_msg = util.uppercase(info.change_kind)
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.HINT,
                    "vers_pre_change",
                    string.format(state.cfg.diagnostic.vers_pre_change, change_msg),
                    "vers"
                ))
            elseif match_yanked then
                -- found a yanked match
                info.match_kind = "yanked"

                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.ERROR,
                    "vers_yanked",
                    state.cfg.diagnostic.vers_yanked,
                    "vers"
                ))
                local change_msg = util.uppercase(info.change_kind)
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.HINT,
                    "vers_yanked_change",
                    string.format(state.cfg.diagnostic.vers_yanked_change, change_msg),
                    "vers"
                ))
            else
                -- no match found
                info.match_kind = "nomatch"

                -- TODO: fix this and only show if no git or path was specified
                -- if not crate.vers then
                --     kind = "crate_novers"
                -- end

                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.ERROR,
                    "vers_nomatch",
                    state.cfg.diagnostic.vers_nomatch,
                    "vers"
                ))
                table.insert(diagnostics, crate_diagnostic(
                    crate,
                    vim.diagnostic.severity.HINT,
                    "vers_nomatch_change",
                    state.cfg.diagnostic.vers_nomatch_change,
                    "vers"
                ))
            end
        end
    else
        table.insert(diagnostics, crate_diagnostic(
            crate,
            vim.diagnostic.severity.ERROR,
            "crate_error_fetching",
            state.cfg.diagnostic.crate_error_fetching,
            "vers"
        ))
    end

    return info, diagnostics
end

function M.process_crate_deps(crate: toml.Crate, version: Version, deps: {Dependency}): {Diagnostic}
    local diagnostics = {}

    local valid_feats = {}
    for _,f in ipairs(version.features) do
        table.insert(valid_feats, f.name)
    end
    for _,d in ipairs(deps) do
        if d.opt then
            table.insert(valid_feats, d.name)
        end
    end

    if not state.cfg.disable_invalid_feature_diagnostic then
        for _,f in ipairs(crate:feats()) do
            if not vim.tbl_contains(valid_feats, f.name) then
                table.insert(diagnostics, feat_diagnostic(
                    crate,
                    f,
                    vim.diagnostic.severity.ERROR,
                    "feat_invalid",
                    state.cfg.diagnostic.feat_invalid,
                    { feat = f }
                ))
            end
        end
    end

    return diagnostics
end

return M
