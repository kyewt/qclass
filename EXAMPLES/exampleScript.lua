local qclass = require "../qclass.lua"

local classModules = {
    "exampleClass.lua"
}

for _, classModule in ipairs(classModules) do
    qclass.new(require(classModule))
end

local classB = qclass.classes.classB
print(classB.pubStaFieldA)
local instB1 = qclass.publicConstruct(classB, "example1")
local instB2 = classB("example2")
-- Imagine we are in a protected scope
-- local instB3 = qclass.protectedConstructFromInst(this, "example3")
-- local instB4 = qclass.protectedConstructFromClass(class, "example4")
-- The same for private but with the qclass function name changed accordingly.