--[[
MIT License

Copyright (c) 2024 kyewt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

-- Frequently used error messages
local errors = {
    badTab = function(name) return "Bad type to " ..name..", expected table" end,
    badStr = function(name) return "Bad type to " ..name..", expected string" end,
    badFun = function(name) return "Bad type to " ..name..", expected function" end,
    badSet = function(name) return "Cannot set index of "..name end,
    badStaGet = function(key, className) return tostring(key).." is not a readable static member of "..className end,
    badStaSet = function(key, className) return tostring(key).." is not a writable static member of "..className end,
    badInsGet = function(key, className) return tostring(key).." is not a readable member of instance of "..className end,
    badInsSet = function(key, className) return tostring(key).." is not a writable member of instance of "..className end,
    badBaseClass = function(class) return tostring(class).." does not have a base class" end,
    badBaseAccess = function(baseClass) return tostring(baseClass).." is not an accessible member of base class "..tostring(baseClass) end,
    badInstantiate = function(fullClassName) return "Cannot instantiate abstract class "..fullClassName end
}

-- Declare and define variables used in class creation
local nilProxy = {} -- A value to be treated as nil while still holding table space
-- Makers
local makeFieldGetter = function(valueTab)
    return function()
        local value = valueTab[1]
        if value == nilProxy then
            value = nil
        end
        return value
    end
end
local makeFieldSetter = function(valueTab)
    return function(_, value)
        if value == nil then
            value = nilProxy
        end
        valueTab[1] = value
    end
end
local makePropertyGetter = function(getterFunc)
    return function(this)
        local value = getterFunc(this)
        if value == nilProxy then
            return nil
        end
        return value
    end
end
local makePropertySetter = function(setterFunc)
    return function(this, value)
        if value == nil then
            value = nilProxy
        end
        setterFunc(this, value)
    end
end
local makeMethodGetter = function(methodFunc)
    return function(this)
        return function(...)
            return methodFunc(this, ...)
        end
    end
end

-- Adders
local addFieldDefaultValues = function(fTemps, values, readonlyValueTabs)
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
local addFields = function(defValues, valueTabs, getters, setters)
    for name, defValue in pairs(defValues) do
        local valueTab = { defValue }
        valueTabs[name] = valueTab
        getters[name] = makeFieldGetter(valueTab)
        setters[name] = makeFieldSetter(valueTab)
    end
end
local addStaticFields = function(fTemps, valueTabs, getters, setters)
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
        end
    end
end
local addProperties = function(pTemps, getters, setters, initers)
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
local addMethods = function(mTemps, getters)
    for _, mTemp in ipairs(mTemps) do
        local name = mTemp[1]
        local func = mTemp[2]
        getters[name] = makeMethodGetter(func)
    end
end

-- Variables accessed internally only
local namespaces = {} -- string : namespace dictionary
local allClasses = {} -- class array
local allClassInheriteds = {} -- class : inheritedClass dictionary
local allClassDatas    = {} -- class : classData dictionary
local allPriClassDatas = {} -- class : priClassData dictionary
local allClassConstructors = {} -- class : function dictionary


-- Creates classes, used during namespace creation
local makeClass -- Self-referencing function
makeClass = function(temp, namespaceName, pubClasses, intClasses, intClassTemplates)
    -- Declare default constructor
    local constructor = temp.constructor or function(this, ...) end
    -- Initialize non-inherited private class-space class data
    local priClassData   = {}
    local priStaValues   = {}; priClassData.priStaValues  = priStaValues
    local priStaGetters  = {}; priClassData.priStaGetters = priStaGetters
    local priStaSetters  = {}; priClassData.priStaSetters = priStaSetters
    local priClaGetters  = {}; priClassData.priClaGetters = priClaGetters
    local priClaSetters  = {}; priClassData.priClaSetters = priClaSetters
    local priClaIniters  = {}; priClassData.priClaIniters = priClaIniters
    -- Initialize inherited non-private class-space data and private instance-space data
    local classData      = {}
    local proStaValues   = {}; classData.proStaValues   = proStaValues
    local pubStaValues   = {}; classData.pubStaValues   = pubStaValues
    local proStaGetters  = {}; classData.proStaGetters  = proStaGetters
    local proStaSetters  = {}; classData.proStaSetters  = proStaSetters
    local pubStaGetters  = {}; classData.pubStaGetters  = pubStaGetters
    local pubStaSetters  = {}; classData.pubStaSetters  = pubStaSetters
    local proClaGetters  = {}; classData.proClaGetters  = proClaGetters
    local proClaSetters  = {}; classData.proClaSetters  = proClaSetters
    local pubClaGetters  = {}; classData.pubClaGetters  = pubClaGetters
    local pubClaSetters  = {}; classData.pubClaSetters  = pubClaSetters
    local proClaIniters  = {}; classData.proClaIniters  = proClaIniters
    local pubClaIniters  = {}; classData.pubClaIniters  = pubClaIniters
    local priDefValues   = {}; classData.priDefValues   = priDefValues
    local proDefValues   = {}; classData.proDefValues   = proDefValues
    local pubDefValues   = {}; classData.pubDefValues   = pubDefValues
    local priDefValuesR  = {}; classData.priDefValuesR  = priDefValuesR
    local proDefValuesR  = {}; classData.proDefValuesR  = proDefValuesR
    local pubDefValuesR  = {}; classData.pubDefValuesR  = pubDefValuesR
    -- Initialize class object
    local staticProxy = {}
    -- Populate non-private class data with inherited data
    do
        local inherits = temp.inherits
        if inherits then
            local inheritedClass
            local split = temp.inherits:split(".")
            do
                local inheritedNamespaceName = split[1]
                local inheritedClassName = split[2]
                if inheritedNamespaceName == namespaceName then
                    inheritedClass = intClasses[inheritedClassName]
                    if not inheritedClass then
                        local inheritedTemplate = intClassTemplates[inheritedClassName]
                        inheritedClass = makeClass(inheritedTemplate, namespaceName, pubClasses, intClasses, intClassTemplates)
                    end
                end
                local inheritedNamespace = namespaces[inheritedNamespaceName]
                if not inheritedNamespace then
                    error("Namespace by the name "..inheritedNamespaceName.." does not exist")
                end
                inheritedClass = inheritedNamespace[inheritedClassName]
            end
            allClassInheriteds[staticProxy] = inheritedClass
            local inheritedClassDatas = {}
            local nextInheritedClass = inheritedClass
            while nextInheritedClass do
                table.insert(inheritedClassDatas, 1, allClassDatas[nextInheritedClass])
                nextInheritedClass = allClassInheriteds[nextInheritedClass]
            end
            for _, inheritedClassData in ipairs(inheritedClassDatas) do
                for dataName, data in pairs(inheritedClassData) do
                    local myDataTab = classData[dataName]
                    for dataName2, data2 in pairs(data) do
                        myDataTab[dataName2] = data2
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
    local fullClassName = namespaceName.."."..className
    local __str  = temp.__tostring or function() return fullClassName end
    -- Define static class metatable objects
    local claStaticMT, pubStaticMT
    do
        local commonStaticMT = {
            __tostring = function() return fullClassName end,
        }
        claStaticMT = {
            __index = function(_, k)
                local getter = pubStaGetters[k] or proStaGetters[k] or priStaGetters[k]
                if not getter then
                    error(errors.badStaGet(k, fullClassName))
                end
                return getter(staticProxy)
            end,
            __newindex = function(_, k, v)
                local setter = pubStaSetters[k] or proStaSetters[k] or priStaSetters[k]
                if not setter then
                    error(errors.badStaGet(k, fullClassName))
                end
                setter(staticProxy, v)
            end,
        }
        pubStaticMT = {
            __index = function(_, k)
                local getter = pubStaGetters[k]
                if not getter then
                    error(errors.badStaGet(k, fullClassName))
                end
                setmetatable(staticProxy, claStaticMT)
                local value = getter(staticProxy)
                setmetatable(staticProxy, pubStaticMT)
                return value
            end,
            __newindex = function(_, k, v)
                local setter = pubStaSetters[k]
                if not setter then
                    error(error.badStaSet(k, fullClassName))
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
    local __cat  = temp.__concat or function(t) error("Cannot concatenate "..fullClassName) end
    local __add  = temp.__add    or function(t) error("Cannot add "..fullClassName) end
    local __sub  = temp.__sub    or function(t) error("Cannot subtract "..fullClassName) end
    local __mul  = temp.__mul    or function(t) error("Cannot multiply "..fullClassName) end
    local __div  = temp.__div    or function(t) error("Cannot divide "..fullClassName) end
    local __idiv = temp.__idiv   or function(t) error("Cannot floor divide "..fullClassName) end
    local __mod  = temp.__mod    or function(t) error("Cannot modulo "..fullClassName) end
    local __pow  = temp.__pow    or function(t) error("Cannot exponentiate "..fullClassName) end
    local __lt   = temp.__lt     or function(t) error("Cannot compare less than ".. fullClassName) end
    local __le   = temp.__lt     or function(t) error("Cannot compare less than or equal to "..fullClassName) end
    local __len  = temp.__len    or function(t) error("Cannot get length of "..fullClassName) end
    local __iter = temp.__iter   or function(t) error("Cannot iterate "..fullClassName) end
    local commonInstanceMTM = { -- Metamethods  shared between instance MTs
        __tostring = __str, __concat = __cat, __add = __add, __sub = __sub,
        __mul = __mul, __div = __div, __idiv = __idiv, __mod = __mod, __pow = __pow,
        __lt = __lt, __le = __le, __len = __len, __iter = __iter,
    }
    local commonInstanceMTD = { -- Metadata shared between instance MTs
        __class = staticProxy,
        __type  = fullClassName
    }
    -- Setup construction if not an abstract class
    
    if temp.abstract then 
        pubStaticMT.__call = function()
            error(errors.badInstantiate(fullClassName))
        end
    else
        local makeInstance = function(constructor, ...)
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
            -- Declare incomplete instance metatable objects
            local instanceProxy = {}
            local claInstanceMT = {
                __index = function(_, k)
                    local getter = priGetters[k] or proGetters[k] or pubGetters[k] or
                        priClaGetters[k] or proClaGetters[k] or pubClaGetters[k] or
                        priStaGetters[k] or proStaGetters[k] or pubStaGetters[k]
                    if not getter then
                        error(errors.badInsGet(k, fullClassName))
                    end
                    return getter(instanceProxy)
                end,
                __newindex = function(_, k, v)
                    local setter = priSetters[k] or proSetters[k] or pubSetters[k] or
                        priClaSetters[k] or proClaSetters[k] or pubClaSetters[k]
                    if not setter then
                        error(errors.badInsSet(k, fullClassName))
                    end
                    setter(instanceProxy, v)
                end
            }
            local pubInstanceMT
            pubInstanceMT = {
                __index = function(_, k)
                    local getter = pubGetters[k] or pubClaGetters[k] or pubStaGetters[k]
                    if not getter then
                        error(errors.badInsGet(k, fullClassName))
                    end
                    setmetatable(instanceProxy, claInstanceMT)
                    local value = getter(instanceProxy)
                    setmetatable(instanceProxy, pubInstanceMT)
                    return value
                end,
                __newindex = function(_, k, v)
                    local setter = pubSetters[k] or pubClaSetters[k] or pubStaSetters[k]
                    if not setter then
                        error(errors.badInsSet(k, fullClassName))
                    end
                    setmetatable(instanceProxy, claInstanceMT)
                    setter(instanceProxy, v)
                    setmetatable(instanceProxy, pubInstanceMT)
                end
            }
            -- Declare temporary instance data (initers, constructor metatable)
            -- Setup instance proxy for construction
            -- Complete instance metatable objects
            do
                local priIniters = {}
                local proIniters = {}
                local pubIniters = {}
                addFields(priDefValuesR, priValues, priGetters, priIniters)
                addFields(proDefValuesR, proValues, proGetters, proIniters)
                addFields(pubDefValuesR, pubValues, pubGetters, pubIniters)
                local conInstanceMT = {
                    __index = function(_, k)
                        local getter = priGetters[k] or proGetters[k] or pubGetters[k] or
                            priClaGetters[k] or proClaGetters[k] or pubClaGetters[k] or
                            priStaGetters[k] or proStaGetters[k] or pubStaGetters[k]
                        if not getter then
                            error(errors.badInsGet(k, fullClassName))
                        end
                        return getter(instanceProxy)
                    end,
                    __newindex = function(_, k, v)
                        local setter = priIniters[k] or proIniters[k] or pubIniters[k] or
                            priClaIniters[k] or proClaIniters[k] or pubClaIniters[k] or
                            priSetters[k] or proSetters[k] or pubSetters[k]
                        if not setter then
                            error(errors.badInsSet(k, fullClassName))
                        end
                        setter(instanceProxy, v)
                    end
                }
                for metaName, metaOverride in pairs(commonInstanceMTM) do
                    conInstanceMT[metaName] = metaOverride
                    claInstanceMT[metaName] = metaOverride
                    pubInstanceMT[metaName] = function(...)
                        setmetatable(instanceProxy, claInstanceMT)
                        local value = metaOverride(...)
                        setmetatable(instanceProxy, pubInstanceMT)
                        return value
                    end
                end
                for metaName, metaData in pairs(commonInstanceMTD) do
                    conInstanceMT[metaName] = metaData
                    claInstanceMT[metaName] = metaData
                    pubInstanceMT[metaName] = metaData 
                end
                setmetatable(instanceProxy, conInstanceMT)
            end
            -- Run constructor function and return instance to user
            constructor(instanceProxy, ...)
            setmetatable(instanceProxy, pubInstanceMT)
            return instanceProxy
        end
         -- Define __call using public constructor only
        claStaticMT.__call = function(_, ...)
            return makeInstance(constructor, ...)
        end
        pubStaticMT.__call = function(_, ...)
            return makeInstance(constructor, ...)
        end
    end
    table.insert(allClasses, staticProxy)
    allClassDatas[staticProxy] = classData
    allPriClassDatas[staticProxy] = priClassData
    allClassConstructors[staticProxy] = constructor
    if temp.internal then
        intClasses[className] = staticProxy
    else
        pubClasses[className] = staticProxy
        intClasses[className] = staticProxy
    end
    temp = nil
    return staticProxy
end

local newNamespace = function(namespaceName, templates)
    if type(namespaceName) ~= "string" then
        error(errors.badStr("namespace"))
    end
    if namespaces[namespaceName] then
        error("A namespace by the name "..namespaceName.." already exists")
    end
    if type(templates) ~= "table" then
        error(errors.badTab("templates"))
    end

    local pubClasses = {} -- Contains only public classes, only used by namespace accessor
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

    do -- Validate and populate namespace
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
                if inherits then
                    if type(inherits) ~= "string" then
                        error("Bad type to inherits, expected string")
                    end
                    local split = inherits:split(".")
                    if #split ~= 2 then
                        error("Bad inherits format, expected namespace.className")
                    end
                    local inhNamespaceName = split[1]
                    local inhClassName = split[2]
                    local inhNamespace = namespaces[inhNamespaceName]
                    if not inhNamespace then
                        error("Namespace of inherited class "..inherits.." does not exist")
                    end
                    if inhNamespace ~= namespace then
                        local succ, _ = pcall(function()
                            return inhNamespace[inhClassName]
                        end)
                        if not succ then
                            error("Class by the name "..inherits.." does not exist")
                        end
                    else
                        local foundTemp = false
                        for _, template in pairs(templates) do
                            if template ~= tab then
                                local name = template.name
                                if name == inhClassName then
                                    foundTemp = true
                                    break
                                end
                            end
                        end
                        if not foundTemp then
                            error("Other template by the name "..inhClassName.." does not exist in validating namespace "..namespaceName)
                        end
                    end
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
        for _, temp in pairs(intClassTemplates) do
            makeClass(temp, namespaceName, pubClasses, intClasses, intClassTemplates)
        end
    end
    
    templates = nil

    return namespace
end

do -- Make internal namespace and object class
    local baseAccessors = setmetatable({}, {__mode = "v"}) -- Weak table for storing base accessors
    local objectClass = {
        name = "object",
        abstract = true,
        properties = {
            public = {
                {"className", function(this)
                    local CLASS = getmetatable(this).__class
                    return tostring(CLASS)
                end}
            },
            protected = {
                {"base", -- Accesses class space instance members of the base class (NOT THREAD SAFE)
                function(this)
                    local baseAccessor = baseAccessors[this]
                    if baseAccessor then return baseAccessor end
                    local CLASS = getmetatable(this).__class
                    local classHierarchy = {CLASS}
                    local baseClass = nil
                    local baseClassData = nil
                    local layer = 1
                    local incrementClass = function()
                        baseClass = classHierarchy[layer + 1]
                        if baseClass then
                            baseClassData = allClassDatas[baseClass]
                            layer = layer + 1
                            return
                        end
                        local currentClass = classHierarchy[layer]
                        baseClass = allClassInheriteds[currentClass]
                        if not baseClass then
                            error(errors.badBaseClass(currentClass))
                        end
                        baseClassData = allClassDatas[baseClass]
                        layer = layer + 1
                        classHierarchy[layer] = baseClass
                    end
                    local decrementClass = function()
                        layer = layer - 1
                        baseClass = classHierarchy[layer]
                        baseClassData = allClassDatas[baseClass]
                    end
                    baseAccessor = setmetatable({}, {
                        __index = function(_, k)
                            incrementClass()
                            local getter = baseClassData.proClaGetters[k] or
                                baseClassData.pubClaGetters[k]
                            if not getter then
                                error(errors.badBaseAccess(baseClass))
                            end
                            local value = getter(this)
                            decrementClass()
                            return value
                        end,
                        __newindex = function(_, k, v)
                            incrementClass()
                            local setter = baseClassData.proClaSetters[k] or 
                                baseClassData.pubClaSetters[k]
                            if not setter then
                                error(errors.badBaseAccess(baseClass))
                            end
                            setter(this, v)
                            decrementClass()
                        end,
                        __call = function(...)
                            incrementClass()
                            allClassConstructors[baseClass](this, ...)
                            decrementClass()
                        end
                    })
                    baseAccessors[this] = baseAccessor
                    return baseAccessor
                end,
                }
            }
        },
        methods = {
            public = {
                {"is", function(this, typeStr)
                    local CLASS = getmetatable(this).__class
                    if tostring(CLASS) == typeStr then
                        return true
                    end
                    return false
                end},
                {"isA", function(this, typeStr) -- Checks type inheritance
                    local CLASS = getmetatable(this).__class
                    local baseClass = allClassInheriteds[CLASS]
                    while baseClass ~= nil do
                        if tostring(baseClass) == typeStr then
                            return true
                        end
                        baseClass = allClassInheriteds[baseClass]
                    end
                    return false
                end}
            }
        }
    }
    newNamespace("qclass", { objectClass })
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