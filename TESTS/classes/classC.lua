local classC = {
    name = "classC",
    inherits = "test.classB",
    fields = {
        public = {
            {"fname", nil, "readonly"}
        }
    },
    properties = {
        public = {
            {"name", function(this)
                return this.base.name
            end}
        }
    },
    constructor = function(this)
        this.fname = this.name
    end
}

return classC