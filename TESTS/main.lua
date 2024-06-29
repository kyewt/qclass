local qclass = require "../qclass.lua"
do
    local classTemplates = {}
    local cpath = "./classes/"
    table.insert(classTemplates, require(cpath.."classA.lua"))
    table.insert(classTemplates, require(cpath.."classB.lua"))
    for _, temp in ipairs(classTemplates) do
        qclass.registerTemplate(temp)
    end
    for _, temp in ipairs(classTemplates) do
        qclass.registerClass(temp.name)
    end
end

local classB = qclass.classes.classB
local instB1 = classB("instB1")

if true then
    print(tostring(instB1))
    print(instB1.priPropertyC)
end
