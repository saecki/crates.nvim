local Core = {}






local api = require("crates.api")
local Version = api.Version
local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local Crate = toml.Crate

Core.cfg = {}
Core.vers_cache = {}
Core.crate_cache = {}
Core.visible = true

return Core
