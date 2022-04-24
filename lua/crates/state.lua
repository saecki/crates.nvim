local State = {}






local api = require("crates.api")
local Version = api.Version
local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local Crate = toml.Crate

State.cfg = {}
State.vers_cache = {}
State.crate_cache = {}
State.visible = true

return State
