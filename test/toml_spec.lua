local toml = require("crates.toml")

describe("parse_crate_features", function()
    it("parses single line features", function()
        local text = '"derive", "alloc"'
        local features = toml.parse_crate_features(text)
        
        assert.equals(2, #features)
        assert.equals("derive", features[1].name)
        assert.equals("alloc", features[2].name)
    end)
    
    it("parses multiline features with newlines", function()
        -- This is what the multiline parsing should produce
        local text = '"net",\n    "rt",\n    "macros"'
        local features = toml.parse_crate_features(text)
        
        assert.equals(3, #features)
        assert.equals("net", features[1].name)
        assert.equals("rt", features[2].name)
        assert.equals("macros", features[3].name)
    end)
    
    it("parses features with trailing comma", function()
        local text = '"derive", "alloc",'
        local features = toml.parse_crate_features(text)
        
        assert.equals(2, #features)
        assert.equals("derive", features[1].name)
        assert.equals("alloc", features[2].name)
        assert.is_true(features[2].comma)
    end)
    
    it("parses multiline features starting on first line", function()
        -- Features array like: features = ["full",
        --     "http2",
        --     "stream"
        -- ]
        local text = '"full",\n    "http2",\n    "stream"\n'
        local features = toml.parse_crate_features(text)
        
        assert.equals(3, #features)
        assert.equals("full", features[1].name)
        assert.equals("http2", features[2].name)
        assert.equals("stream", features[3].name)
    end)
    
    it("parses features with extra whitespace", function()
        local text = '\n    "postgres",\n        "r2d2",\n        "uuidv07"\n'
        local features = toml.parse_crate_features(text)
        
        assert.equals(3, #features)
        assert.equals("postgres", features[1].name)
        assert.equals("r2d2", features[2].name)
        assert.equals("uuidv07", features[3].name)
    end)
end)
