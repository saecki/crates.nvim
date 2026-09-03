require("crates.command").register()
require("crates.highlight").define()

vim.api.nvim_create_autocmd("BufRead", {
    pattern = "Cargo.toml",
    once = true,
    callback = function()
        require("crates").setup({})
    end,
})
