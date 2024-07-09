local qclass = require "../qclass.lua"

local classModules = {
    "exampleClass.lua"
}

for _, classModule in ipairs(classModules) do
    qclass.new(require(classModule))
end

local classB = qclass.classes.classB
print(classB.pubStaFieldA)
local instB1 = classB("example1")