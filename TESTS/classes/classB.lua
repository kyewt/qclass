local count = 0

local classB = {
    name = "classB",
    inherits = "test.classA",
    properties = {
        public = {
            {"name", function(this)
                return this.base.name
            end}
        }
    }
}

return classB