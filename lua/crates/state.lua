local State = {}








local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local Crate = toml.Crate
local types = require("crates.types")
local CrateInfo = types.CrateInfo
local Diagnostic = types.Diagnostic
local Version = types.Version

State.cfg = {}
State.vers_cache = {}
State.crate_cache = {}
State.info_cache = {}
State.diagnostic_cache = {}
State.visible = true

return State
