local record Core
    cfg: Config
    vers_cache: {string:{Version}}
    crate_cache: {integer:{string:Crate}}
    visible: boolean
end

local Config = require('crates.config')
local Version = require('crates.api').Version
local Crate = require('crates.toml').Crate

Core.cfg = {}
Core.vers_cache = {}
Core.crate_cache = {}
Core.visible = false

return Core
