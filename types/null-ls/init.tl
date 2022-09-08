local record NullLs
    record Source
        name: string
        meta: Meta
        method: MethodKind
        filetypes: {string}
        generator: Generator
    end

    record Meta
        url: string
        description: string
    end

    record Generator
        fn: function(Params): {Action}
        opts: Opts

        record Opts
            runtime_condition: function(Params)
        end
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
