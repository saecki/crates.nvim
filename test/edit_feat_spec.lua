local config = require("crates.config")
local edit = require("crates.edit")
local state = require("crates.state")
local toml = require("crates.toml")

state.cfg = config.build({
    remove_empty_features = false,
})

local function parse(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local _, crates = toml.parse_crates(buf)
    return crates[1], buf
end

describe("edit multiline features", function()
    it("enables a feature before the closing bracket", function()
        local lines = {
            '[dependencies]',
            'diesel = { version = "1.4.8", features = [',
            '  "uuidv07",',
            '  "extras",',
            '] }',
        }
        local crate, buf = parse(lines)
        edit.enable_feature(buf, crate, "mysql")

        local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals('diesel = { version = "1.4.8", features = [', result[2])
        assert.equals('  "uuidv07",', result[3])
        assert.equals('  "extras",', result[4])
        assert.equals('  "mysql"', result[5])
        assert.equals('] }', result[6])
        assert.is_nil(result[2]:find('"mysql"', 1, true))
    end)

    it("disables a middle feature on its own line", function()
        local lines = {
            '[dependencies]',
            'diesel = { version = "1.4.8", features = [',
            '  "uuidv07",',
            '  "extras",',
            '  "mysql",',
            '] }',
        }
        local crate, buf = parse(lines)
        edit.disable_feature(buf, crate, crate.feat.items[2])

        local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals('  "uuidv07",', result[3])
        assert.is_nil(result[4]:find('"extras"', 1, true))
        assert.equals('  "mysql",', result[5])
    end)

    it("enables a feature in a table-style multiline array", function()
        local lines = {
            '[dependencies.tokio]',
            'version = "1.0"',
            'features = [',
            '    "full",',
            ']',
        }
        local crate, buf = parse(lines)
        edit.enable_feature(buf, crate, "rt")

        local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals('    "full",', result[4])
        assert.equals('    "rt"', result[5])
        assert.equals(']', result[6])
    end)

    it("enable then disable does not leave a stray quote", function()
        local lines = {
            '[dependencies]',
            'diesel = { version = "1.4.8", features = [',
            '  "uuidv07",',
            '  "extras",',
            '] }',
        }
        local crate, buf = parse(lines)
        edit.enable_feature(buf, crate, "mysql")
        crate = toml.refresh_crate(buf, crate)
        local added = crate:get_feat("mysql")
        assert.is_not_nil(added)
        edit.disable_feature(buf, crate, added)

        local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = table.concat(result, "\n")
        assert.is_nil(text:find('"mysql"', 1, true))
        local close
        for _, l in ipairs(result) do
            if l:find("]", 1, true) then
                close = l
            end
        end
        assert.equals("] }", close:match("%S.*"))
        assert.is_nil(close:find('"', 1, true))
        local _, crates = toml.parse_crates(buf)
        assert.equals(2, #crates[1].feat.items)
    end)

    it("refreshes spans after two edits", function()
        local lines = {
            '[dependencies]',
            'diesel = { version = "1.4.8", features = [',
            '  "uuidv07",',
            '] }',
        }
        local crate, buf = parse(lines)
        edit.enable_feature(buf, crate, "extras")
        crate = toml.refresh_crate(buf, crate)
        edit.enable_feature(buf, crate, "mysql")

        local result = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        assert.is_not_nil(result:find('"uuidv07"', 1, true))
        assert.is_not_nil(result:find('"extras"', 1, true))
        assert.is_not_nil(result:find('"mysql"', 1, true))
        local _, crates = toml.parse_crates(buf)
        assert.equals(3, #crates[1].feat.items)
    end)
end)
