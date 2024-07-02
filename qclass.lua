-- Config for requiring modules
local IS_ROBLOX = false

-- Declare and define variables used in class creation
local nilProxy = {} -- A value to be treated as nil while still holding table space
local makeFieldGetter
local makeFieldSetter
local makePropertyGetter
local makePropertySetter
local makeMethodGetter
local addFieldDefaultValues
local addFields
local addStaticFields
local addProperties
local addMethods
do -- Makers
    if not IS_ROBLOX then
        makeFieldGetter = require "./makeFieldGetter.lua"
        makeFieldSetter = require "./makeFieldSetter.lua"
        makePropertyGetter = require "./makePropertyGetter.lua"
        makePropertySetter = require "./makePropertySetter.lua"
        makeMethodGetter = require "./makeMethodGetter.lua"
    else
        makeFieldGetter = require(script.Parent:WaitForChild("makeFieldGetter"))
        makeFieldSetter = require(script.Parent:WaitForChild("makeFieldSetter"))
        makePropertyGetter = require(script.Parent:WaitForChild("makePropertyGetter"))
        makePropertySetter = require(script.Parent:WaitForChild("makePropertySetter"))
        makeMethodGetter = require(script.Parent:WaitForChild("makeMethodGetter"))
    end
    makeFieldGetter.init(nilProxy); makeFieldGetter = makeFieldGetter.makeFieldGetter
    makeFieldSetter.init(nilProxy); makeFieldSetter = makeFieldSetter.makeFieldSetter
    makePropertyGetter.init(nilProxy); makePropertyGetter = makePropertyGetter.makePropertyGetter
    makePropertySetter.init(nilProxy); makePropertySetter = makePropertySetter.makePropertySetter
end
do -- Adders
    addFieldDefaultValues = function(fTemps, values, readonlyValueTabs)
        for _, fTemp in ipairs(fTemps) do
            local name = fTemp[1]
            local value = fTemp[2]
            local readonly = fTemp[3]
            if value == nil then
                value = nilProxy
            end
            if readonly then
                values[name] = nil
                readonlyValueTabs[name] = value
            else
                readonlyValueTabs[name] = nil
                values[name] = value
            end
        end
    end
    addFields = function(defValues, valueTabs, getters, setters)
        for name, defValue in pairs(defValues) do
            local valueTab = { defValue }
            valueTabs[name] = valueTab
            getters[name] = makeFieldGetter(valueTab)
            setters[name] = makeFieldSetter(valueTab)
        end
    end
    addStaticFields = function(fTemps, valueTabs, getters, setters, initers)
        for _, fTemp in ipairs(fTemps) do
            local name = fTemp[1]
            local value = fTemp[2]
            local readonly = fTemp[3]
            if value == nil then
                value = nilProxy
            end
            local valueTab = { value }
            valueTabs[name] = valueTab
            getters[name] = makeFieldGetter(valueTab)
            if not readonly then
                setters[name] = makeFieldSetter(valueTab)
            elseif initers then
                initers[name] = makeFieldSetter(valueTab)
            end
        end
    end
    addProperties = function(pTemps, getters, setters, initers)
        for _, pTemp in ipairs(pTemps) do
            local name = pTemp[1]
            local getter = pTemp[2]
            local setter = pTemp[3]
            if getter then
                getters[name] = makePropertyGetter(getter)
            else
                getters[name] = nil
            end
            if setter then
                setters[name] = makePropertySetter(setter)
            else
                setters[name] = nil
            end
            if initers then
                local initer = pTemp[4]
                if initer then
                    initers[name] = makePropertySetter(initer)
                else
                    initers[name] = nil
                end
            end
        end
    end
    addMethods = function(mTemps, getters)
        for _, mTemp in ipairs(mTemps) do
            local name = mTemp[1]
            local func = mTemp[2]
            getters[name] = makeMethodGetter(func)
        end
    end
end

-- Frequently used error messages
local errors = {
    badTab = function(name) return "Bad type to" ..name..", expected table" end,
    badStr = function(name) return "Bad type to" ..name..", expected string" end,
    badFun = function(name) return "Bad type to" ..name..", expected function" end,
    badStaGet = function(key, className) return tostring(key).." is not a readable static member of "..className end,
    badStaSet = function(key, className) return tostring(key).." is not a writable static member of "..className end,
    badInsGet = function(key, className) return tostring(key).." is not a readable member of instance of "..className end,
    badInsSet = function(key, className) return tostring(key).." is not a writable member of instance of "..className end
}

local namespaces = {} -- string : namespace dictionary
local allClassInheriteds = {} -- class : inheritedClass dictionary
local allClassDatas = {} -- class : classData dictionary

local newNamespace = function(namespaceName, templates)
    if type(namespaceName) ~= "string" then
        error(errors.badStr("namespace"))
    end
    if namespaces[namespaceName] then
        error("A namespace by the name "..namespaceName.." already exists")
    end

    local pubClasses = {} -- Contains only public classes, only used by namespace accessor

    do -- Populate namespace
        local intClasses = {} -- Contains public and internal classes, used in makeClass
        local intClassTemplates = {} -- Used during template registration and class creation

        -- Function to validate templates during template registration
        local validateTemplate
        do
            local memberContainerValidators = {
                field = function(mem)
                    if type(mem) ~= "table" then
                        error(errors.badTab("field"))
                    end
                    local mName = mem[1]
                    if type(mName) ~= "string" then
                        error(errors.badStr("field name"))
                    end
                end,
                property = function(mem)
                    if type(mem) ~= "table" then
                        error(errors.badTab("property"))
                    end
                    local mName = mem[1]
                    if type(mName) ~= "string" then
                        error(errors.badStr("property name"))
                    end
                    local getter = mem[2]
                    local setter = mem[3]
                    local initer = mem[4]
                    if getter == nil and setter == nil and initer == nil then
                        error("Bad property, needs getter, setter, or initer")
                    end
                    if getter ~= nil and type(getter) ~= "function" then
                        error(errors.badFun("getter"))
                    end
                    if setter ~= nil and type(setter) ~= "function" then
                        error(errors.badFun("setter"))
                    end
                    if initer ~= nil and type(initer) ~= "function" then
                        error(errors.badFun("initer"))
                    end
                end,
                method = function(mem)
                    if type(mem) ~= "table" then
                        error(errors.badTab("method"))
                    end
                    local mName = mem[1]
                    if type(mName) ~= "string" then
                        error(errors.badStr("method name"))
                    end
                    local func = mem[2]
                    if type(func) ~= "function" then
                        error(errors.badFun("method function"))
                    end
                end
            }
            local validateMembers = function(cont, contName)
                if cont == nil then return end
                if type(cont) ~= "table" then
                    error(errors.badTab(contName))
                end
                local fields = cont.fields
                if fields then
                    if type(fields) ~= "table" then
                        error(errors.badTab("fields"))
                    end
                    for _, field in ipairs(fields) do
                        memberContainerValidators.field(field)
                    end
                end
                local properties = cont.properties
                if properties then
                    if type(properties) ~= "table" then
                        error(errors.badTab("properties"))
                    end
                    for _, property in ipairs(properties) do
                        memberContainerValidators.property(property)
                    end
                end
                local methods = cont.methods
                if methods then
                    if type(methods) ~= "table" then
                        error(errors.badTab("methods"))
                    end
                    for _, method in ipairs(methods) do
                        memberContainerValidators.method(method)
                    end
                end
            end
            local validateConstructor = function(con, accessStr)
                if con == nil then return end
                if type(con) ~= "function" then
                    error(errors.badFun(accessStr.." constructor"))
                end
            end
            local validateConstructors = function(cons)
                if cons == nil then return end
                if type(cons) ~= "table" then
                    error(errors.badTab("constructors"))
                end
                validateConstructor(cons.private, "private")
                validateConstructor(cons.protected, "protected")
                validateConstructor(cons.public, "public")
            end
            local validateMetaFunc = function(func, name)
                if func == nil then return end
                if type(func) ~= "function" then
                    error(errors.badFun(name))
                end
            end
            validateTemplate = function(tab)
                if type(tab) ~= "table" then
                    error(errors.badTab("tab"))
                end
                local name = tab.name
                if type(name) ~= "string" then
                    error("Bad type to name, expected string")
                end
                if intClassTemplates[name] then
                    error("Class template with the name "..name.." already exists")
                end
                local inherits = tab.inherits
                if inherits ~= nil and type(inherits) ~= "string" then
                    error("Bad type to inherits, expected string")
                end
                validateMembers(tab.statics, "statics")
                validateMembers(tab, name)
                validateConstructors(tab.constructors)
                validateMetaFunc(tab.__concat)
                validateMetaFunc(tab.__add)
                validateMetaFunc(tab.__sub)
                validateMetaFunc(tab.__mul)
                validateMetaFunc(tab.__div)
                validateMetaFunc(tab.__idiv)
                validateMetaFunc(tab.__mod)
                validateMetaFunc(tab.__pow)
                validateMetaFunc(tab.__tostring)
                validateMetaFunc(tab.__lt)
                validateMetaFunc(tab.__le)
                validateMetaFunc(tab.__len)
                validateMetaFunc(tab.__iter)
            end
        end
        -- Registers templates to be used during class creation
        for _, temp in pairs(templates) do
            validateTemplate(temp)
            intClassTemplates[temp.name] = temp
        end

        -- Makes classes from registered templates
        local makeClass = function(temp)
            -- Define constructors
            local priConstructor = function(this, ...) end
            local proConstructor = function(this, ...) end
            local pubConstructor = function(this, ...) end
            do
                local constructors = temp.constructors
                if constructors then
                    local private = constructors.private
                    if private then priConstructor = private end
                    local protected = constructors.protected
                    if protected then proConstructor = protected end
                    local public = constructors.public
                    if public then pubConstructor = public end
                end
            end
            -- Initialize non-inherited private class-space class data
            local priStaValues  = {}
            local priStaGetters = {}
            local priStaSetters = {}
            local priClaGetters = {}
            local priClaSetters = {}
            local priClaIniters = {}
            -- Initialize inherited non-private class-space data and private instance-space data
            local classData     = {}
            local proStaValues  = {}; classData.proStaValues  = proStaValues
            local pubStaValues  = {}; classData.pubStaValues  = pubStaValues
            local proStaGetters = {}; classData.proStaGetters = proStaGetters
            local proStaSetters = {}; classData.proStaSetters = proStaSetters
            local pubStaGetters = {}; classData.pubStaGetters = pubStaGetters
            local pubStaSetters = {}; classData.pubStaSetters = pubStaSetters
            local proClaGetters = {}; classData.proClaGetters = proClaGetters
            local proClaSetters = {}; classData.proClaSetters = proClaSetters
            local pubClaGetters = {}; classData.pubClaGetters = pubClaGetters
            local pubClaSetters = {}; classData.pubClaSetters = pubClaSetters
            local proClaIniters = {}; classData.proClaIniters = proClaIniters
            local pubClaIniters = {}; classData.pubClaIniters = pubClaIniters
            local priDefValues  = {}; classData.priDefValues  = priDefValues
            local proDefValues  = {}; classData.proDefValues  = proDefValues
            local pubDefValues  = {}; classData.pubDefValues  = pubDefValues
            local priDefValuesR = {}; classData.priDefValuesR = priDefValuesR
            local proDefValuesR = {}; classData.proDefValuesR = proDefValuesR
            local pubDefValuesR = {}; classData.pubDefValuesR = pubDefValuesR
            -- Initialize class object
            local staticProxy = {}
            -- Populate non-private class data with inherited data
            -- Define inheritedClassDatas for later use in base accessor
            local inheritedClassDatas = {}
            do
                local inherits = temp.inherits
                if inherits then
                    local inheritedClass
                    local split = temp.inherits:split(".")
                    local len = #split
                    if len > 1 then
                        local inheritedNamespace = namespaces[split[1]]
                        if not inheritedNamespace then
                            error("Namespace by the name "..inheritedNamespace.." does not exist")
                        end
                        inheritedClass = inheritedNamespace[split[2]]
                    else
                        local inheritedClassName = split[1]
                        inheritedClass = intClasses[inheritedClassName]
                        if not inheritedClass then
                            inheritedClass = makeClass(intClassTemplates[inheritedClassName])
                        end
                    end
                    local nextInheritedClass = inheritedClass
                    while nextInheritedClass do
                        table.insert(inheritedClassDatas, 1, allClassDatas[nextInheritedClass])
                        nextInheritedClass = allClassInheriteds[nextInheritedClass]
                    end
                    for _, inheritedClassData in ipairs(inheritedClassDatas) do
                        for dataTabName, dataTab in pairs(inheritedClassData) do
                            local myDataTab = {}
                            classData[dataTabName] = myDataTab
                            for dataName, data in pairs(dataTab) do
                                myDataTab[dataName] = data
                            end
                        end
                    end
                end
            end
            -- Populate class data with data from class template
            do -- Static Members
                local statics = temp.statics
                if statics then
                    local fields = statics.fields
                    if fields then
                        local private = fields.private
                        if private then
                            addStaticFields(private, priStaValues, priStaGetters, priStaSetters)
                        end
                        local protected = fields.protected
                        if protected then
                            addStaticFields(protected, proStaValues, proStaGetters, proStaSetters)
                        end
                        local public = fields.public
                        if public then
                            addStaticFields(public, pubStaValues, pubStaGetters, pubStaSetters)
                        end
                    end
                    local properties = statics.properties
                    if properties then
                        local private = properties.private
                        if private then
                            addProperties(private, priStaGetters, priStaSetters)
                        end
                        local protected = properties.protected
                        if protected then
                            addProperties(protected, proStaGetters, proStaSetters)
                        end
                        local public = properties.public
                        if public then
                            addProperties(public, pubStaGetters, pubStaSetters)
                        end
                    end
                    local methods = statics.methods
                    if methods then
                        local private = methods.private
                        if private then
                            addMethods(private, priStaGetters)
                        end
                        local protected = methods.protected
                        if protected then
                            addMethods(protected, proStaGetters)
                        end
                        local public = methods.public
                        if public then
                            addMethods(public, pubStaGetters)
                        end
                    end
                end
            end
            do -- Class space Instance Members
                local properties = temp.properties
                if temp.properties then
                    local private = properties.private
                    if private then
                        addProperties(private, priClaGetters, priClaSetters, priClaIniters)
                    end
                    local protected = properties.protected
                    if protected then
                        addProperties(protected, proClaGetters, proClaSetters, proClaIniters)
                    end
                    local public = properties.public
                    if public then
                        addProperties(public, pubClaGetters, pubClaSetters, pubClaIniters)
                    end
                end
                local methods = temp.methods
                if methods then
                    local private = methods.private
                    if private then
                        addMethods(private, priClaGetters)
                    end
                    local protected = methods.protected
                    if protected then
                        addMethods(protected, proClaGetters)
                    end
                    local public = methods.public
                    if public then
                        addMethods(public, pubClaGetters)
                    end
                end
            end
            do -- Instance field default values
                local fields = temp.fields
                if fields then
                    local private = fields.private
                    if private then
                        addFieldDefaultValues(private, priDefValues, priDefValuesR)
                    end
                    local protected = fields.protected
                    if protected then
                        addFieldDefaultValues(protected, proDefValues, proDefValuesR)
                    end
                    local public = fields.public
                    if public then
                        addFieldDefaultValues(public, pubDefValues, pubDefValuesR)
                    end
                end
            end
            -- Define variables for use in static and instance MTs
            local className  = temp.name
            local __str  = temp.__tostring or function() return className end
            -- Define static class metatable objects
            local claStaticMT, pubStaticMT
            do
                local commonStaticMT = {
                    __tostring = function() return className end,
                }
                claStaticMT = {
                    __index = function(_, k)
                        local getter = pubStaGetters[k] or proStaGetters[k] or priStaGetters[k]
                        if not getter then
                            error(errors.badStaGet(k, className))
                        end
                        return getter(staticProxy)
                    end,
                    __newindex = function(_, k, v)
                        local setter = pubStaSetters[k] or proStaSetters[k] or priStaSetters[k]
                        if not setter then
                            error(errors.badStaGet(k, className))
                        end
                        setter(staticProxy, v)
                    end,
                }
                pubStaticMT = {
                    __index = function(_, k)
                        local getter = pubStaGetters[k]
                        if not getter then
                            error(errors.badStaGet(k, className))
                        end
                        setmetatable(staticProxy, claStaticMT)
                        local value = getter(staticProxy)
                        setmetatable(staticProxy, pubStaticMT)
                    end,
                    __newindex = function(_, k, v)
                        local setter = pubStaSetters[k]
                        if not setter then
                            error(error.badStaSet(k, className))
                        end
                        setmetatable(staticProxy, claStaticMT)
                        setter(staticProxy, v)
                        setmetatable(staticProxy, pubStaticMT)
                    end
                }
                for k, v in pairs(commonStaticMT) do
                    claStaticMT[k] = v; pubStaticMT[k] = v
                end
            end
            setmetatable(staticProxy, pubStaticMT)
            -- Define variables for use in instance MTs
            local __cat  = temp.__concat or function(t) error("Cannot concatenate "..className) end
            local __add  = temp.__add    or function(t) error("Cannot add "..className) end
            local __sub  = temp.__sub    or function(t) error("Cannot subtract "..className) end
            local __mul  = temp.__mul    or function(t) error("Cannot multiply "..className) end
            local __div  = temp.__div    or function(t) error("Cannot divide "..className) end
            local __idiv = temp.__idiv   or function(t) error("Cannot floor divide "..className) end
            local __mod  = temp.__mod    or function(t) error("Cannot modulo "..className) end
            local __pow  = temp.__pow    or function(t) error("Cannot exponentiate "..className) end
            local __lt   = temp.__lt     or function(t) error("Cannot compare less than ".. className) end
            local __le   = temp.__lt     or function(t) error("Cannot compare less than or equal to "..className) end
            local __len  = temp.__len    or function(t) error("Cannot get length of "..className) end
            local __iter = temp.__iter   or function(t) error("Cannot iterate "..className) end
            local commonInstanceMT = {
                __tostring = __str, __concat = __cat, __add = __add, __sub = __sub,
                __mul = __mul, __div = __div, __idiv = __idiv, __mod = __mod, __pow = __pow,
                __lt = __lt, __le = __le, __len = __len, __iter = __iter
            }
            -- Define __call for public constructor only
            pubStaticMT.__call = function(_, ...)
                -- Initialize permanent instance data
                local priValues  = {}
                local proValues  = {}
                local pubValues  = {}
                local priGetters = {}
                local proGetters = {}
                local pubGetters = {}
                local priSetters = {}
                local proSetters = {}
                local pubSetters = {}
                -- Populate permanent instance data
                addFields(priDefValues, priValues, priGetters, priSetters)
                addFields(proDefValues, proValues, proGetters, proSetters)
                addFields(pubDefValues, pubValues, pubGetters, pubSetters)
                for name, defValue in pairs(pubDefValuesR) do
                    local value = { defValue }
                    pubValues[name] = value
                    pubGetters[name] = makeFieldGetter(value)
                end
                -- Define instance metatable objects
                local instanceProxy = {}
                local claInstanceMT = {
                    __index = function(_, k)
                        local getter = priGetters[k] or proGetters[k] or pubGetters[k] or
                            priClaGetters[k] or proClaGetters[k] or pubClaGetters[k] or
                            priStaGetters[k] or proStaGetters[k] or pubStaGetters[k]
                        if not getter then
                            error(errors.badInsGet(k, className))
                        end
                        return getter(instanceProxy)
                    end,
                    __newindex = function(_, k, v)
                        local setter = priSetters[k] or proSetters[k] or pubSetters[k] or
                            priClaSetters[k] or proClaSetters[k] or pubClaSetters[k]
                        if not setter then
                            error(errors.badInsSet(k, className))
                        end
                        setter(instanceProxy, v)
                    end
                }
                local pubInstanceMT
                pubInstanceMT = {
                    __index = function(_, k)
                        local getter = pubGetters[k] or pubClaGetters[k] or pubStaGetters[k]
                        if not getter then
                            error(errors.badInsGet(k, className))
                        end
                        setmetatable(instanceProxy, claInstanceMT)
                        local value = getter(instanceProxy)
                        setmetatable(instanceProxy, pubInstanceMT)
                        return value
                    end,
                    __newindex = function(_, k, v)
                        local setter = pubSetters[k] or pubClaSetters[k] or pubStaSetters[k]
                        if not setter then
                            error(errors.badInsSet(k, className))
                        end
                        setmetatable(instanceProxy, claInstanceMT)
                        setter(instanceProxy, v)
                        setmetatable(instanceProxy, pubInstanceMT)
                    end
                }
                for metaName, metaOverride in pairs(commonInstanceMT) do
                    pubInstanceMT[metaName] = function(...)
                        setmetatable(instanceProxy, claInstanceMT)
                        local value = metaOverride(...)
                        setmetatable(instanceProxy, pubInstanceMT)
                        return value
                    end
                end
                -- Define temporary instance data and setup instance proxy for construction
                do
                    local priIniters = {}
                    local proIniters = {}
                    addFields(priDefValuesR, priValues, priGetters, priIniters)
                    addFields(proDefValuesR, proValues, proGetters, proIniters)
                    local conInstanceMT = {
                        __index = function(_, k)
                            local getter = priGetters[k] or proGetters[k] or pubGetters[k] or
                                priClaGetters[k] or proClaGetters[k] or pubClaGetters[k] or
                                priStaGetters[k] or proStaGetters[k] or pubStaGetters[k]
                            if not getter then
                                error(errors.badInsGet(k, className))
                            end
                            return getter(instanceProxy)
                        end,
                        __newindex = function(_, k, v)
                            local setter = priIniters[k] or proIniters[k] or
                                priClaIniters[k] or proClaIniters[k] or pubClaIniters[k] or
                                priSetters[k] or proSetters[k] or pubSetters[k]
                            if not setter then
                                error(errors.badInsSet(k, className))
                            end
                            setter(instanceProxy, v)
                        end
                    }
                    for k, v in pairs(commonInstanceMT) do
                        conInstanceMT[k] = v; claInstanceMT[k] = v
                    end
                    setmetatable(instanceProxy, conInstanceMT)
                end
                pubConstructor(instanceProxy, ...)
                setmetatable(instanceProxy, pubInstanceMT)
                return instanceProxy
            end
            allClassDatas[staticProxy] = classData
            if temp.internal then
                intClasses[className] = staticProxy
            else
                pubClasses[className] = staticProxy
                intClasses[className] = staticProxy
            end
            temp = nil
            return staticProxy
        end

        for _, temp in pairs(intClassTemplates) do
            makeClass(temp)
        end
    end
    
    local namespace = setmetatable({}, { -- Namespace accessor, readonly access to public classes within this namespace
        __index = function(_, k)
            local class = pubClasses[k]
            if not class then
                error("Namespace "..namespaceName.." does not contain public class "..tostring(k))
            end
            return class
        end,
        __newindex = function()
            error("Cannot set member of namespace")
        end
    })
    namespaces[namespaceName] = namespace

    namespaceName = nil
    templates = nil

    return namespace
end

local qclass = {
    newNamespace = newNamespace,
    namespaces = setmetatable({}, { -- Readonly accessor for namespaces
        __index = function(_, k)
            local namespace = namespaces[k]
            if not namespace then
                error("Namespace by the name "..tostring(k).." does not exist")
            end
            return namespace
        end,
        __newindex = function()
            error("Cannot set member of qclass.namespaces")
        end
    })
}

return qclass