local nilProxy = nil

local makePropertyGetter = function(getterFunc)
    return function(this)
        local value = getterFunc(this)
        if value == nilProxy then
            return nil
        end
        return value
    end
end

local init = function(_nilProxy)
    nilProxy = _nilProxy
end

return {
    makePropertyGetter = makePropertyGetter,
    init = init
}