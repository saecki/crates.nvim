local record M
end

local Crate = require("crates.toml").Crate

function M.crate_diagnostic(crate: Crate, message: string, severity: integer): vim.diagnostic.Diagnostic
    return {
        lnum = crate.lines.s,
        end_lnum = crate.lines.e,
        col = 0,
        end_col = 0,
        severity = severity,
        message = message,
        source = "crates",
    }
end

function M.process_items(crates: {Crate}): {string:Crate}, {vim.diagnostic.Diagnostic}
    local diagnostics = {}
    local cache: {string:Crate} = {}

    for _,c in ipairs(crates) do
        if cache[c.name] then
            local original = M.crate_diagnostic(
                cache[c.name],
                "Original entry is defined here",
                vim.diagnostic.severity.HINT
            )
            table.insert(diagnostics, original)
            local duplicate = M.crate_diagnostic(
                c,
                "Duplicate crate entry",
                vim.diagnostic.severity.ERROR
            )
            table.insert(diagnostics, duplicate)
        else
            cache[c.name] = c
        end
    end

    return cache, diagnostics
end

return M
