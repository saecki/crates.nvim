local toml = require("crates.toml")

describe("parse_crates repro", function()
    it("parses diesel from issue", function()
        local lines = {
            '[package]',
            'edition = "2021"',
            'name = "hi_there"',
            'version = "0.1.0"',
            '',
            '[dependencies]',
            '# the `uuidv07` feature is a renamed dependency with the package `uuid`',
            'diesel = { version = "1.4.8", features = [',
            '	"uuidv07",',
            '	"huge-tables",',
            '	"large-tables",',
            '	"mysql",',
            '	"network-address",',
            '	"numeric",',
            '	"extras",',
            '] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #sections)
        assert.equals(1, #crates)
        
        local crate = crates[1]
        assert.equals("diesel", crate:package())
        assert.is_not_nil(crate.feat)
        assert.equals(7, #crate.feat.items)
        assert.equals("uuidv07", crate.feat.items[1].name)
        assert.equals("extras", crate.feat.items[7].name)
    end)

    it("parses empty array", function()
        local lines = {
            '[dependencies]',
            'dep = { version = "1", features = [] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates)
        assert.is_not_nil(crates[1].feat)
        assert.equals(0, #crates[1].feat.items)
    end)
    
    it("parses array with spaces", function()
        local lines = {
            '[dependencies]',
            'dep = { version = "1", features = [ "a", "b" ] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local _, crates = toml.parse_crates(buf)
        assert.equals(1, #crates)
        assert.equals(2, #crates[1].feat.items)
    end)
    
    it("parses diesel with features first", function()
        local lines = {
            '[dependencies]',
            'diesel = { features = [',
            '	"uuidv07",',
            '], version = "1.4.8" }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("diesel", crate:package())
        assert.equals(1, #crate.feat.items)
        assert.equals("uuidv07", crate.feat.items[1].name)
    end)

    it("parses diesel with NO version (only features)", function()
        local lines = {
            '[dependencies]',
            'diesel = { features = [',
            '	"uuidv07",',
            '] }'
        }
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        
        local sections, crates = toml.parse_crates(buf)
        
        assert.equals(1, #crates)
        local crate = crates[1]
        assert.equals("diesel", crate:package())
        assert.equals(1, #crate.feat.items)
    end)
end)
