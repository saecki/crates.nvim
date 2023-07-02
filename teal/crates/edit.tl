local record M end

local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Feature = types.Feature
local Range = types.Range
local SemVer = types.SemVer
local Requirement = types.Requirement

function M.rename_crate_package(buf: integer, crate: toml.Crate, name: string)
    local line, col: integer, Range
    if crate.pkg then
        line = crate.pkg.line
        col = crate.pkg.col
    else
        line = crate.lines.s
        col = crate.explicit_name_col
    end

    vim.api.nvim_buf_set_text(buf, line, col.s, line, col.e, { name })
end

local function insert_version(buf: integer, crate: toml.Crate, text: string): Range
    if not crate.vers then
        if crate.syntax == "table" then
            local line = crate.lines.s + 1
            vim.api.nvim_buf_set_lines(
                buf, line, line, false,
                { 'version = "' .. text .. '"' }
            )
            return crate.lines:moved(0, 1)
        elseif crate.syntax == "inline_table" then
            local line = crate.lines.s
            local col = math.min(
                crate.pkg and crate.pkg.col.s or 999,
                crate.def and crate.def.col.s or 999,
                crate.feat and crate.def.col.s or 999,
                crate.git and crate.git.decl_col.s or 999,
                crate.path and crate.path.decl_col.s or 999
            )
            vim.api.nvim_buf_set_text(
                buf, line, col, line, col,
                { ' version = "' .. text .. '",' }
            )
            return Range.pos(line)
        elseif crate.syntax == "plain" then
            return Range.empty() -- unreachable
        end
    else
        local t = text
        if state.cfg.insert_closing_quote and not crate.vers.quote.e then
            t = text .. crate.vers.quote.s
        end
        local line = crate.vers.line

        vim.api.nvim_buf_set_text(
            buf,
            line,
            crate.vers.col.s,
            line,
            crate.vers.col.e,
            { t }
        )
        return Range.pos(line)
    end
end

local function replace_existing(r: Requirement, version: SemVer): SemVer
    if version.pre then
        return version
    else
        return SemVer.new {
            major = version.major,
            minor = r.vers.minor and version.minor or nil,
            patch = r.vers.patch and version.patch or nil,
        }
    end
end

function M.smart_version_text(crate: toml.Crate, version: SemVer): string
    if #crate:vers_reqs() == 0 then
        return version:display()
    end

    local pos = 1
    local text = ""
    for _,r in ipairs(crate:vers_reqs()) do
        if r.cond == "eq" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "wl" then
            if version.pre then
                text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. version:display()
            else
                local v = SemVer.new {
                    major = r.vers.major and version.major or nil,
                    minor = r.vers.minor and version.minor or nil,
                }
                local before = string.sub(crate.vers.text, pos, r.vers_col.s)
                local after = string.sub(crate.vers.text, r.vers_col.e + 1, r.cond_col.e)
                text = text .. before .. v:display() .. after
            end
        elseif r.cond == "tl" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "cr" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "bl" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "lt" and not semver.matches_requirement(version, r) then
            local v = SemVer.new {
                major = version.major,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            }

            if v.patch then
                v.patch = v.patch + 1
            elseif v.minor then
                v.minor = v.minor + 1
            elseif v.major then
                v.major = v.major + 1
            end

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "le" and not semver.matches_requirement(version, r) then
            local v: SemVer

            if version.pre then
                v = version
            else
                v =  SemVer.new { major = version.major }
                if r.vers.minor or version.minor and version.minor > 0 then
                    v.minor = version.minor
                end
                if r.vers.patch or version.patch and version.patch > 0 then
                    v.minor = version.minor
                    v.patch = version.patch
                end
            end

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "gt" and not semver.matches_requirement(version, r) then
            local v = SemVer.new {
                major = r.vers.major and version.major or nil,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            }

            if v.patch then
                v.patch = v.patch - 1
                if v.patch < 0 then
                    v.patch = 0
                    v.minor = v.minor - 1
                end
            elseif v.minor then
                v.minor = v.minor - 1
                if v.minor < 0 then
                    v.minor = 0
                    v.major = v.major - 1
                end
            elseif v.major then
                v.major = v.major - 1
                if v.major < 0 then
                    v.major = 0
                end
            end

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        elseif r.cond == "ge" then
            local v = replace_existing(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display()
        else
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.e)
        end

        pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
    end
    text = text .. string.sub(crate.vers.text, pos)

    return text
end

function M.version_text(crate: toml.Crate, version: SemVer, alt: boolean|nil): string
    local smart = alt ~= state.cfg.smart_insert
    if smart then
        return M.smart_version_text(crate, version)
    else
        return version:display()
    end
end

function M.set_version(buf: integer, crate: toml.Crate, version: SemVer, alt: boolean|nil): Range
    local text = M.version_text(crate, version, alt)
    return insert_version(buf, crate, text)
end

function M.upgrade_crates(buf: integer, crates: {string:toml.Crate}, info: {string:CrateInfo}, alt: boolean|nil)
    for k,c in pairs(crates) do
        local i = info[k]

        if i then
            local version = i.vers_upgrade or i.vers_update
            if version then
                M.set_version(buf, c, version.parsed, alt)
            end
        end
    end
end

function M.update_crates(buf: integer, crates: {string:toml.Crate}, info: {string:CrateInfo}, alt: boolean|nil)
    for k,c in pairs(crates) do
        local i = info[k]

        if i then
            local version = i.vers_update
            if version then
                M.set_version(buf, c, version.parsed, alt)
            end
        end
    end
end

function M.enable_feature(buf: integer, crate: toml.Crate, feature: Feature): Range
    local t = '"' .. feature.name .. '"'
    if not crate.feat then
        if crate.syntax == "table" then
            local line = math.max(
                crate.vers and crate.vers.line + 1 or 0,
                crate.pkg and crate.pkg.line + 1 or 0,
                crate.def and crate.def.line + 1 or 0
            )
            line = line ~= 0 and line or math.min(
                crate.git and crate.git.line or 999,
                crate.path and crate.path.line or 999
            )
            vim.api.nvim_buf_set_lines(
                buf, line, line, false,
                { "features = [" .. t .."]" }
            )
            return Range.pos(line)
        elseif crate.syntax == "plain" then
            t = ", features = [" .. t .. "] }"
            local line = crate.vers.line
            local col = crate.vers.col.e
            if crate.vers.quote.e then
                col = col + 1
            else
                t = crate.vers.quote.s .. t
            end
            vim.api.nvim_buf_set_text(buf, line, col, line, col, { t })

            vim.api.nvim_buf_set_text(
                buf,
                line,
                crate.vers.col.s - 1,
                line,
                crate.vers.col.s - 1,
                { "{ version = " }
            )
            return Range.pos(line)
        elseif crate.syntax == "inline_table" then
            local line = crate.lines.s
            local text = ", features = [" .. t .. "]"
            local col = math.max(
                crate.vers and crate.vers.col.e + (crate.vers.quote.e and 1 or 0) or 0,
                crate.pkg and crate.pkg.col.e or 0,
                crate.def and crate.def.col.e or 0
            )
            if col == 0 then
                text = " features = [" .. t .. "],"
                col = math.min(
                    crate.git and crate.git.decl_col.s or 999,
                    crate.path and crate.path.decl_col.s or 999
                )
            end
            vim.api.nvim_buf_set_text(
                buf, line, col, line, col,
                { text }
            )
            return Range.pos(line)
        end
    else
        local last_feat = crate.feat.items[#crate.feat.items]
        if last_feat then
            if not last_feat.comma then
                t = ", " .. t
            end
            if not last_feat.quote.e then
                t = last_feat.quote.s .. t
            end
        end

        vim.api.nvim_buf_set_text(
            buf,
            crate.feat.line,
            crate.feat.col.e,
            crate.feat.line,
            crate.feat.col.e,
            { t }
        )
        return Range.pos(crate.feat.line)
    end
end

function M.disable_feature(buf: integer, crate: toml.Crate, feature: toml.Feature): Range
    -- check reference in case of duplicates
    local index: integer
    for i,f in ipairs(crate.feat.items) do
        if f == feature then
            index = i
            break
        end
    end
    if not index then return end

    local col_start = feature.decl_col.s
    local col_end = feature.decl_col.e
    if index == 1 then
        if #crate.feat.items > 1 then
            col_end = crate.feat.items[2].col.s - 1
        elseif feature.comma then
            col_end = col_end + 1
        end
    else
        local prev_feature = crate.feat.items[index - 1]
        col_start = prev_feature.col.e + 1
    end

    vim.api.nvim_buf_set_text(
        buf,
        crate.feat.line,
        crate.feat.col.s + col_start,
        crate.feat.line,
        crate.feat.col.s + col_end,
        { "" }
    )
    return Range.pos(crate.feat.line)
end

function M.enable_def_features(buf: integer, crate: toml.Crate): Range
    vim.api.nvim_buf_set_text(
        buf,
        crate.def.line,
        crate.def.col.s,
        crate.def.line,
        crate.def.col.e,
        { "true" }
    )
    return Range.pos(crate.def.line)
end

local function disable_def_features(buf: integer, crate: toml.Crate): Range
    if crate.def then
        local line = crate.def.line
        vim.api.nvim_buf_set_text(
            buf,
            line,
            crate.def.col.s,
            line,
            crate.def.col.e,
            { "false" }
        )
        return crate.lines
    else
        if crate.syntax == "table" then
            local line = math.max(
                crate.vers and crate.vers.line + 1 or 0,
                crate.pkg and crate.pkg.line + 1 or 0
            )
            line = line ~= 0 and line or math.min(
                crate.feat and crate.feat.line or 999,
                crate.git and crate.git.line or 999,
                crate.path and crate.path.line or 999
            )
            vim.api.nvim_buf_set_lines(
                buf,
                line,
                line,
                false,
                { "default_features = false" }
            )
            return crate.lines:moved(0, 1)
        elseif crate.syntax == "plain" then
            local t = ", default_features = false }"
            local col = crate.vers.col.e
            if crate.vers.quote.e then
                col = col + 1
            else
                t = crate.vers.quote.s .. t
            end
            local line = crate.vers.line
            vim.api.nvim_buf_set_text(
                buf,
                line,
                col,
                line,
                col,
                { t }
            )

            vim.api.nvim_buf_set_text(
                buf,
                line,
                crate.vers.col.s - 1,
                line,
                crate.vers.col.s - 1,
                { "{ version = " }
            )
            return crate.lines
        elseif crate.syntax == "inline_table" then
            local line = crate.lines.s
            local text = ", default_features = false"
            local col = math.max(
                crate.vers and crate.vers.col.e + (crate.vers.quote.e and 1 or 0) or 0,
                crate.pkg and crate.pkg.col.e or 0
            )
            if col == 0 then
                text = " default_features = false,"
                col = math.min(
                    crate.feat and crate.def.col.s or 999,
                    crate.git and crate.git.decl_col.s or 999,
                    crate.path and crate.path.decl_col.s or 999
                )
            end
            vim.api.nvim_buf_set_text(
                buf, line, col, line, col,
                { text }
            )
            return crate.lines
        end
    end
end

function M.disable_def_features(buf: integer, crate: toml.Crate, feature: toml.Feature|nil): Range
    if feature then
        if crate.def and crate.def.col.s < crate.feat.col.s then
            M.disable_feature(buf, crate, feature)
            return disable_def_features(buf, crate)
        else
            local lines = disable_def_features(buf, crate)
            M.disable_feature(buf, crate, feature)
            return lines
        end
    else
        return disable_def_features(buf, crate)
    end
end

function M.expand_plain_crate_to_inline_table(buf: integer, crate: toml.Crate)
    if crate.syntax ~= "plain" then
        return
    end

    vim.api.nvim_buf_set_text(
        buf, crate.lines.s, crate.vers.decl_col.s, crate.lines.s, crate.vers.decl_col.e,
        { crate.explicit_name .. ' = { version = "' .. crate.vers.text .. '" }' }
    )
end

function M.extract_crate_into_table(buf: integer, crate: toml.Crate)
    if crate.syntax == "table" then
        return
    end

    -- remove original line
    vim.api.nvim_buf_set_lines( buf, crate.lines.s, crate.lines.e, false, {})

    -- insert table after dependency section
    local lines = {
        crate.section:display(crate.explicit_name),
    }
    if crate.vers then
        table.insert(lines, "version = " .. '"' .. crate.vers.text ..'"')
    end
    if crate.registry then
        table.insert(lines, "registry = " .. '"' .. crate.registry.text ..'"')
    end
    if crate.path then
        table.insert(lines, "path = " .. '"' .. crate.path.text ..'"')
    end
    if crate.git then
        table.insert(lines, "git = " .. '"' .. crate.git.text ..'"')
    end
    if crate.branch then
        table.insert(lines, "branch = " .. '"' .. crate.branch.text ..'"')
    end
    if crate.rev then
        table.insert(lines, "rev = " .. '"' .. crate.rev.text ..'"')
    end
    if crate.pkg then
        table.insert(lines, "package = " .. '"' .. crate.pkg.text ..'"')
    end
    if crate.workspace then
        table.insert(lines, "workspace = " .. '"' .. crate.workspace.text ..'"')
    end
    if crate.def then
        table.insert(lines, "default_features = " .. '"' .. crate.def.text ..'"')
    end
    if crate.feat then
        table.insert(lines, "features = [" .. crate.feat.text .. "]")
    end
    if crate.opt then
        table.insert(lines, "optional = " .. '"' .. crate.opt.text ..'"')
    end

    table.insert(lines, "")

    local line = crate.section.lines.e - 1
    vim.api.nvim_buf_set_lines(buf, line, line, false, lines)
end

return M
