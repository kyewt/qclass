local classB = {
    name =  "classB",
    static = false,
    inherits = "classA",
    implements = { "interfaceA", "interfaceB" },
    statics = {
        fields = {
            private = {
                { "priStaFieldA", "private static string" },
                { "priStaFieldB", nil },
            },
            protected = {
                { "proStaFieldA", "protected static string"}
            },
            public = {
                { "pubStaFieldA", "public static string" }
            }
        },
        properties = {
            private = {
                {   "priStaPropertyA",
                    function(class) return class.priStaFieldA end,
                    function(class, value) class.priStaFieldA = value end
                },
                {   "priStaPropertyB",
                    function(class) return class.priStaFieldA end,
                    nil
                },
                {   "priStaPropertyC",
                    nil,
                    function(class, value) class.priStaFieldA = value end
                },
            },
            protected = {},
            public = {}
        },
        methods = {
            private = {
                { "priStaMethodA", function(class, ...) print(...) end }
            },
            protected = {},
            public = {},
        }
    },
    fields = {
        private = {
            { "priFieldA", "private string", "readonly"},
            { "priFieldB", nil, "readonly"},
        },
        protected = { 
            { "proFieldA", "protected string" }
        },
        public = {
            { "pubFieldA", "public string" }
        }
    },
    properties = {
        private = {
            {   "priPropertyA",
                function(this) return this.priFieldA end,
                function(this, value) this.priFieldA = value end,
            },
            {   "priPropertyB",
                function(this) return this.priFieldA end,
                function(this, value) this.priFieldA = value end,
            },
            {
                "priPropertyC",
                function(this) return this.priFieldA end,
                nil,
                function(this, value)
                    if type(value) ~= "string" then
                        error("bad type to value expected string, got "..type(value))
                    end
                    this.priFieldA = value
                end
            }
        },
        protected = {},
        public = {}
    },
    methods = {
        private = {
            { "priMethodA", function(this) print("priMethodA: "..tostring(this)) end }
        },
        protected = {},
        public = {}
    },
    constructors = {
        private = function(this, ...)
            
        end,
        protected = nil,
        public = function(this, ...)
            local myArgs = {...}
            local initValue = myArgs[1]
            this.priPropertyC = initValue
            this.priMethodA()
            this.priFieldB = { "hi ", "nice ", "to ", "meet ", "you."}
        end,
    },
    __tostring = function(this) return this.priFieldA end,
}

table.freeze(classB)
-- If unfrozen, the class may be modified by other scripts, do what you want.

return classB