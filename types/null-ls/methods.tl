local record Methods
    internal: Internal

    record Internal
        CODE_ACTION: MethodKind
    end

    enum MethodKind
        "textDocument/codeAction"
    end
end

return Methods
