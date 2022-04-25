local State = {}






local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local Crate = toml.Crate
local types = require("crates.types")
local Version = types.Version

State.cfg = {}
State.vers_cache = {}
State.crate_cache = {}
State.visible = true

return State
