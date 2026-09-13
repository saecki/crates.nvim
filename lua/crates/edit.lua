local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local TomlCrateSyntax = toml.TomlCrateSyntax
local types = require("crates.types")
local Cond = types.Cond
local Span = types.Span
local SemVer = types.SemVer

local M = {}

---@alias TomlCrateEntryKey =
--- | "workspace"
--- | "vers"
--- | "registry"
--- | "path"
--- | "git"
--- | "branch"
--- | "tag"
--- | "rev"
--- | "pkg"
--- | "def"
--- | "feat"
--- | "opt"

local default_key_order = {
    "workspace",
    "vers",
    "registry",
    "path",
    "git",
    "branch",
    "tag",
    "rev",
    "pkg",
    "def",
    "feat",
    "opt",
}

---@param a_line integer
---@param a_col integer
---@param b_line integer
---@param b_col integer
---@return boolean
local function pos_before(a_line, a_col, b_line, b_col)
    return a_line < b_line or (a_line == b_line and a_col < b_col)
end

---@param text string
---@param col integer
---@return integer
local function skip_comma_space(text, col)
    local i = col + 1
    if text:sub(i, i) == "," then
        i = i + 1
        while text:sub(i, i) == " " do
            i = i + 1
        end
        return i - 1
    end
    return col
end

---Exclusive end of a value (`]` for a multiline array, after the closing quote otherwise).
---@param entry TomlCrateEntry
---@return integer, integer
local function entry_end_pos(entry)
    if entry.end_col then
        return entry.end_line or entry.line, entry.end_col + 1
    end
    local col = entry.col.e
    ---@cast entry TomlCrateString
    if entry.quote and entry.quote.e then
        col = col + 1
    end
    return entry.line, col
end

---Declaration span: start of the key through exclusive end of the value.
---@param entry TomlCrateEntry
---@return integer, integer, integer, integer
local function entry_decl_span(entry)
    local end_line, end_col = entry_end_pos(entry)
    if entry.end_line and entry.end_line ~= entry.line then
        return entry.line, entry.decl_col.s, end_line, end_col
    end
    return entry.line, entry.decl_col.s, entry.line, entry.decl_col.e
end

---Returns the buffer position at which to insert `key`, and whether another key precedes it.
---Requires that `key` is missing and that at least one other key is present.
---@param crate TomlCrate
---@param key TomlCrateEntryKey
---@return integer, integer, boolean
function M.insert_pos(crate, key)
    local ins_line = crate.lines.s
    local ins_col = 0
    local found_prev = false
    local before = true
    for _, k in ipairs(default_key_order) do
        if key == k then
            if found_prev then
                return ins_line, ins_col, true
            end

            before = false
            goto continue
        end

        ---@type TomlCrateEntry
        local entry = crate[k]
        if entry then
            if before then
                ins_line, ins_col = entry_end_pos(entry)
                found_prev = true
            else
                return entry.line, entry.decl_col.s, false
            end
        end

        ::continue::
    end

    if found_prev then
        return ins_line, ins_col, true
    end

    error("no other keys present")
end

---Returns the column at which to insert the key and whether there is another key before that.
---Requires that the key to insert isn't present in the crate,
---and that at least one other key is present
---@param crate TomlCrate
---@param key TomlCrateEntryKey
---@return integer, boolean
function M.col_to_insert(crate, key)
    local _, col, before = M.insert_pos(crate, key)
    return col, before
end

---Returns the line at which to insert the key
---Requires that the key to insert isn't present in the crate
---@param crate TomlCrate
---@param key TomlCrateEntryKey
---@return integer
function M.line_to_insert(crate, key)
    local line = 0
    local before = true
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
                line = (entry.end_line or entry.line) + 1
            else
                return entry.line
            end
        end

        ::continue::
    end

    return crate.lines.s + 1
end

---@param buf integer
---@param crate TomlCrate
---@param entry TomlCrateEntry
local function remove_inline_table_entry(buf, crate, entry)
    local s_line, s_col, e_line, e_col = entry_decl_span(entry)

    local prev_end_line, prev_end_col = nil, nil
    local next_start_line, next_start_col = nil, nil
    for _, k in ipairs(default_key_order) do
        ---@type TomlCrateEntry
        local e = crate[k]
        if e and e ~= entry then
            local es, ecs, ee, ece = entry_decl_span(e)
            if pos_before(es, ecs, s_line, s_col) then
                if not prev_end_line or pos_before(prev_end_line, prev_end_col, ee, ece) then
                    prev_end_line, prev_end_col = ee, ece
                end
            elseif pos_before(s_line, s_col, es, ecs) then
                if not next_start_line or pos_before(es, ecs, next_start_line, next_start_col) then
                    next_start_line, next_start_col = es, ecs
                end
            end
        end
    end

    local start_line, start_col = s_line, s_col
    local end_line, end_col = e_line, e_col
    local text = {}
    if prev_end_line == s_line then
        start_line, start_col = prev_end_line, prev_end_col
        if not next_start_line then
            text = { " " }
        end
    elseif next_start_line == e_line then
        end_line, end_col = next_start_line, next_start_col
        -- Suffix keys after `]` include the comma in `decl_col`; eat it so we
        -- don't leave `{ , version = ... }`.
        local end_text = vim.api.nvim_buf_get_lines(buf, end_line, end_line + 1, false)[1]
        end_col = skip_comma_space(end_text, end_col)
    end

    vim.api.nvim_buf_set_text(buf, start_line, start_col, end_line, end_col, text)
end

---Removes the key and returns the crate's span of lines after editing.
---@param buf integer
---@param crate TomlCrate
---@param key TomlCrateEntryKey
---@return Span
function M.remove_entry(buf, crate, key)
    ---@type TomlCrateEntry
    local entry = crate[key]

    if crate.syntax == TomlCrateSyntax.TABLE then
        local line = entry.line
        local end_line = line + 1
        if key == "feat" and entry.end_line and entry.end_line >= line then
            end_line = entry.end_line + 1
        end
        vim.api.nvim_buf_set_lines(buf, line, end_line, false, {})
        return crate.lines:moved(0, -(end_line - line))
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        remove_inline_table_entry(buf, crate, entry)
        return crate.lines
    else -- crate.syntax == TomlCrateSyntax.PLAIN then
        error("unreachable")
    end
end

---@param buf integer
---@param crate TomlCrate
---@param name string
function M.rename_crate_package(buf, crate, name)
    local line, col = crate:package_pos()
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
            local line, col = M.insert_pos(crate, "vers")
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
---@param alt boolean?
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
function M.use_git_source(buf, crate, repo_url)
    if not (repo_url and crate.vers and not crate.git) then
        return
    end

    local end_col = crate.vers.col.e
    if crate.vers.quote.e then
        end_col = end_col + 1
    end

    if crate.syntax == TomlCrateSyntax.PLAIN then
        local t = '{ git = "' .. repo_url .. '" }'
        local line = crate.vers.line
        vim.api.nvim_buf_set_text(
            buf, line, crate.vers.col.s - 1, line, end_col, { t }
        )
        return
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        local line = crate.vers.line
        local text = ' git = "' .. repo_url .. '"'
        vim.api.nvim_buf_set_text(
            buf, line, crate.vers.decl_col.s, line, end_col, { text }
        )
        return
    else
        local line = crate.vers.line
        local text = 'git = "' .. repo_url .. '"'
        vim.api.nvim_buf_set_text(
            buf, line, crate.vers.decl_col.s, line, end_col + 1, { text }
        )
    end
end

---@param buf integer
---@param crate TomlCrate
---@param version SemVer
---@param alt boolean?
---@return Span
function M.set_version(buf, crate, version, alt)
    local text = M.version_text(crate, version, alt)
    return insert_version(buf, crate, text)
end

---@param buf integer
---@param crates table<string,TomlCrate>
---@param info table<string,CrateInfo>
---@param alt boolean?
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
---@param alt boolean?
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
---@param feature string
---@return Span
function M.enable_feature(buf, crate, feature)
    local t = '"' .. feature .. '"'

    if crate.feat then
        local last_feat = crate.feat.items[#crate.feat.items]
        local line = crate.feat.end_line or crate.feat.line
        local col = crate.feat.end_col or crate.feat.col.e
        local multiline = crate.feat.end_line and crate.feat.end_line ~= crate.feat.line

        if multiline then
            if last_feat and not last_feat.comma then
                local comma_at = last_feat.col.e
                if last_feat.quote.e then
                    comma_at = comma_at + 1
                end
                vim.api.nvim_buf_set_text(buf, last_feat.line, comma_at, last_feat.line, comma_at, { "," })
            end
            local indent = "    "
            if last_feat then
                local last_line = vim.api.nvim_buf_get_lines(buf, last_feat.line, last_feat.line + 1, false)[1]
                indent = last_line:match("^%s*") or indent
            end
            vim.api.nvim_buf_set_text(buf, line, col, line, col, { indent .. t, "" })
            return Span.pos(line)
        end

        if last_feat then
            if not last_feat.comma then
                t = ", " .. t
            else
                t = " " .. t
            end
            if not last_feat.quote.e then
                t = last_feat.quote.s .. t
            end
        end

        vim.api.nvim_buf_set_text(buf, line, col, line, col, { t })
        return Span.pos(line)
    end

    if crate.syntax == TomlCrateSyntax.TABLE then
        local line = M.line_to_insert(crate, "feat")
        vim.api.nvim_buf_set_lines(
            buf, line, line, false,
            { "features = [" .. t .. "]" }
        )
        return Span.pos(line)
    elseif crate.syntax == TomlCrateSyntax.INLINE_TABLE then
        local line, col, before = M.insert_pos(crate, "feat")
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
    if state.cfg.remove_empty_features and #crate:feats() == 1 then
        return M.remove_entry(buf, crate, "feat")
    end

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

    local line = feature.line or crate.feat.line
    local col_start = feature.decl_col.s
    local col_end = feature.decl_col.e
    local multiline = crate.feat.end_line and crate.feat.end_line ~= crate.feat.line

    if multiline then
        local prev_feat = crate.feat.items[index - 1]
        local next_feat = crate.feat.items[index + 1]
        if prev_feat and prev_feat.line == line then
            col_start = prev_feat.col.e + 1
        elseif next_feat and next_feat.line == line then
            col_end = next_feat.col.s - 1
        elseif feature.comma then
            col_end = col_end + 1
        end
        vim.api.nvim_buf_set_text(buf, line, col_start, line, col_end, { "" })
        return Span.pos(line)
    end

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

    vim.api.nvim_buf_set_text(buf, line, col_start, line, col_end, { "" })
    return Span.pos(line)
end

---@param buf integer
---@param crate TomlCrate
---@return Span
function M.enable_def_features(buf, crate)
    if state.cfg.remove_enabled_default_features then
        return M.remove_entry(buf, crate, "def")
    else
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
        local line, col, before = M.insert_pos(crate, "def")
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
---@param feature TomlFeature?
---@return Span
function M.disable_def_features(buf, crate, feature)
    if feature then
        local def_before_feat = not crate.def
            or pos_before(crate.def.line, crate.def.col.s, crate.feat.line, crate.feat.col.s)
        if def_before_feat then
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

---@param feat TomlCrateFeat
---@return string[]
local function feat_as_table_lines(feat)
    local inner = vim.split(feat.text, "\n", { plain = true })
    if #inner == 1 then
        return { "features = [" .. inner[1] .. "]" }
    end

    ---@type string[]
    local out = { "features = [" .. inner[1] }
    for i = 2, #inner - 1 do
        table.insert(out, inner[i])
    end
    table.insert(out, inner[#inner] .. "]")
    return out
end

---@param buf integer
---@param crate TomlCrate
function M.extract_crate_into_table(buf, crate)
    if crate.syntax == TomlCrateSyntax.TABLE then
        return
    end

    local insert_line = crate.section.lines.e - (crate.lines.e - crate.lines.s)
    vim.api.nvim_buf_set_lines(buf, crate.lines.s, crate.lines.e, false, {})

    local lines = {
        crate.section:display(crate.explicit_name),
    }
    if crate.workspace then
        table.insert(lines, "workspace = " .. '"' .. crate.workspace.text .. '"')
    end
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
    if crate.tag then
        table.insert(lines, "tag = " .. '"' .. crate.tag.text .. '"')
    end
    if crate.rev then
        table.insert(lines, "rev = " .. '"' .. crate.rev.text .. '"')
    end
    if crate.pkg then
        table.insert(lines, "package = " .. '"' .. crate.pkg.text .. '"')
    end
    if crate.def then
        table.insert(lines, "default-features = " .. crate.def.text)
    end
    if crate.feat then
        for _, l in ipairs(feat_as_table_lines(crate.feat)) do
            table.insert(lines, l)
        end
    end
    if crate.opt then
        table.insert(lines, "optional = " .. '"' .. crate.opt.text .. '"')
    end

    table.insert(lines, "")

    vim.api.nvim_buf_set_lines(buf, insert_line, insert_line, false, lines)
end

return M
