-- 独立的最小堆数据结构模块
-- 分离自explorer.lua以提高代码组织性

local MinHeap = {}
MinHeap.__index = MinHeap

-- 创建新的最小堆
-- @param compare 比较函数，默认为小于比较
function MinHeap.new(compare)
    return setmetatable({
        heap = {}, 
        compare = compare or function(a, b) return a < b end
    }, MinHeap)
end

-- 向堆中添加元素
-- @param value 要添加的值
function MinHeap:push(value)
    table.insert(self.heap, value)
    self:siftUp(#self.heap)
end

-- 移除并返回堆顶元素
-- @return 堆顶元素，如果堆为空则返回nil
function MinHeap:pop()
    if #self.heap == 0 then
        return nil
    end
    
    local root = self.heap[1]
    self.heap[1] = self.heap[#self.heap]
    table.remove(self.heap)
    
    if #self.heap > 0 then
        self:siftDown(1)
    end
    
    return root
end

-- 查看堆顶元素而不移除
-- @return 堆顶元素，如果堆为空则返回nil
function MinHeap:peek()
    return self.heap[1]
end

-- 检查堆是否为空
-- @return true如果堆为空，否则false
function MinHeap:empty()
    return #self.heap == 0
end

-- 获取堆大小
-- @return 堆中元素的数量
function MinHeap:size()
    return #self.heap
end

-- 检查堆是否包含指定值
-- @param value 要检查的值
-- @return true如果包含，否则false
-- 注意：这是O(n)操作，使用时要谨慎
function MinHeap:contains(value)
    for _, v in ipairs(self.heap) do
        if v == value then return true end
    end
    return false
end

-- 清空堆
function MinHeap:clear()
    self.heap = {}
end

-- 内部函数：上浮操作
-- @param index 要上浮的元素索引
function MinHeap:siftUp(index)
    local parent = math.floor(index / 2)
    while index > 1 and self.compare(self.heap[index], self.heap[parent]) do
        self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
        index = parent
        parent = math.floor(index / 2)
    end
end

-- 内部函数：下沉操作
-- @param index 要下沉的元素索引
function MinHeap:siftDown(index)
    local size = #self.heap
    while true do
        local smallest = index
        local left = 2 * index
        local right = 2 * index + 1
        
        if left <= size and self.compare(self.heap[left], self.heap[smallest]) then
            smallest = left
        end
        if right <= size and self.compare(self.heap[right], self.heap[smallest]) then
            smallest = right
        end
        
        if smallest == index then break end
        
        self.heap[index], self.heap[smallest] = self.heap[smallest], self.heap[index]
        index = smallest
    end
end

-- 调试函数：打印堆内容
function MinHeap:debug_print()
    print("MinHeap contents: " .. table.concat(self.heap, ", "))
end

-- 验证堆属性（用于调试）
-- @return true如果堆属性正确，否则false
function MinHeap:validate()
    for i = 1, math.floor(#self.heap / 2) do
        local left = 2 * i
        local right = 2 * i + 1
        
        if left <= #self.heap and not self.compare(self.heap[i], self.heap[left]) then
            return false, "堆属性在索引 " .. i .. " 和 " .. left .. " 之间违反"
        end
        
        if right <= #self.heap and not self.compare(self.heap[i], self.heap[right]) then
            return false, "堆属性在索引 " .. i .. " 和 " .. right .. " 之间违反"
        end
    end
    
    return true, "堆属性正确"
end

return MinHeap