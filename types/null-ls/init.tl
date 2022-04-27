local record NullLs
    record Source
        name: string
        method: MethodKind
        generator: Generator
    end

    record Generator
        fn: function(Params): {Action}
    end

    record Action
        name: string
        action: function
    end

    record Params
        bufnr: integer
        bufname: string
    end

    register: function(Source)
end

local methods = require("null-ls.methods")
local MethodKind = methods.MethodKind

return NullLs
