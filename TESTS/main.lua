local qclass = require "../qclass.lua"
local namespace
do
    local classTemplates = {}
    local cpath = "./classes/"
    table.insert(classTemplates, require(cpath.."classA.lua"))
    table.insert(classTemplates, require(cpath.."classB.lua"))
    table.insert(classTemplates, require(cpath.."classC.lua"))
    namespace = qclass.newNamespace("test", classTemplates)
end

-- Test 1
if true then
    local classB = namespace.classB
    local instB1 = classB()
    local classC = namespace.classC
    local instC1 = classC()
    print(instB1.isA("test.classA"))
    print(instB1.name)
    print(instC1.isA("test.classA"))
    print(instC1.name)
end
