local State = {BufCache = {}, }












local config = require("crates.config")
local Config = config.Config
local toml = require("crates.toml")
local types = require("crates.types")
local Crate = types.Crate
local CrateInfo = types.CrateInfo
local Diagnostic = types.Diagnostic

State.cfg = {}
State.api_cache = {}
State.buf_cache = {}
State.visible = true

return State
