local record M
    record CrateInfo
        lines: Range
        vers_line: integer
        virt_text: {{string,string}}
        diagnostics: {vim.diagnostic.Diagnostic}
    end
    enum CrateScope
        "vers"
        "def"
        "feat"
    end
end

local CrateInfo = M.CrateInfo
local CrateScope = M.CrateScope
local core = require("crates.core")
local util = require("crates.util")
local semver = require("crates.semver")
local toml = require("crates.toml")
local Crate = toml.Crate
local CrateFeature = toml.CrateFeature
local Version = require("crates.api").Version
local Range = require("crates.types").Range



function M.crate_diagnostic(crate: Crate, message: string, severity: integer, scope: CrateScope|nil): vim.diagnostic.Diagnostic
    local d = {
        lnum = crate.lines.s,
        end_lnum = crate.lines.e,
        col = 0,
        end_col = 0,
        severity = severity,
        message = message,
        source = "crates",
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

function M.feat_diagnostic(crate: Crate, feat: CrateFeature, message: string, severity: integer): vim.diagnostic.Diagnostic
    return {
        lnum = crate.feat.line,
        end_lnum = crate.feat.line,
        col = crate.feat.col.s + feat.col.s,
        end_col = crate.feat.col.s + feat.col.e,
        severity = severity,
        message = message,
        source = "crates",
    }
end

function M.process_crate_versions(crate: Crate, versions: {Version}): CrateInfo
    local avoid_pre = core.cfg.avoid_prerelease and not crate:vers_is_pre()
    local newest, newest_pre, newest_yanked = util.get_newest(versions, avoid_pre, nil)
    newest = newest or newest_pre or newest_yanked

    local info = {
        lines = crate.lines,
        vers_line = crate.vers and crate.vers.line or crate.lines.s,
        virt_text = {},
        diagnostics = {},
    }
    if newest then
        if semver.matches_requirements(newest.parsed, crate:vers_reqs()) then
            -- version matches, no upgrade available
            info.virt_text = { { string.format(core.cfg.text.version, newest.num), core.cfg.highlight.version } }
        else
            -- version does not match, upgrade available
            local match, match_pre, match_yanked = util.get_newest(versions, avoid_pre, crate:vers_reqs())

            local upgrade_text = { string.format(core.cfg.text.upgrade, newest.num), core.cfg.highlight.upgrade }
            table.insert(info.diagnostics, M.crate_diagnostic(
                crate,
                core.cfg.diagnostic.vers_upgrade,
                vim.diagnostic.severity.WARN,
                "vers"
            ))

            if match then
                -- found a match
                info.virt_text = {
                    { string.format(core.cfg.text.version, match.num), core.cfg.highlight.version },
                    upgrade_text,
                }
            elseif match_pre then
                -- found a pre-release match
                info.virt_text = {
                    { string.format(core.cfg.text.prerelease, match_pre.num), core.cfg.highlight.prerelease },
                    upgrade_text,
                }
                table.insert(info.diagnostics, M.crate_diagnostic(
                    crate,
                    core.cfg.diagnostic.vers_pre,
                    vim.diagnostic.severity.WARN,
                    "vers"
                ))
            elseif match_yanked then
                -- found a yanked match
                info.virt_text = {
                    { string.format(core.cfg.text.yanked, match_yanked.num), core.cfg.highlight.yanked },
                    upgrade_text,
                }
                table.insert(info.diagnostics, M.crate_diagnostic(
                    crate,
                    core.cfg.diagnostic.vers_yanked,
                    vim.diagnostic.severity.ERROR,
                    "vers"
                ))
            else
                -- no match found
                info.virt_text = {
                    { core.cfg.text.nomatch, core.cfg.highlight.nomatch },
                    upgrade_text,
                }
                local message = core.cfg.diagnostic.vers_nomatch
                if not crate.vers then
                    message = core.cfg.diagnostic.crate_novers
                end
                table.insert(info.diagnostics, M.crate_diagnostic(
                    crate,
                    message,
                    vim.diagnostic.severity.ERROR,
                    "vers"
                ))
            end
        end
    else
        info.virt_text = { { core.cfg.text.error, core.cfg.highlight.error } }
        table.insert(info.diagnostics, M.crate_diagnostic(
            crate,
            core.cfg.diagnostic.crate_error_fetching,
            vim.diagnostic.severity.ERROR,
            "vers"
        ))
    end

    return info
end

function M.process_crates(crates: {Crate}): {string:Crate}, {vim.diagnostic.Diagnostic}
    local diagnostics = {}
    local cache: {string:Crate} = {}

    for _,c in ipairs(crates) do
        if cache[c.name] then
            table.insert(diagnostics, M.crate_diagnostic(
                cache[c.name],
                core.cfg.diagnostic.crate_dup_orig,
                vim.diagnostic.severity.HINT
            ))
            table.insert(diagnostics, M.crate_diagnostic(
                c,
                core.cfg.diagnostic.crate_dup,
                vim.diagnostic.severity.ERROR
            ))
        else
            cache[c.name] = c

            local feats: {string:CrateFeature} = {}
            for _,f in ipairs(c:feats()) do
                if feats[f.name] then
                    table.insert(diagnostics, M.feat_diagnostic(
                        c,
                        feats[f.name],
                        core.cfg.diagnostic.feat_dup_orig,
                        vim.diagnostic.severity.HINT
                    ))
                    table.insert(diagnostics, M.feat_diagnostic(
                        c,
                        f,
                        core.cfg.diagnostic.feat_dup,
                        vim.diagnostic.severity.WARN
                    ))
                else
                    feats[f.name] = f
                end
            end
        end
    end

    return cache, diagnostics
end

return M
