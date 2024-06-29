local nilProxy = nil

local makeFieldGetter = function(valueTab)
    return function()
        local value = valueTab[1]
        if value == nilProxy then
            value = nil
        end
        return value
    end
end

local init = function(_nilProxy)
    nilProxy = _nilProxy
end

return {
    makeFieldGetter = makeFieldGetter,
    init = init
}