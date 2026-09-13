local config = require("crates.config")
local edit = require("crates.edit")
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")

local function parse(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local _, crates = toml.parse_crates(buf)
    return crates[1], buf
end

local function buf_text(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("inline multiline edit bugs", function()
    before_each(function()
        state.cfg = config.build({
            remove_empty_features = true,
        })
    end)

    it("inserts default-features on the version line when features come first", function()
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { features = [',
            '    "net"',
            '], version = "1.0" }',
        })
        edit.disable_def_features(buf, crate)

        local result = buf_text(buf)
        assert.equals("[dependencies]", result[1])
        assert.equals('tokio = { features = [', result[2])
        assert.equals('    "net"', result[3])
        assert.is_not_nil(result[4]:find("default%-features = false", 1))
        assert.is_not_nil(result[4]:find('version = "1.0"', 1, true))
        assert.is_nil(result[2]:find("default%-features"))
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates)
        assert.is_not_nil(crates[1].def)
        assert.equals("false", crates[1].def.text)
        assert.equals("1.0", crates[1].vers.text)
    end)

    it("removes a multiline features array without leaving a stray comma", function()
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { features = [',
            '    "net"',
            '], version = "1.0" }',
        })
        edit.disable_feature(buf, crate, crate.feat.items[1])

        local result = buf_text(buf)
        assert.equals("[dependencies]", result[1])
        assert.equals(2, #result)
        assert.equals('tokio = { version = "1.0" }', result[2])
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates)
        assert.is_nil(crates[1].feat)
        assert.equals("1.0", crates[1].vers.text)
    end)

    it("removes multiline features when version is on the opening line", function()
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { version = "1.0", features = [',
            '    "net"',
            "] }",
        })
        edit.disable_feature(buf, crate, crate.feat.items[1])

        local result = buf_text(buf)
        assert.equals(2, #result)
        assert.is_nil(result[2]:find("features", 1, true))
        assert.is_not_nil(result[2]:find('version = "1.0"', 1, true))
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates)
        assert.is_nil(crates[1].feat)
    end)

    it("extracts a multiline inline crate before the next section", function()
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { version = "1.0", features = [',
            '    "full",',
            '    "test-util"',
            "] }",
            "",
            "[dev-dependencies]",
            'serde = "1"',
        })
        edit.extract_crate_into_table(buf, crate)

        local result = buf_text(buf)
        local text = table.concat(result, "\n")
        for _, line in ipairs(result) do
            assert.is_nil(line:find("\n", 1, true))
        end
        assert.is_not_nil(text:find("%[dependencies%.tokio%]", 1))
        assert.is_not_nil(text:find('version = "1.0"', 1, true))
        assert.is_not_nil(text:find('"full"', 1, true))
        assert.is_not_nil(text:find('"test-util"', 1, true))
        assert.is_not_nil(text:find("%[dev%-dependencies%]", 1))
        assert.is_not_nil(text:find('serde = "1"', 1, true))

        local dep_header, table_header, dev_header
        for i, line in ipairs(result) do
            if line == "[dependencies]" then
                dep_header = i
            elseif line == "[dependencies.tokio]" then
                table_header = i
            elseif line == "[dev-dependencies]" then
                dev_header = i
            end
        end
        assert.is_not_nil(dep_header)
        assert.is_not_nil(table_header)
        assert.is_not_nil(dev_header)
        assert.is_true(dep_header < table_header)
        assert.is_true(table_header < dev_header)
        assert.is_nil(result[2]:find("tokio =", 1, true))

        local _, crates = toml.parse_crates(buf)
        assert.equals(2, #crates)
        local names = { crates[1]:package(), crates[2]:package() }
        table.sort(names)
        assert.same({ "serde", "tokio" }, names)
    end)

    it("inserts version before a features-only multiline array", function()
        local crate, buf = parse({
            "[dependencies]",
            "tokio = { features = [",
            '    "net"',
            "] }",
        })
        edit.set_version(buf, crate, semver.parse_version("1.2.3"), true)

        local result = buf_text(buf)
        assert.is_not_nil(result[2]:find('version = "1.2.3"', 1, true))
        assert.is_not_nil(result[2]:find("features = [", 1, true))
        assert.is_nil(result[2]:find("version = .*features = .*version", 1))
        local _, crates = toml.parse_crates(buf)
        assert.equals("1.2.3", crates[1].vers.text)
        assert.equals(1, #crates[1].feat.items)
    end)

    it("disables one of two features sharing an inner line", function()
        state.cfg = config.build({
            remove_empty_features = false,
        })
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { version = "1.0", features = [',
            '    "net", "rt"',
            "] }",
        })
        edit.disable_feature(buf, crate, crate.feat.items[1])

        local result = buf_text(buf)
        assert.is_nil(result[3]:find('"net"', 1, true))
        assert.is_not_nil(result[3]:find('"rt"', 1, true))
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates[1].feat.items)
        assert.equals("rt", crates[1].feat.items[1].name)
    end)

    it("still edits a single-line features array", function()
        local crate, buf = parse({
            "[dependencies]",
            'tokio = { version = "1.0", features = ["net"] }',
        })
        edit.disable_feature(buf, crate, crate.feat.items[1])

        local result = buf_text(buf)
        assert.equals('tokio = { version = "1.0" }', result[2]:gsub("%s+$", ""):gsub("%s+}", " }"))
        local _, crates = toml.parse_crates(buf)
        assert.is_nil(crates[1].feat)
    end)
end)
