local classA = {
    name = "classA",
    inherits = "qclass.object",
    properties = {
        public = {
            {"name", function()
                return "classA.name"
            end}
        }
    }
}

return classA