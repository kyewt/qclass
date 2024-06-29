
local makeMethodGetter = function(methodFunc)
    return function(this)
        return function(...)
            return methodFunc(this, ...)
        end
    end
end

return makeMethodGetter