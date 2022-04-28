local api = require("crates.api")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local Features = types.Features
local SemVer = types.SemVer
local Range = types.Range

describe("crate", function()
	local json_str
	it("read file", function()
		json_str = io.input("test/rand.json"):read("a")
		assert.equals("string", type(json_str))
	end)

	it("parse json", function()
		local crate = api.parse_crate(json_str)
		assert.same({
			name = "rand",
			description = "Random number generators and other randomness functionality.\n",
			homepage = "https://rust-random.github.io/book",
			documentation = "https://docs.rs/rand",
			repository = "https://github.com/rust-random/rand",
		}, crate)
	end)
end)

describe("versions", function()
	local json_str
	it("read file", function()
		json_str = io.input("test/rand_versions.json"):read("a")
		assert.equals("string", type(json_str))
	end)

	it("parse json", function()
		local versions = api.parse_vers(json_str)
		assert.equals("table", type(versions))
		assert.equals(3, #versions)

		assert.same({
			num = "0.8.5",
			features = Features.new({
				{ name = "default", members = { "std", "std_rng" } },
				{ name = "alloc", members = { "rand_core/alloc" } },
				{ name = "getrandom", members = { "rand_core/getrandom" } },
				{ name = "libc", members = {} },
				{ name = "min_const_gen", members = {} },
				{ name = "nightly", members = {} },
				{ name = "packed_simd", members = {} },
				{ name = "rand_chacha", members = {} },
				{ name = "rand_chacha/std", members = {} },
				{ name = "rand_core/alloc", members = {} },
				{ name = "rand_core/getrandom", members = {} },
				{ name = "rand_core/serde1", members = {} },
				{ name = "rand_core/std", members = {} },
				{ name = "serde", members = {} },
				{ name = "serde1", members = { "rand_core/serde1", "serde" } },
				{ name = "simd_support", members = { "packed_simd" } },
				{ name = "small_rng", members = {} },
				{ name = "std", members = { "alloc", "getrandom", "libc", "rand_chacha/std", "rand_core/std" } },
				{ name = "std_rng", members = { "rand_chacha" } },
			}),
			yanked = false,
			parsed = SemVer.new({ major = 0, minor = 8, patch = 5 }),
			created = DateTime.new(1644822000),
		}, versions[1])

		assert.same({
			num = "0.3.5",
			features = Features.new({
				{ name = "default", members = {} },
			}),
			yanked = false,
			parsed = SemVer.new({ major = 0, minor = 3, patch = 5 }),
			created = DateTime.new(1427896800),
		}, versions[2])

		assert.same({
			num = "0.1.1",
			features = Features.new({
				{ name = "default", members = {} },
			}),
			yanked = true,
			parsed = SemVer.new({ major = 0, minor = 1, patch = 1 }),
			created = DateTime.new(1422939600),
		}, versions[3])
	end)
end)

describe("dependencies", function()
	local json_str
	it("read file", function()
		json_str = io.input("test/rand_dependencies.json"):read("a")
		assert.equals("string", type(json_str))
	end)

	it("parse json", function()
		local dependencies = api.parse_deps(json_str)
		assert.equals("table", type(dependencies))
		assert.equals(4, #dependencies)

		assert.same({
			name = "average",
			opt = false,
			kind = "dev",
			vers = {
				reqs = {
					{
						cond = "cr",
						cond_col = Range.new(0, 1),
						vers = SemVer.new({ major = 0, minor = 9, patch = 2 }),
						vers_col = Range.new(1, 6),
					},
				},
				text = "^0.9.2",
			},
		}, dependencies[1])

        assert.same({
			name = "rand_core",
			opt = false,
			kind = "normal",
			vers = {
				reqs = {
					{
						cond = "cr",
						cond_col = Range.new(0, 1),
						vers = SemVer.new({ major = 0, minor = 3 }),
						vers_col = Range.new(1, 4),
					},
				},
				text = "^0.3",
			},
		}, dependencies[2])

        assert.same({
			name = "rustc_version",
			opt = false,
			kind = "build",
			vers = {
				reqs = {
					{
						cond = "cr",
						cond_col = Range.new(0, 1),
						vers = SemVer.new({ major = 0, minor = 2 }),
						vers_col = Range.new(1, 4),
					},
				},
				text = "^0.2",
			},
		}, dependencies[3])

        assert.same({
			name = "cloudabi",
			opt = true,
			kind = "normal",
			vers = {
				reqs = {
					{
						cond = "cr",
						cond_col = Range.new(0, 1),
						vers = SemVer.new({ major = 0, minor = 0, patch = 3 }),
						vers_col = Range.new(1, 6),
					},
				},
				text = "^0.0.3",
			},
		}, dependencies[4])
	end)
end)
