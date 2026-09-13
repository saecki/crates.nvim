local config = require("crates.config")
local completion = require("crates.completion.common")
local semver = require("crates.semver")
local state = require("crates.state")
local toml = require("crates.toml")
local types = require("crates.types")
local ApiFeatures = types.ApiFeatures

local function setup_buf(lines, cursor)
    state.cfg = config.build({})
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, cursor)

    local _, crates = toml.parse_crates(buf)
    local crate = crates[1]
    state.buf_cache[buf] = {
        crates = { [crate:cache_key()] = crate },
        info = {},
        diagnostics = {},
        working_crates = {},
    }
    state.api_cache["tokio"] = {
        name = "tokio",
        versions = {
            {
                num = "1.0.0",
                parsed = semver.parse_version("1.0.0"),
                yanked = false,
                features = ApiFeatures.new({
                    { name = "default", members = {}, dep = false },
                    { name = "full", members = {}, dep = false },
                    { name = "net", members = {}, dep = false },
                }),
                deps = {},
            },
        },
    }
    return buf
end

local function insert_text_for(list, label)
    assert.is_not_nil(list)
    for _, item in ipairs(list.items) do
        if item.label == label then
            return item.insertText or item.label
        end
    end
    error("missing completion item: " .. label)
end

describe("feature completion in array gaps", function()
    it("quotes a feature inserted on a blank line of a multiline array", function()
        setup_buf({
            "[dependencies]",
            'tokio = { version = "1", features = [',
            "",
            "] }",
        }, { 3, 0 })

        local list = completion.complete_sync()
        assert.equals('"full"', insert_text_for(list, "full"))
        assert.equals('"net"', insert_text_for(list, "net"))
    end)

    it("quotes a feature inserted into an empty single-line array", function()
        local lines = {
            "[dependencies]",
            'tokio = { version = "1", features = [] }',
        }
        local col = lines[2]:find("%[", 1) 
        setup_buf(lines, { 2, col })

        local list = completion.complete_sync()
        assert.equals('"full"', insert_text_for(list, "full"))
    end)

    it("does not wrap an existing quoted name under the cursor", function()
        local lines = {
            "[dependencies]",
            'tokio = { version = "1", features = ["net"] }',
        }
        local col = lines[2]:find("net", 1, true) - 1
        setup_buf(lines, { 2, col })

        local list = completion.complete_sync()
        local text = insert_text_for(list, "full")
        assert.equals("full", text)
    end)
end)
