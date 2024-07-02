local qclass = require "../qclass.lua"
local namespace
do
    local classTemplates = {}
    local cpath = "./classes/"
    table.insert(classTemplates, require(cpath.."classA.lua"))
    table.insert(classTemplates, require(cpath.."classB.lua"))
    namespace = qclass.newNamespace("test", classTemplates)
end

local classB = namespace.classB
local instB1 = classB("instB1")

if true then
    print(tostring(instB1))
    --print(instB1.priPropertyC)
end
