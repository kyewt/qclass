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
                -- Getter and setter
                {   "priStaPropertyA",
                    function(class) return class.priStaFieldA end,
                    function(class, value) class.priStaFieldA = value end
                },
                -- Only getter
                {   "priStaPropertyB",
                    function(class) return class.priStaFieldA end,
                },
                -- Only setter
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
            { "priFieldA", "private string"},
            { "priFieldB", nil}
        },
        protected = { 
            { "proFieldA", "protected string" }
        },
        public = {
            { "pubFieldA", "public string", "readonly" }
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
            -- Non-static properties may have a fourth value, the initializer
            -- Initializers are setters only accessible during construction
            -- Initializers may set readonly fields
            {
                "priPropertyC",
                function(this) return this.priFieldA end,
                nil,
                function(this, value) this.priFieldA = value end
            }
        },
        protected = {},
        public = {}
    },
    methods = {
        private = {
            { "priMethodA", function(this) print(tostring(this)) end }
        },
        protected = {},
        public = {}
    },
    constructors = {
        public = function(this, ...)
            local myArgs = {...}
            local myStr = myArgs[1]
            this.pubFieldA = myStr
        end,
    },
    __tostring = function(this) return this.priFieldA end,
}

return classB