local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local types = require("crates.types")
local Cond = types.Cond
local Span = types.Span
local SemVer = types.SemVer

local M = {}

local default_key_order = {
    "vers",
    "registry",
    "path",
    "git",
    "branch",
    "rev",
    "pkg",
    "def",
    "feat",
    "workspace",
    "opt",
}

---Returns the column at which to insert the key and whether there is another key before that
---Requires that the key to insert isn't present in the crate,
---and that at least one other key is present
---@param crate TomlCrate
---@param key string
---@return integer, boolean
function M.col_to_insert(crate, key)
    local col = 0
    local before = true
    for _, k in ipairs(default_key_order) do
        if key == k then
            if col ~= 0 then
                return col, true
            end

            before = false
            goto continue
        end

        ---@type TomlCrateEntry
        local entry = crate[k]
        if entry then
            if before then
                col = entry.decl_col.e
            else
                return entry.decl_col.s, false
            end
        end

        ::continue::
    end

    error("no other keys present")
end

---Returns the line at which to insert the key
---Requires that the key to insert isn't present in the crate
---@param crate TomlCrate
---@param key string
---@return integer
function M.line_to_insert(crate, key)
    local line = 0
    local before = false
    for _, k in ipairs(default_key_order) do
        if key == k then
            if line ~= 0 then
                return line
            end

            before = false
            goto continue
        end

        ---@type TomlCrateEntry
        local entry = crate[k]
        if entry then
            if before then
                line = entry.decl_col.e
            else
                return entry.line
            end
        end

        ::continue::
    end

    return crate.lines.s + 1
end

---comment
---@param buf integer
---@param crate TomlCrate
---@param name string
function M.rename_crate_package(buf, crate, name)
    ---@type integer, Span
    local line, col
    if crate.pkg then
        line = crate.pkg.line
        col = crate.pkg.col
    else
        line = crate.lines.s
        col = crate.explicit_name_col
    end

    vim.api.nvim_buf_set_text(buf, line, col.s, line, col.e, { name })
end

---@param buf integer
---@param crate TomlCrate
---@param text string
---@return Span
local function insert_version(buf, crate, text)
    if not crate.vers then
        if crate.syntax == TomlCrateSyntax.TABLE then
            local line = crate.lines.s + 1
            vim.api.nvim_buf_set_lines(
                buf, line, line, false,
                { 'version = "' .. text .. '"' }
            )
            return crate.lines:moved(0, 1)
        elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
            local line = crate.lines.s
            local col = M.col_to_insert(crate, "vers")
            vim.api.nvim_buf_set_text(
                buf, line, col, line, col,
                { ' version = "' .. text .. '",' }
            )
            return Span.pos(line)
        else -- crate.syntax == TomlCrateSyntax.PLAIN
            error("unreachable")
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
        return Span.pos(line)
    end
end

---Return a requirement version string with the same fields as `r` but values from `version`
---@param r Requirement
---@param version SemVer
---@return string
local function req_version_like(r, version)
    if version.pre then
        return version:display_req()
    else
        local v = SemVer.new({
            major = version.major,
            minor = r.vers.minor and version.minor or nil,
            patch = r.vers.patch and version.patch or nil,
        })
        return v:display_req()
    end
end

---@param crate TomlCrate
---@param version SemVer
---@return string
function M.smart_version_text(crate, version)
    if #crate:vers_reqs() == 0 then
        return version:display()
    end

    local pos = 1
    local text = ""
    for _, r in ipairs(crate:vers_reqs()) do
        if r.cond == Cond.EQ then
            local v = req_version_like(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v
        elseif r.cond == Cond.WL then
            if version.pre then
                text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. version:display_req()
            else
                local v = SemVer.new({
                    major = r.vers.major and version.major or nil,
                    minor = r.vers.minor and version.minor or nil,
                })
                local before = string.sub(crate.vers.text, pos, r.vers_col.s)
                local after = string.sub(crate.vers.text, r.vers_col.e + 1, r.cond_col.e)
                text = text .. before .. v:display_req() .. after
            end
        elseif r.cond == Cond.TL then
            local v = req_version_like(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v
        elseif r.cond == Cond.CR then
            local v = req_version_like(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v
        elseif r.cond == Cond.BL then
            local v = req_version_like(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v
        elseif r.cond == Cond.LT and not semver.matches_requirement(version, r) then
            local v = SemVer.new({
                major = version.major,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            })

            if v.patch then
                v.patch = v.patch + 1
            elseif v.minor then
                v.minor = v.minor + 1
            elseif v.major then
                v.major = v.major + 1
            end

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display_req()
        elseif r.cond == Cond.LE and not semver.matches_requirement(version, r) then
            ---@type SemVer
            local v

            if version.pre then
                v = version
            else
                v = SemVer.new({ major = version.major })
                if r.vers.minor or version.minor and version.minor > 0 then
                    v.minor = version.minor
                end
                if r.vers.patch or version.patch and version.patch > 0 then
                    v.minor = version.minor
                    v.patch = version.patch
                end
            end

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display_req()
        elseif r.cond == Cond.GT and not semver.matches_requirement(version, r) then
            local v = SemVer.new({
                major = r.vers.major and version.major or nil,
                minor = r.vers.minor and version.minor or nil,
                patch = r.vers.patch and version.patch or nil,
            })

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

            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v:display_req()
        elseif r.cond == Cond.GE and not semver.matches_requirement(version, r) then
            local v = req_version_like(r, version)
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.s) .. v
        else
            text = text .. string.sub(crate.vers.text, pos, r.vers_col.e)
        end

        pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
    end
    text = text .. string.sub(crate.vers.text, pos)

    return text
end

---@param crate TomlCrate
---@param version SemVer
---@param alt boolean|nil
---@return string
function M.version_text(crate, version, alt)
    local smart = state.cfg.smart_insert
    if alt then
        smart = not smart
    end

    if smart then
        return M.smart_version_text(crate, version)
    else
        return version:display_req()
    end
end

---@param buf integer
---@param crate TomlCrate
---@param repo_url string
function M.replace_version_with_git(buf, crate, repo_url)
    if not repo_url then
        return
    end

    if crate.vers then
        if crate.syntax == TomlCrateSyntax.PLAIN then
            local t = '{ git = "' .. repo_url .. '" }'
            local line = crate.vers.line
            vim.api.nvim_buf_set_text(
                buf, line, crate.vers.col.s - 1, line, crate.vers.col.e + 1, { t }
            )
            return
        elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
            local line = crate.vers.line
            local text = ' git = "' .. repo_url .. '"'
            vim.api.nvim_buf_set_text(
                buf, line, crate.vers.decl_col.s, line, crate.vers.col.e + 1, { text }
            )
            return
        else
            local line = crate.vers.line
            local text = 'git = "' .. repo_url .. '"'
            vim.api.nvim_buf_set_text(
                buf, line, crate.vers.decl_col.s, line, crate.vers.col.e + 1, { text }
            )
        end
    end
end

---@param buf integer
---@param crate TomlCrate
---@param version SemVer
---@param alt boolean|nil
---@return Span
function M.set_version(buf, crate, version, alt)
    local text = M.version_text(crate, version, alt)
    return insert_version(buf, crate, text)
end

---@param buf integer
---@param crates table<string,TomlCrate>
---@param info table<string,CrateInfo>
---@param alt boolean|nil
function M.upgrade_crates(buf, crates, info, alt)
    for k, c in pairs(crates) do
        local i = info[k]

        if i then
            local version = i.vers_upgrade or i.vers_update
            if version then
                M.set_version(buf, c, version.parsed, alt)
            end
        end
    end
end

---@param buf integer
---@param crates table<string,TomlCrate>
---@param info table<string,CrateInfo>
---@param alt boolean|nil
function M.update_crates(buf, crates, info, alt)
    for k, c in pairs(crates) do
        local i = info[k]

        if i then
            local version = i.vers_update
            if version then
                M.set_version(buf, c, version.parsed, alt)
            end
        end
    end
end

---@param buf integer
---@param crate TomlCrate
---@param feature ApiFeature
---@return Span
function M.enable_feature(buf, crate, feature)
    local t = '"' .. feature.name .. '"'
    if crate.feat then
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
        return Span.pos(crate.feat.line)
    end

    if crate.syntax == TomlCrateSyntax.TABLE then
        local line = M.line_to_insert(crate, "feat")
        vim.api.nvim_buf_set_lines(
            buf, line, line, false,
            { "features = [" .. t .. "]" }
        )
        return Span.pos(line)
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        local line = crate.lines.s
        local col, before = M.col_to_insert(crate, "feat")
        local text = ", features = [" .. t .. "]"
        if not before then
            text = " features = [" .. t .. "],"
        end
        vim.api.nvim_buf_set_text(
            buf, line, col, line, col,
            { text }
        )
        return Span.pos(line)
    else -- crate.syntax == TomlCrateSyntax.PLAIN then
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
        return Span.pos(line)
    end
end

---@param buf integer
---@param crate TomlCrate
---@param feature TomlFeature
---@return Span
function M.disable_feature(buf, crate, feature)
    -- check reference in case of duplicates
    ---@type integer
    local index
    for i, f in ipairs(crate.feat.items) do
        if f == feature then
            index = i
            break
        end
    end
    assert(index)

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
    return Span.pos(crate.feat.line)
end

---@param buf integer
---@param crate TomlCrate
---@return Span
function M.enable_def_features(buf, crate)
    vim.api.nvim_buf_set_text(
        buf,
        crate.def.line,
        crate.def.col.s,
        crate.def.line,
        crate.def.col.e,
        { "true" }
    )
    return Span.pos(crate.def.line)
end

---@param buf integer
---@param crate TomlCrate
---@return Span
local function disable_def_features(buf, crate)
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
    end

    if crate.syntax == TomlCrateSyntax.TABLE then
        local line = M.line_to_insert(crate, "def")
        vim.api.nvim_buf_set_lines(
            buf,
            line,
            line,
            false,
            { "default-features = false" }
        )
        return crate.lines:moved(0, 1)
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        local line = crate.lines.s
        local col, before = M.col_to_insert(crate, "def")
        local text = ", default-features = false"
        if not before then
            text = " default-features = false,"
        end
        vim.api.nvim_buf_set_text(
            buf, line, col, line, col,
            { text }
        )
        return crate.lines
    else -- crate.syntax == TomlCrateSyntax.PLAIN then
        local t = ", default-features = false }"
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
    end
end

---@param buf integer
---@param crate TomlCrate
---@param feature TomlFeature|nil
---@return Span
function M.disable_def_features(buf, crate, feature)
    if feature then
        if not crate.def or crate.def.col.s < crate.feat.col.s then
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

---@param buf integer
---@param crate TomlCrate
function M.expand_plain_crate_to_inline_table(buf, crate)
    if crate.syntax ~= TomlCrateSyntax.PLAIN then
        return
    end

    local text = crate.explicit_name .. ' = { version = "' .. crate.vers.text .. '" }'
    vim.api.nvim_buf_set_text(
        buf, crate.lines.s, crate.vers.decl_col.s, crate.lines.s, crate.vers.decl_col.e,
        { text }
    )

    if state.cfg.expand_crate_moves_cursor then
        local pos = { crate.lines.s + 1, #text - 2 }
        vim.api.nvim_win_set_cursor(0, pos)
    end
end

---@param buf integer
---@param crate TomlCrate
function M.extract_crate_into_table(buf, crate)
    if crate.syntax == TomlCrateSyntax.TABLE then
        return
    end

    -- remove original line
    vim.api.nvim_buf_set_lines(buf, crate.lines.s, crate.lines.e, false, {})

    -- insert table after dependency section
    local lines = {
        crate.section:display(crate.explicit_name),
    }
    if crate.vers then
        table.insert(lines, "version = " .. '"' .. crate.vers.text .. '"')
    end
    if crate.registry then
        table.insert(lines, "registry = " .. '"' .. crate.registry.text .. '"')
    end
    if crate.path then
        table.insert(lines, "path = " .. '"' .. crate.path.text .. '"')
    end
    if crate.git then
        table.insert(lines, "git = " .. '"' .. crate.git.text .. '"')
    end
    if crate.branch then
        table.insert(lines, "branch = " .. '"' .. crate.branch.text .. '"')
    end
    if crate.branch then
        table.insert(lines, "tag = " .. '"' .. crate.tag.text .. '"')
    end
    if crate.rev then
        table.insert(lines, "rev = " .. '"' .. crate.rev.text .. '"')
    end
    if crate.pkg then
        table.insert(lines, "package = " .. '"' .. crate.pkg.text .. '"')
    end
    if crate.workspace then
        table.insert(lines, "workspace = " .. '"' .. crate.workspace.text .. '"')
    end
    if crate.def then
        table.insert(lines, "default-features = " .. crate.def.text)
    end
    if crate.feat then
        table.insert(lines, "features = [" .. crate.feat.text .. "]")
    end
    if crate.opt then
        table.insert(lines, "optional = " .. '"' .. crate.opt.text .. '"')
    end

    table.insert(lines, "")

    local line = crate.section.lines.e - 1
    vim.api.nvim_buf_set_lines(buf, line, line, false, lines)
end

return M
