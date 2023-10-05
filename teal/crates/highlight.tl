local record M
    highlights: {{string,{string:any}}}
end

M.highlights = {
    { "CratesNvimLoading", { default = true, link = "DiagnosticVirtualTextInfo" } },
    { "CratesNvimVersion" , { default = true, link = "DiagnosticVirtualTextInfo" } },
    { "CratesNvimPreRelease", { default = true, link = "DiagnosticVirtualTextWarn" } },
    { "CratesNvimYanked", { default = true, link = "DiagnosticVirtualTextError" } },
    { "CratesNvimNoMatch", { default = true, link = "DiagnosticVirtualTextError" } },
    { "CratesNvimUpgrade", { default = true, link = "DiagnosticVirtualTextWarn" } },
    { "CratesNvimError", { default = true, link = "DiagnosticVirtualTextError" } },

    { "CratesNvimPopupTitle", { default = true, link = "Title" } },
    { "CratesNvimPopupPillText", { default = true, ctermfg = 15, ctermbg = 242, fg = "#e0e0e0", bg = "#3a3a3a" } },
    { "CratesNvimPopupPillBorder", { default = true, ctermfg = 242, fg = "#3a3a3a" } },
    { "CratesNvimPopupDescription", { default = true, link = "Comment" } },
    { "CratesNvimPopupLabel", { default = true, link = "Identifier" } },
    { "CratesNvimPopupValue", { default = true, link = "String" } },
    { "CratesNvimPopupUrl", { default = true, link = "Underlined" } },
    { "CratesNvimPopupVersion", { default = true, link = "None" } },
    { "CratesNvimPopupPreRelease", { default = true, link = "DiagnosticVirtualTextWarn" } },
    { "CratesNvimPopupYanked", { default = true, link = "DiagnosticVirtualTextError" } },
    { "CratesNvimPopupVersionDate", { default = true, link = "Comment" } },
    { "CratesNvimPopupFeature", { default = true, link = "None" } },
    { "CratesNvimPopupEnabled", { default = true, ctermfg=2, fg = "#23ab49" } },
    { "CratesNvimPopupTransitive", { default = true, ctermfg=4, fg = "#238bb9" } },
    { "CratesNvimPopupNormalDependenciesTitle", { default = true, link = "Statement" } },
    { "CratesNvimPopupBuildDependenciesTitle", { default = true, link = "Statement" } },
    { "CratesNvimPopupDevDependenciesTitle", { default = true, link = "Statement" } },
    { "CratesNvimPopupDependency", { default = true, link = "None" } },
    { "CratesNvimPopupOptional", { default = true, link = "Comment" } },
    { "CratesNvimPopupDependencyVersion", { default = true, link = "String" } },
    { "CratesNvimPopupLoading", { default = true, link = "Special" } },

    { "CmpItemKindVersion", { default = true, link = "Special" } },
    { "CmpItemKindFeature", { default = true, link = "Special" } },
}

function M.define()
    for _, h in ipairs(M.highlights) do
        vim.api.nvim_set_hl(0, h[1], h[2])
    end
end

return M
