local nilProxy = nil

local makePropertySetter = function(setterFunc)
    return function(this, value)
        if value == nil then
            value = nilProxy
        end
        setterFunc(this, value)
    end
end

local init = function(_nilProxy)
    nilProxy = _nilProxy
end

return {
    makePropertySetter = makePropertySetter,
    init = init
}