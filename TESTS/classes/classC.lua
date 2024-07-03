local classC = {
    name = "classC",
    inherits = "test.classB",
    properties = {
        public = {
            {"name", function(this)
                return this.base.name
            end}
        }
    }
}

return classC