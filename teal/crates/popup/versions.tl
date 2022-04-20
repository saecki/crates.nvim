local record M
    record VersContext
        buf: integer
        crate: Crate
        versions: {Version}
    end
end

local VersContext = M.VersContext
local api = require("crates.api")
local Version = api.Version
local core = require("crates.core")
local popup = require("crates.popup.common")
local HighlightText = popup.HighlightText
local WinOpts = popup.WinOpts
local toml = require("crates.toml")
local Crate = toml.Crate
local types = require("crates.types")
local Range = types.Range
local util = require("crates.util")

local function select_version(ctx: VersContext, line: integer, alt: boolean|nil)
    local index = line - popup.TOP_OFFSET
    local crate = ctx.crate
    local version = ctx.versions[index]
    if not version then return end

    local line_range: Range
    line_range = util.set_version(ctx.buf, crate, version.parsed, alt)

    -- update crate position
    for l in line_range:iter() do
        local text = vim.api.nvim_buf_get_lines(ctx.buf, l, l + 1, false)[1]
        text = toml.trim_comments(text)
        if crate.syntax == "table" then
            local c = toml.parse_crate_table_vers(text)
            if c and c.vers then
                crate.vers.line = l
                crate.vers.col = c.vers.col
                crate.vers.decl_col = c.vers.decl_col
                crate.vers.quote = c.vers.quote
            end
        elseif crate.syntax == "plain" or crate.syntax == "inline_table" then
            local c = toml.parse_crate(text)
            if c and c.vers then
                crate.vers.line = l
                crate.vers.col = c.vers.col
                crate.vers.decl_col = c.vers.decl_col
                crate.vers.quote = c.vers.quote
            end
        end
    end
end

local function copy_version(versions: {Version}, line: integer)
    local index = line - popup.TOP_OFFSET
    local version = versions[index]
    if not version then return end

    vim.fn.setreg(core.cfg.popup.copy_register, version.num)
end

function M.open(crate: Crate, versions: {Version}, opts: WinOpts)
    popup.type = "versions"

    local title = string.format(core.cfg.popup.text.title, crate.name)
    local vers_width = 0
    local versions_text: {HighlightText} = {}

    for _,v in ipairs(versions) do
        local text, hl: string, string
        if v.yanked then
            text = string.format(core.cfg.popup.text.yanked, v.num)
            hl = core.cfg.popup.highlight.yanked
        elseif v.parsed.pre then
            text = string.format(core.cfg.popup.text.prerelease, v.num)
            hl = core.cfg.popup.highlight.prerelease
        else
            text = string.format(core.cfg.popup.text.version, v.num)
            hl = core.cfg.popup.highlight.version
        end

        table.insert(versions_text, { text = text, hl = hl })
        vers_width = math.max(vim.fn.strdisplaywidth(text) as integer, vers_width)
    end

    local date_width = 0
    if core.cfg.popup.show_version_date then
        for i,v in ipairs(versions_text) do
            local diff = vers_width - vim.fn.strdisplaywidth(v.text) as integer
            local date = versions[i].created:display(core.cfg.date_format)
            v.text = v.text..string.rep(" ", diff)
            v.suffix = string.format(core.cfg.popup.text.version_date, date)
            v.suffix_hl = core.cfg.popup.highlight.version_date

            date_width = math.max(vim.fn.strdisplaywidth(v.suffix) as integer, date_width)
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
        for _,k in ipairs(core.cfg.popup.keys.select) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    select_version(ctx, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Select version"
            })
        end

        for _,k in ipairs(core.cfg.popup.keys.select_alt) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    select_version(ctx, vim.api.nvim_win_get_cursor(0)[1], true)
                end,
                noremap = true,
                silent = true,
                desc = "Select version alt",
            })
        end

        for _,k in ipairs(core.cfg.popup.keys.copy_version) do
            vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
                callback = function()
                    copy_version(versions, vim.api.nvim_win_get_cursor(0)[1])
                end,
                noremap = true,
                silent = true,
                desc = "Copy version",
            })
        end
    end)
end

return M
