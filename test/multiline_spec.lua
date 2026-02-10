local toml = require("crates.toml")

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
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.is_not_nil(crate.feat)
        assert.equals(2, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
        assert.equals("test-util", crate.feat.items[2].name)
    end)

    it("parses multiline features in inline dependency", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1.0", features = [',
            '    "full",',
            '    "test-util"',
            '] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.is_not_nil(crate.feat)
        assert.equals(2, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
        assert.equals("test-util", crate.feat.items[2].name)
    end)

    it("parses single line features in inline dependency", function()
        local lines = {
            '[dependencies]',
            'tokio = { version = "1.0", features = ["full"] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("tokio", crate:package())
        assert.is_not_nil(crate.feat)
        assert.equals(1, #crate.feat.items)
        assert.equals("full", crate.feat.items[1].name)
    end)
end)
