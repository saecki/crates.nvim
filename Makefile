.PHONY: types
types:
	nvim -l scripts/gen_types.lua

.PHONY: test
test:
	nvim --headless --noplugin -u test/minimal.vim -c "lua require(\"plenary.test_harness\").test_directory_command('test {minimal_init = \"test/minimal.vim\"}')"

.PHONY: doc
doc:
	nvim -l docgen/gen_doc.lua

.PHONY: release
release:
	@test $${RELEASE_VERSION?Please set environment variable RELEASE_VERSION}
	echo "${RELEASE_VERSION}" > docgen/shared/stable.txt
	nvim -l docgen/gen_doc.lua
