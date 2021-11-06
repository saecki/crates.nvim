local record lsp
    record CompletionItemKind
        Text: integer
        Method: integer
        Function: integer
        Constructor: integer
        Field: integer
        Variable: integer
        Class: integer
        Interface: integer
        Module: integer
        Property: integer
        Unit: integer
        Value: integer
        Enum: integer
        Keyword: integer
        Snippet: integer
        Color: integer
        File: integer
        Reference: integer
        Folder: integer
        EnumMember: integer
        Constant: integer
        Struct: integer
        Event: integer
        Operator: integer
        TypeParameter: integer
    end

    record MarkupKind
        Plaintext: string
        Markdown: string
    end

    record MarkupContent
        kind: string -- MarkupKind
        value: string
    end

    record CompletionItem
        label: string
        kind: integer|nil -- CompletionItemKind|nil
        detail: string|nil
        documentation: MarkupContent|string|nil
        deprecated: boolean|nil
        preselect: boolean|nil
        sortText: string|nil
        filterText: string|nil
        insertText: string|nil
    end
end

local record cmp
    lsp: lsp

    record SourceBaseApiParams
        option: table
    end
    
    record SourceCompletionApiParams
        context: table
        offset: number
    end
end


return cmp
