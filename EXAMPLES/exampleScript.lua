local qclass = require "../qclass.lua"

local classTemplates = {
    require "exampleClass.lua"
}

local namespace = qclass.newNamespace("example", classTemplates)

local classA = namespace.classA
print(classA.pubStaFieldA)
local instA1 = classA("example1")
print(instA1.pubStaFieldA)