local cmp = package.loaded['cmp']
if cmp then
    cmp.register_source('crates', require('crates.cmp').new())
end
