local record M
    record VersContext
        buf: integer
        crate: toml.Crate
        versions: {Version}
    end
end

local VersContext = M.VersContext
local edit = require("crates.edit")
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local Range = types.Range
local Version = types.Version
local util = require("crates.util")

local function select_version(ctx: VersContext, line: integer, alt: boolean|nil)
    local index = popup.item_index(line)
    local crate = ctx.crate
    local version = ctx.versions[index]
    if not version then return end

    local line_range: Range
    line_range = edit.set_version(ctx.buf, crate, version.parsed, alt)

    -- update only crate version position, not the parsed requirements
    -- (or any other semantic information), so selecting another version
    -- with `smart_insert` will behave predictable
    if crate.syntax == "table" then
        for line_nr in line_range:iter() do
            local text = vim.api.nvim_buf_get_lines(ctx.buf, line_nr, line_nr + 1, false)[1]
            text = toml.trim_comments(text)

            local vers = toml.parse_crate_table_vers(text, line_nr)
            if vers then
                crate.vers = crate.vers or vers
                crate.vers.line = line_nr
                crate.vers.col = vers.col
                crate.vers.decl_col = vers.decl_col
                crate.vers.quote = vers.quote
            end
        end
    elseif crate.syntax == "plain" or crate.syntax == "inline_table" then
        local line_nr = line_range.s
        local text = vim.api.nvim_buf_get_lines(ctx.buf, line_nr, line_nr + 1, false)[1]
        text = toml.trim_comments(text)

        local c = toml.parse_crate(text, line_nr)
        if c and c.vers then
            crate.vers = crate.vers or c.vers
            crate.vers.line = line_nr
            crate.vers.col = c.vers.col
            crate.vers.decl_col = c.vers.decl_col
            crate.vers.quote = c.vers.quote
        end
    end

    if state.cfg.popup.hide_on_select then
        popup.hide()
    end
end

local function copy_version(versions: {Version}, line: integer)
    local index = popup.item_index(line)
    local version = versions[index]
    if not version then return end

    vim.fn.setreg(state.cfg.popup.copy_register, version.num)
end

function M.open(crate: toml.Crate, versions: {Version}, opts: WinOpts)
    popup.type = "versions"

    local title = string.format(state.cfg.popup.text.title, crate:package())
    local vers_width = 0
    local versions_text: {{HighlightText}} = {}

    for _,v in ipairs(versions) do
        local t: HighlightText = {}
        if v.yanked then
            t.text = string.format(state.cfg.popup.text.yanked, v.num)
            t.hl = state.cfg.popup.highlight.yanked
        elseif v.parsed.pre then
            t.text = string.format(state.cfg.popup.text.prerelease, v.num)
            t.hl = state.cfg.popup.highlight.prerelease
        else
            t.text = string.format(state.cfg.popup.text.version, v.num)
            t.hl = state.cfg.popup.highlight.version
        end

        table.insert(versions_text, { t })
        vers_width = math.max(vim.fn.strdisplaywidth(t.text) as integer, vers_width)
    end

    local date_width = 0
    if state.cfg.popup.show_version_date then
        for i,line in ipairs(versions_text) do
            local vers_text = line[1]
            local diff = vers_width - vim.fn.strdisplaywidth(vers_text.text) as integer
            local date = versions[i].created:display(state.cfg.date_format)
            vers_text.text = vers_text.text..string.rep(" ", diff)

            local date_text: HighlightText = {
                text = string.format(state.cfg.popup.text.version_date, date),
                hl = state.cfg.popup.highlight.version_date
            }
            table.insert(line, date_text)
            date_width = math.max(vim.fn.strdisplaywidth(date_text.text) as integer, date_width)
        end
    end

    local width = popup.win_width(title, vers_width + date_width)
    local height = popup.win_height(versions)
    popup.open_win(width, height, title, versions_text, opts, function(_win: integer, buf: integer)
        local ctx = {
            buf = util.current_buf(),
            crate = crate,
            versions = versions,
        }
        for _,k in ipairs(state.cfg.popup.keys.select) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    select_version(ctx, line)
                end,
                noremap = true,
                silent = true,
                desc = "Select version"
            })
        end

        for _,k in ipairs(state.cfg.popup.keys.select_alt) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    select_version(ctx, line, true)
                end,
                noremap = true,
                silent = true,
                desc = "Select version alt",
            })
        end

        for _,k in ipairs(state.cfg.popup.keys.copy_value) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    local line = util.cursor_pos()
                    copy_version(versions, line)
                end,
                noremap = true,
                silent = true,
                desc = "Copy version",
            })
        end
    end)
end

return M
