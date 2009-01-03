StringBuffer = {}
StringBuffer_mt = { __index = StringBuffer }

function StringBuffer:new()
    local newObject = {
        stack = { n=0 }  -- 'n' counts number of elements in the stack        
    }  
    setmetatable(newObject, StringBuffer_mt)  
    return newObject
end

-- push 's' into the top of the stack
-- and concatenates shorter strings
function StringBuffer:addString(s)
    if s == nil then
        return
    end
    local stack = self.stack
    table.insert(stack, s)       
    for i = stack.n - 1, 1, -1 do
        if string.len(stack[i]) > string.len(stack[i+1]) then
            break 
        end
        stack[i] = stack[i] .. table.remove(stack)
    end
end

-- It just concatenates all strings down the bottom.
-- @return final contents of the buffer.
function StringBuffer:toString()
    local stack = self.stack
    for i = stack.n - 1, 1, -1 do
        stack[i] = stack[i] .. table.remove(stack)
    end
    return stack[1]
end

