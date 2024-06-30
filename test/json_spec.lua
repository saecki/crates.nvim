local api = require("crates.api")
local semver = require("crates.semver")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local Cond = types.Cond
local ApiDependencyKind = types.ApiDependencyKind
local ApiFeatures = types.ApiFeatures
local SemVer = types.SemVer
local Span = types.Span

---@generic T
---@param t T
---@return T
local function shallow_copy(t)
    local new = {}
    for k,v in pairs(t) do
        new[k] = v
    end
    return new
end

describe("json", function()
    ---@type string
    local index_json_str
    ---@type string
    local meta_json_str
    it("read index file", function()
        index_json_str = io.open("test/diesel_index.json"):read("a")
        assert.equals("string", type(index_json_str))
    end)

    it("read meta file", function()
        meta_json_str = io.open("test/diesel_meta.json"):read("a")
        assert.equals("string", type(meta_json_str))
    end)

    it("parse crate", function()
        local crate = api.parse_crate(index_json_str, meta_json_str)
        assert.is_not_nil(crate)

        ---@type ApiCrate
        local crate_without_versions = shallow_copy(crate)
        crate_without_versions.versions = nil

        assert.same({
            name = "diesel",
            description = "A safe, extensible ORM and Query Builder for PostgreSQL, SQLite, and MySQL",
            created = DateTime.new(os.time({
                year = 2015,
                month = 11,
                day = 29,
                hour = 17,
                min = 53,
                sec = 47,
            })),
            updated = DateTime.new(os.time({
                year = 2024,
                month = 6,
                day = 13,
                hour = 11,
                min = 33,
                sec = 58,
            })),
            downloads = 10451525,
            homepage = "https://diesel.rs",
            documentation = "https://docs.rs/diesel/",
            repository = "https://github.com/diesel-rs/diesel",
            categories = { "Database interfaces" },
            keywords = { "database", "orm", "sql" },
        }, crate_without_versions)

        local version = crate.versions[5]
        ---@type ApiVersion
        local version_without_deps = shallow_copy(version)
        version_without_deps.deps = nil

        assert.same({
            num = "2.1.4",
            parsed = SemVer.new({ major = 2, minor = 1, patch = 4 }),
            yanked = false,
            created = DateTime.new(os.time({
                year = 2023,
                month = 11,
                day = 14,
                hour = 15,
                min = 3,
                sec = 19,
            })),
            features = ApiFeatures.new({
                { name = "default",                                                         members = { "32-column-tables", "with-deprecated" } },
                { name = "128-column-tables",                                               members = { "64-column-tables", "diesel_derives/128-column-tables" } },
                { name = "32-column-tables",                                                members = { "diesel_derives/32-column-tables" } },
                { name = "64-column-tables",                                                members = { "32-column-tables", "diesel_derives/64-column-tables" } },
                { name = "chrono",                                                          members = { "diesel_derives/chrono", "dep:chrono" } },
                { name = "extras",                                                          members = { "chrono", "network-address", "numeric", "r2d2", "time", "dep:serde_json", "dep:uuid" } },
                { name = "huge-tables",                                                     members = { "64-column-tables" } },
                { name = "i-implement-a-third-party-backend-and-opt-into-breaking-changes", members = {} },
                { name = "ipnet-address",                                                   members = { "dep:ipnet", "dep:libc" } },
                { name = "large-tables",                                                    members = { "32-column-tables" } },
                { name = "mysql",                                                           members = { "mysql_backend", "dep:bitflags", "dep:mysqlclient-sys", "dep:percent-encoding", "dep:url" } },
                { name = "mysql_backend",                                                   members = { "diesel_derives/mysql", "dep:byteorder" } },
                { name = "network-address",                                                 members = { "dep:ipnetwork", "dep:libc" } },
                { name = "nightly-error-messages",                                          members = {} },
                { name = "numeric",                                                         members = { "dep:bigdecimal", "dep:num-bigint", "dep:num-integer", "dep:num-traits" } },
                { name = "postgres",                                                        members = { "postgres_backend", "dep:pq-sys" } },
                { name = "postgres_backend",                                                members = { "diesel_derives/postgres", "dep:bitflags", "dep:byteorder", "dep:itoa" } },
                { name = "r2d2",                                                            members = { "diesel_derives/r2d2", "dep:r2d2" } },
                { name = "returning_clauses_for_sqlite_3_35",                               members = {} },
                { name = "sqlite",                                                          members = { "diesel_derives/sqlite", "libsqlite3-sys", "time?/formatting", "time?/parsing" } },
                { name = "time",                                                            members = { "diesel_derives/time", "dep:time" } },
                { name = "unstable",                                                        members = { "diesel_derives/nightly" } },
                { name = "with-deprecated",                                                 members = { "diesel_derives/with-deprecated" } },
                { name = "without-deprecated",                                              members = { "diesel_derives/without-deprecated" } },

                { name = "dep:bigdecimal",                                                  members = {},                                                                                       dep = true },
                { name = "dep:bitflags",                                                    members = {},                                                                                       dep = true },
                { name = "dep:byteorder",                                                   members = {},                                                                                       dep = true },
                { name = "dep:chrono",                                                      members = {},                                                                                       dep = true },
                { name = "dep:ipnet",                                                       members = {},                                                                                       dep = true },
                { name = "dep:ipnetwork",                                                   members = {},                                                                                       dep = true },
                { name = "dep:itoa",                                                        members = {},                                                                                       dep = true },
                { name = "dep:libc",                                                        members = {},                                                                                       dep = true },
                { name = "dep:libsqlite3-sys",                                              members = {},                                                                                       dep = true },
                { name = "dep:mysqlclient-sys",                                             members = {},                                                                                       dep = true },
                { name = "dep:num-bigint",                                                  members = {},                                                                                       dep = true },
                { name = "dep:num-integer",                                                 members = {},                                                                                       dep = true },
                { name = "dep:num-traits",                                                  members = {},                                                                                       dep = true },
                { name = "dep:percent-encoding",                                            members = {},                                                                                       dep = true },
                { name = "dep:pq-sys",                                                      members = {},                                                                                       dep = true },
                { name = "dep:quickcheck",                                                  members = {},                                                                                       dep = true },
                { name = "dep:r2d2",                                                        members = {},                                                                                       dep = true },
                { name = "dep:serde_json",                                                  members = {},                                                                                       dep = true },
                { name = "dep:time",                                                        members = {},                                                                                       dep = true },
                { name = "dep:url",                                                         members = {},                                                                                       dep = true },
                { name = "dep:uuid",                                                        members = {},                                                                                       dep = true },
            }),
        }, version_without_deps)

        ---@param vers string
        ---@return ApiDependencyVers
        local function dep_vers(vers)
            return {
                text = vers,
                reqs = semver.parse_requirements(vers),
            }
        end
        assert.same({
            { name = "bigdecimal",       vers = dep_vers(">=0.0.13, <0.5.0"),  kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "bitflags",         vers = dep_vers("^2.0.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "byteorder",        vers = dep_vers("^1.0"),              kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "cfg-if",           vers = dep_vers("^1"),                kind = ApiDependencyKind.DEV,    opt = false },
            { name = "chrono",           vers = dep_vers("^0.4.20"),           kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "diesel_derives",   vers = dep_vers("~2.1.1"),            kind = ApiDependencyKind.NORMAL, opt = false },
            { name = "dotenvy",          vers = dep_vers("^0.15"),             kind = ApiDependencyKind.DEV,    opt = false },
            { name = "ipnet",            vers = dep_vers("^2.5.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "ipnetwork",        vers = dep_vers(">=0.12.2, <0.21.0"), kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "ipnetwork",        vers = dep_vers(">=0.12.2, <0.21.0"), kind = ApiDependencyKind.DEV,    opt = false },
            { name = "itoa",             vers = dep_vers("^1.0.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "libc",             vers = dep_vers("^0.2.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "libsqlite3-sys",   vers = dep_vers(">=0.17.2, <0.28.0"), kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "mysqlclient-sys",  vers = dep_vers("^0.2.5"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "num-bigint",       vers = dep_vers(">=0.2.0, <0.5.0"),   kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "num-integer",      vers = dep_vers("^0.1.39"),           kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "num-traits",       vers = dep_vers("^0.2.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "percent-encoding", vers = dep_vers("^2.1.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "pq-sys",           vers = dep_vers("^0.4.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "quickcheck",       vers = dep_vers("^1.0.3"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "quickcheck",       vers = dep_vers("^1.0.3"),            kind = ApiDependencyKind.DEV,    opt = false },
            { name = "r2d2",             vers = dep_vers(">=0.8.2, <0.9.0"),   kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "serde_json",       vers = dep_vers(">=0.8.0, <2.0"),     kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "time",             vers = dep_vers("^0.3.9"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "url",              vers = dep_vers("^2.1.0"),            kind = ApiDependencyKind.NORMAL, opt = true },
            { name = "uuid",             vers = dep_vers(">=0.7.0, <2.0.0"),   kind = ApiDependencyKind.NORMAL, opt = true },
        }, version.deps)
    end)
end)
