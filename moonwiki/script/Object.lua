---
-- class Object
Object = { 
    super = nil,
    name = "Object",
    methods = {}
}

-- constructor 
function Object.new(class, ...)
    -- put class reference to object's table
    local newObject = { class = class}
    local meta = { 
        __index = function(self,key)
            return self.class.methods[key] 
        end
    }
    setmetatable(newObject, meta)
    -- check if additional arguments was specified
    if table.getn(arg) == 0 then
        return newObject
    end
    for i,table in ipairs(arg) do
        --print("i,table", i, table)
        if type(table) == "table" then
            -- copy all keys and values to new object
            for key, value in pairs(table) do
                --print("key=", key, "value=", value)
                newObject[key] = value
            end
        end
    end
    return newObject
end


-- common methods

function Object.methods:toString()
    local result = "Class '" .. self.class.name .. "'"
    if self.class.super ~= nil then
        result = result .. " inherited from '" .. self.class.super.name .. "'"
    end
    result = result .. ", self = " .. tostring(self)
    return result
end


-- Return true if the caller is an instance of class
function Object.methods:instanceof(class)
    local result = false
    local currentClass = self.class
    while ( nil ~= currentClass ) and ( false == result ) do
        if( currentClass == class ) then
            result = true
        else
            currentClass = currentClass.super
        end
    end
    return result
end

-- helper function for class creation
function class(name, super)
    assert(super ~= nil)
    local newClass = {
        super = super,
        name = name,
        new = super.new,
        methods = {}
    }
    
    -- if class slot unavailable, check super class
    -- if applied to argument, pass it to the class method new
    setmetatable(newClass, { 
        __index = function(self,key)
            return self.super[key]
        end ,
        __call = function(self,...)
            return self.new(self,unpack(arg))
        end
    })
    -- if instance method unavailable, check method slot in super class
    setmetatable(newClass.methods, { 
        __index = function(self,key)
            return newClass.super.methods[key] 
        end
    })
    return newClass
end

--[[
TestClass = class("TestClass", Object)

local object1 = Object:new()
print(object1:toString())
print(object1.class.super)
print(object1.class)

local object2 = TestClass:new(1)
print(object2:toString())
print(object2.class.super)
print(object2.class)

print(object1:instanceof(Object))
print(object1:instanceof(TestClass))
print(object2:instanceof(Object))
print(object2:instanceof(TestClass))

local object3 = TestClass {a="aaa"}
print(object3.a)

print("obj5")
local object5 = TestClass {}
local object6 = TestClass()
local object7 = TestClass(nil)
local object8 = TestClass "aaa"
local object9 = TestClass {a="aaa"}
print("obj5")

NextClass = class("NextClass", TestClass)

function NextClass.create()
    local newObject = NextClass {
        field1 = 1,
        field2 = 2
    }
    return newObject
end
local object4 = NextClass.create()
print (object4.field1)
print (object4.field2)
print (object4:toString())
print (object4:instanceof(TestClass))

print ("aaaaaaaaaaaa")
SecondClass = class("SecondClass", NextClass)

function SecondClass.new(class)
    local newObject = SecondClass.super.new(class, {
        dd = "aaaccc",
        aa = "dddeee"
    })
    return newObject
end

local aa = SecondClass()
print(aa.aa)
print(aa.dd)
]]
