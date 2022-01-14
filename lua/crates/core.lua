local Core = {}






local Config = require("crates.config").Config
local Version = require("crates.api").Version
local Crate = require("crates.toml").Crate

Core.cfg = {}
Core.vers_cache = {}
Core.crate_cache = {}
Core.visible = true

return Core
