local toml = require("crates.toml")

local function parse(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local _, crates = toml.parse_crates(buf)
    return crates, buf
end

local function col_of(line, substr)
    local s = line:find(substr, 1, true)
    assert.is_not_nil(s, "substring not found: " .. substr)
    return s - 1, s - 1 + #substr
end

describe("parse_crates multiline features", function()
    it("parses multiline features in dependency section", function()
        local lines = {
            '[dependencies.tokio]',
            'version = "1.0"',
            'features = [',
            '    "full",',
            '    "test-util"',
            ']'
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.equals("1.0", crate.vers.text)
        assert.is_not_nil(crate.feat)
        assert.equals(2, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
        assert.equals("test-util", crate.feat.items[2].name)
        assert.equals(3, crate.feat.items[1].line)
        assert.equals(4, crate.feat.items[2].line)
        assert.equals(5, crate.feat.end_line)
        local s, e = col_of(lines[4], "full")
        assert.equals(s, crate.feat.items[1].col.s)
        assert.equals(e, crate.feat.items[1].col.e)
    end)

    it("parses multiline features in inline dependency", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1.0", features = [',
            '    "full",',
            '    "test-util"',
            '] }'
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.equals("1.0", crate.vers.text)
        assert.is_not_nil(crate.vers.reqs)
        assert.is_true(#crate.vers.reqs > 0)
        assert.equals(2, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
        assert.equals("test-util", crate.feat.items[2].name)
        assert.equals(1, crate.lines.s)
        assert.equals(5, crate.lines.e)
        assert.equals(4, crate.feat.end_line)
        local s, e = col_of(lines[3], "full")
        assert.equals(s, crate.feat.items[1].col.s)
        assert.equals(e, crate.feat.items[1].col.e)
        assert.equals(2, crate.feat.items[1].line)
    end)

    it("parses single line features in inline dependency", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1.0", features = ["full"] }'
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.is_not_nil(crate.feat)
        assert.equals(1, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
        assert.equals(1, crate.feat.items[1].line)
        local s, e = col_of(lines[2], "full")
        assert.equals(s, crate.feat.items[1].col.s)
        assert.equals(e, crate.feat.items[1].col.e)
        assert.equals(crate.feat.line, crate.feat.end_line)
    end)

    it("parses version after a multiline features array", function()
        local lines = {
            '[dependencies]',
            'dep = { features = [',
            '    "feat1"',
            '], version = "1.2.3" }'
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("dep", crate:package())
        assert.equals("feat1", crate.feat.items[1].name)
        assert.is_not_nil(crate.vers)
        assert.equals("1.2.3", crate.vers.text)
        assert.is_true(#crate.vers.reqs > 0)
    end)

    it("does not swallow the next crate if the array is unclosed", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1", features = [',
            'serde = "1"',
        }
        local crates = parse(lines)

        assert.equals(2, #crates)
        assert.equals("tokio", crates[1]:package())
        assert.equals("serde", crates[2]:package())
        assert.equals("1", crates[2].vers.text)
    end)

    it("keeps in-progress features when the array is unclosed at EOF", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1", features = [',
            '    "full"',
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        assert.equals("tokio", crates[1]:package())
        assert.is_not_nil(crates[1].feat)
        assert.equals(1, #crates[1].feat.items)
        assert.equals("full", crates[1].feat.items[1].name)
        assert.equals(2, crates[1].feat.items[1].line)
        assert.equals(3, crates[1].lines.e)
    end)

    it("does not treat extra-features as a features array", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1", extra-features = [',
            '    "nope"',
            '] }',
        }
        local crates = parse(lines)

        assert.equals(1, #crates)
        assert.is_nil(crates[1].feat)
        assert.equals("1", crates[1].vers.text)
    end)
end)
