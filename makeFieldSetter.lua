local nilProxy = nil

local makeFieldSetter = function(valueTab)
    return function(_, value)
        if value == nil then
            value = nilProxy
        end
        valueTab[1] = value
    end
end

local init = function(_nilProxy)
    nilProxy = _nilProxy
end

return {
    makeFieldSetter = makeFieldSetter,
    init = init
}