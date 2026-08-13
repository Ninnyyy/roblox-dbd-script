local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Helpers = {
    Name = "Helpers",
}


-- Constants


Helpers.IsStudio = RunService:IsStudio()


-- Safe execution


function Helpers:SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result =
        pcall(callback, ...)

    if not success then
        warn(
            "[Lua Test] Helpers.SafeCall:",
            result
        )

        return false, result
    end

    return true, result
end

function Helpers:Try(callback, fallback, ...)
    if type(callback) ~= "function" then
        return fallback
    end

    local success, result =
        pcall(callback, ...)

    if success then
        return result
    end

    return fallback
end


-- Type helpers


function Helpers:IsNil(value)
    return value == nil
end

function Helpers:IsString(value)
    return type(value) == "string"
end

function Helpers:IsNumber(value)
    return type(value) == "number"
end

function Helpers:IsBoolean(value)
    return type(value) == "boolean"
end

function Helpers:IsFunction(value)
    return type(value) == "function"
end

function Helpers:IsTable(value)
    return type(value) == "table"
end

function Helpers:IsInstance(value)
    return typeof(value) == "Instance"
end

function Helpers:IsVector2(value)
    return typeof(value) == "Vector2"
end

function Helpers:IsVector3(value)
    return typeof(value) == "Vector3"
end

function Helpers:IsCFrame(value)
    return typeof(value) == "CFrame"
end

function Helpers:IsColor3(value)
    return typeof(value) == "Color3"
end


-- String helpers


function Helpers:Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$")
end

function Helpers:Lower(value)
    if type(value) ~= "string" then
        return ""
    end

    return string.lower(value)
end

function Helpers:Upper(value)
    if type(value) ~= "string" then
        return ""
    end

    return string.upper(value)
end

function Helpers:StartsWith(
    value,
    prefix
)
    if type(value) ~= "string"
        or type(prefix) ~= "string" then
        return false
    end

    return value:sub(
        1,
        #prefix
    ) == prefix
end

function Helpers:EndsWith(
    value,
    suffix
)
    if type(value) ~= "string"
        or type(suffix) ~= "string" then
        return false
    end

    if suffix == "" then
        return true
    end

    return value:sub(
        -#suffix
    ) == suffix
end

function Helpers:Contains(
    value,
    search
)
    if type(value) ~= "string"
        or type(search) ~= "string" then
        return false
    end

    return string.find(
        value,
        search,
        1,
        true
    ) ~= nil
end

function Helpers:Capitalize(value)
    if type(value) ~= "string"
        or value == "" then
        return ""
    end

    return value:sub(1, 1):upper()
        .. value:sub(2)
end

function Helpers:TitleCase(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:gsub(
        "(%a)([%w_]*)",
        function(first, rest)
            return first:upper()
                .. rest:lower()
        end
    )
end


-- Number helpers


function Helpers:ToNumber(
    value,
    fallback
)
    local number =
        tonumber(value)

    if number == nil then
        return fallback
    end

    return number
end

function Helpers:ToBoolean(
    value,
    fallback
)
    if type(value) == "boolean" then
        return value
    end

    if type(value) == "string" then
        local lower =
            string.lower(
                self:Trim(value)
            )

        if lower == "true"
            or lower == "yes"
            or lower == "on"
            or lower == "1" then
            return true
        end

        if lower == "false"
            or lower == "no"
            or lower == "off"
            or lower == "0" then
            return false
        end
    end

    if type(value) == "number" then
        return value ~= 0
    end

    return fallback
end

function Helpers:FormatNumber(
    value,
    decimals
)
    value =
        tonumber(value)
        or 0

    decimals =
        tonumber(decimals)
        or 0

    return string.format(
        "%." .. decimals .. "f",
        value
    )
end

function Helpers:FormatCompact(
    value
)
    value =
        tonumber(value)
        or 0

    local absolute =
        math.abs(value)

    if absolute >= 1e9 then
        return string.format(
            "%.2fB",
            value / 1e9
        )
    end

    if absolute >= 1e6 then
        return string.format(
            "%.2fM",
            value / 1e6
        )
    end

    if absolute >= 1e3 then
        return string.format(
            "%.2fK",
            value / 1e3
        )
    end

    return tostring(
        math.floor(value)
    )
end


-- Time helpers


function Helpers:FormatTime(seconds)
    seconds =
        math.max(
            0,
            tonumber(seconds)
                or 0
        )

    local hours =
        math.floor(
            seconds / 3600
        )

    local minutes =
        math.floor(
            (seconds % 3600)
            / 60
        )

    local remaining =
        math.floor(
            seconds % 60
        )

    if hours > 0 then
        return string.format(
            "%02d:%02d:%02d",
            hours,
            minutes,
            remaining
        )
    end

    return string.format(
        "%02d:%02d",
        minutes,
        remaining
    )
end

function Helpers:Now()
    return os.clock()
end

function Helpers:UnixTime()
    return os.time()
end


-- Table helpers


function Helpers:TableContains(
    tableValue,
    value
)
    if type(tableValue) ~= "table" then
        return false
    end

    for _, item in pairs(tableValue) do
        if item == value then
            return true
        end
    end

    return false
end

function Helpers:TableFind(
    tableValue,
    value
)
    if type(tableValue) ~= "table" then
        return nil
    end

    for key, item in pairs(tableValue) do
        if item == value then
            return key
        end
    end

    return nil
end

function Helpers:TableCount(
    tableValue
)
    if type(tableValue) ~= "table" then
        return 0
    end

    local count = 0

    for _ in pairs(tableValue) do
        count += 1
    end

    return count
end

function Helpers:ArrayCount(
    tableValue
)
    if type(tableValue) ~= "table" then
        return 0
    end

    return #tableValue
end

function Helpers:ClearTable(
    tableValue
)
    if type(tableValue) ~= "table" then
        return false
    end

    for key in pairs(tableValue) do
        tableValue[key] = nil
    end

    return true
end

function Helpers:CopyTable(
    tableValue,
    deep
)
    if type(tableValue) ~= "table" then
        return tableValue
    end

    local copy = {}

    for key, value in pairs(tableValue) do
        if deep
            and type(value) == "table" then
            copy[key] =
                self:CopyTable(
                    value,
                    true
                )
        else
            copy[key] = value
        end
    end

    return copy
end

function Helpers:MergeTables(
    target,
    source,
    deep
)
    if type(target) ~= "table"
        or type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if deep
            and type(value) == "table"
            and type(target[key]) == "table" then
            self:MergeTables(
                target[key],
                value,
                true
            )
        elseif deep
            and type(value) == "table" then
            target[key] =
                self:CopyTable(
                    value,
                    true
                )
        else
            target[key] = value
        end
    end

    return target
end

function Helpers:ArrayRemove(
    array,
    value
)
    if type(array) ~= "table" then
        return false
    end

    for index = #array, 1, -1 do
        if array[index] == value then
            table.remove(
                array,
                index
            )

            return true
        end
    end

    return false
end

function Helpers:ArrayRemoveAll(
    array,
    value
)
    if type(array) ~= "table" then
        return 0
    end

    local removed = 0

    for index = #array, 1, -1 do
        if array[index] == value then
            table.remove(
                array,
                index
            )

            removed += 1
        end
    end

    return removed
end


-- Instance helpers


function Helpers:Find(
    parent,
    name
)
    if not parent
        or type(name) ~= "string" then
        return nil
    end

    return parent:FindFirstChild(
        name
    )
end

function Helpers:FindClass(
    parent,
    className
)
    if not parent
        or type(className) ~= "string" then
        return nil
    end

    for _, child in ipairs(
        parent:GetChildren()
    ) do
        if child:IsA(className) then
            return child
        end
    end

    return nil
end

function Helpers:IsDescendant(
    instance,
    ancestor
)
    if not instance
        or not ancestor then
        return false
    end

    local success, result =
        pcall(function()
            return instance:IsDescendantOf(
                ancestor
            )
        end)

    return success
        and result == true
end

function Helpers:SafeDestroy(
    instance
)
    if not instance then
        return false
    end

    local success =
        pcall(function()
            instance:Destroy()
        end)

    return success
end

function Helpers:SetProperty(
    instance,
    property,
    value
)
    if not instance
        or type(property) ~= "string" then
        return false
    end

    local success =
        pcall(function()
            instance[property] = value
        end)

    return success
end

function Helpers:GetProperty(
    instance,
    property,
    fallback
)
    if not instance
        or type(property) ~= "string" then
        return fallback
    end

    local success, value =
        pcall(function()
            return instance[property]
        end)

    if not success then
        return fallback
    end

    return value
end


-- Roblox object creation


function Helpers:Create(
    className,
    properties,
    parent
)
    if type(className) ~= "string"
        or className == "" then
        return nil
    end

    local success, instance =
        pcall(function()
            return Instance.new(
                className
            )
        end)

    if not success
        or not instance then
        warn(
            "[Lua Test] Failed to create:",
            className
        )

        return nil
    end

    if type(properties) == "table" then
        for property, value in pairs(
            properties
        ) do
            pcall(function()
                instance[property] =
                    value
            end)
        end
    end

    if parent then
        pcall(function()
            instance.Parent = parent
        end)
    end

    return instance
end


-- Signal helpers


function Helpers:Connect(
    signal,
    callback
)
    if not signal
        or type(callback) ~= "function" then
        return nil
    end

    local success, connection =
        pcall(function()
            return signal:Connect(
                callback
            )
        end)

    if not success then
        return nil
    end

    return connection
end

function Helpers:Disconnect(
    connection
)
    if not connection then
        return false
    end

    local success =
        pcall(function()
            connection:Disconnect()
        end)

    return success
end


-- Task helpers


function Helpers:Delay(
    duration,
    callback
)
    if type(callback) ~= "function" then
        return nil
    end

    duration =
        math.max(
            0,
            tonumber(duration)
                or 0
        )

    return task.delay(
        duration,
        callback
    )
end

function Helpers:Spawn(
    callback
)
    if type(callback) ~= "function" then
        return nil
    end

    return task.spawn(
        callback
    )
end

function Helpers:Cancel(
    thread
)
    if not thread then
        return false
    end

    local success =
        pcall(function()
            task.cancel(thread)
        end)

    return success
end


-- JSON helpers


function Helpers:EncodeJSON(
    value
)
    local success, result =
        pcall(function()
            return HttpService:JSONEncode(
                value
            )
        end)

    if not success then
        return nil
    end

    return result
end

function Helpers:DecodeJSON(
    value
)
    if type(value) ~= "string" then
        return nil
    end

    local success, result =
        pcall(function()
            return HttpService:JSONDecode(
                value
            )
        end)

    if not success then
        return nil
    end

    return result
end


-- Color helpers


function Helpers:IsColor(
    value
)
    return typeof(value) == "Color3"
end

function Helpers:ColorFromRGB(
    r,
    g,
    b
)
    return Color3.fromRGB(
        tonumber(r) or 255,
        tonumber(g) or 255,
        tonumber(b) or 255
    )
end

function Helpers:ColorToRGB(
    color
)
    if not self:IsColor(color) then
        return nil
    end

    return {
        R = math.floor(
            color.R * 255 + 0.5
        ),

        G = math.floor(
            color.G * 255 + 0.5
        ),

        B = math.floor(
            color.B * 255 + 0.5
        ),
    }
end


-- Debug helpers


function Helpers:Debug(
    ...)
    print(
        "[Lua Test]",
        ...
    )
end

function Helpers:Warn(
    ...
)
    warn(
        "[Lua Test]",
        ...
    )
end

function Helpers:Assert(
    condition,
    message
)
    if condition then
        return true
    end

    error(
        message
            or "[Lua Test] Assertion failed",
        2
    )
end

return Helpers