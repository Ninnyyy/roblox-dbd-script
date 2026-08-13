--[[
    Lua Test Script
    Helpers.lua

    Shared utility helpers.

    Responsibilities:
        - Safe function execution
        - Type checking
        - Table utilities
        - String utilities
        - Instance utilities
        - Number utilities
        - Player / character helpers
        - Roblox object validation
        - Deep copy
        - Deep merge
        - Clamp / rounding
        - Runtime-safe helpers
]]

local Players = game:GetService("Players")

local Helpers = {
    Name = "Helpers",
    Version = "2.1.0",

    Initialized = false,
}



-- Safe Execution


function Helpers:SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result = pcall(
        callback,
        ...
    )

    if not success then
        warn(
            "[Lua Test] Helpers.SafeCall:",
            result
        )

        return false, result
    end

    return true, result
end


function Helpers:Try(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    return pcall(
        callback,
        ...
    )
end



-- Type Helpers


function Helpers:IsString(value)
    return type(value) == "string"
end


function Helpers:IsNumber(value)
    return type(value) == "number"
        and value == value
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


function Helpers:IsConnection(value)
    return typeof(value) == "RBXScriptConnection"
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



-- String Helpers


function Helpers:IsEmptyString(value)
    return type(value) ~= "string"
        or value == ""
end


function Helpers:Trim(value)
    if type(value) ~= "string" then
        return value
    end

    return value:match("^%s*(.-)%s*$")
end


function Helpers:Lower(value)
    if type(value) ~= "string" then
        return value
    end

    return string.lower(value)
end


function Helpers:Upper(value)
    if type(value) ~= "string" then
        return value
    end

    return string.upper(value)
end


function Helpers:StartsWith(value, prefix)
    if type(value) ~= "string"
        or type(prefix) ~= "string" then

        return false
    end

    return string.sub(
        value,
        1,
        #prefix
    ) == prefix
end


function Helpers:EndsWith(value, suffix)
    if type(value) ~= "string"
        or type(suffix) ~= "string" then

        return false
    end

    if #suffix > #value then
        return false
    end

    return string.sub(
        value,
        -#suffix
    ) == suffix
end


function Helpers:Contains(value, search)
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


function Helpers:Split(value, separator)
    local result = {}

    if type(value) ~= "string" then
        return result
    end

    separator =
        separator or "%s"

    if separator == "%s" then
        for part in string.gmatch(
            value,
            "%S+"
        ) do
            table.insert(
                result,
                part
            )
        end

        return result
    end

    local pattern =
        "([^"
        .. separator
        .. "]+)"

    for part in string.gmatch(
        value,
        pattern
    ) do
        table.insert(
            result,
            part
        )
    end

    return result
end


function Helpers:Join(values, separator)
    if type(values) ~= "table" then
        return ""
    end

    return table.concat(
        values,
        separator or ", "
    )
end



-- Number Helpers


function Helpers:Clamp(
    value,
    minimum,
    maximum
)
    if type(value) ~= "number" then
        return minimum
    end

    if minimum > maximum then
        minimum, maximum =
            maximum, minimum
    end

    return math.clamp(
        value,
        minimum,
        maximum
    )
end


function Helpers:Round(value, decimals)
    if type(value) ~= "number" then
        return 0
    end

    decimals =
        tonumber(decimals)
        or 0

    decimals =
        math.max(
            0,
            math.floor(decimals)
        )

    local multiplier =
        10 ^ decimals

    return math.floor(
        value * multiplier + 0.5
    ) / multiplier
end


function Helpers:Floor(value)
    if type(value) ~= "number" then
        return 0
    end

    return math.floor(value)
end


function Helpers:Ceil(value)
    if type(value) ~= "number" then
        return 0
    end

    return math.ceil(value)
end


function Helpers:Abs(value)
    if type(value) ~= "number" then
        return 0
    end

    return math.abs(value)
end


function Helpers:Lerp(a, b, alpha)
    if type(a) ~= "number"
        or type(b) ~= "number" then

        return a
    end

    alpha =
        self:Clamp(
            tonumber(alpha) or 0,
            0,
            1
        )

    return a + (b - a) * alpha
end


function Helpers:Map(
    value,
    inputMin,
    inputMax,
    outputMin,
    outputMax
)
    if inputMax == inputMin then
        return outputMin
    end

    local alpha =
        (value - inputMin)
        / (inputMax - inputMin)

    return outputMin
        + (
            outputMax - outputMin
        ) * alpha
end



-- Table Helpers


function Helpers:DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen =
        seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}

    seen[value] = copy

    for key, child in pairs(value) do
        copy[
            self:DeepCopy(
                key,
                seen
            )
        ] =
            self:DeepCopy(
                child,
                seen
            )
    end

    return copy
end


function Helpers:DeepMerge(
    original,
    incoming
)
    local result =
        self:DeepCopy(original)

    if type(incoming) ~= "table" then
        return result
    end

    for key, value in pairs(
        incoming
    ) do

        if type(value) == "table"
            and type(result[key]) == "table" then

            result[key] =
                self:DeepMerge(
                    result[key],
                    value
                )

        else
            result[key] =
                self:DeepCopy(value)
        end
    end

    return result
end


function Helpers:TableCount(tableValue)
    if type(tableValue) ~= "table" then
        return 0
    end

    local count = 0

    for _ in pairs(tableValue) do
        count += 1
    end

    return count
end


function Helpers:TableIsEmpty(tableValue)
    if type(tableValue) ~= "table" then
        return true
    end

    return next(tableValue) == nil
end


function Helpers:TableContains(
    tableValue,
    target
)
    if type(tableValue) ~= "table" then
        return false
    end

    for _, value in pairs(tableValue) do
        if value == target then
            return true
        end
    end

    return false
end


function Helpers:TableFind(
    tableValue,
    target
)
    if type(tableValue) ~= "table" then
        return nil
    end

    for key, value in pairs(tableValue) do
        if value == target then
            return key
        end
    end

    return nil
end


function Helpers:TableClear(tableValue)
    if type(tableValue) ~= "table" then
        return false
    end

    table.clear(tableValue)

    return true
end


function Helpers:ArrayCopy(tableValue)
    if type(tableValue) ~= "table" then
        return {}
    end

    local result = {}

    for index, value in ipairs(
        tableValue
    ) do
        result[index] = value
    end

    return result
end


function Helpers:ArrayRemove(
    tableValue,
    target
)
    if type(tableValue) ~= "table" then
        return false
    end

    for index = #tableValue, 1, -1 do
        if tableValue[index] == target then
            table.remove(
                tableValue,
                index
            )

            return true
        end
    end

    return false
end



-- Instance Helpers


function Helpers:IsAlive(instance)
    if not instance then
        return false
    end

    if not instance.Parent then
        return false
    end

    return true
end


function Helpers:Find(
    parent,
    name
)
    if not parent
        or type(name) ~= "string" then

        return nil
    end

    local success, result =
        pcall(function()
            return parent:FindFirstChild(
                name
            )
        end)

    if success then
        return result
    end

    return nil
end


function Helpers:WaitFor(
    parent,
    name,
    timeout
)
    if not parent
        or type(name) ~= "string" then

        return nil
    end

    local success, result =
        pcall(function()
            return parent:WaitForChild(
                name,
                timeout
            )
        end)

    if success then
        return result
    end

    return nil
end


function Helpers:Destroy(instance)
    if not instance then
        return false
    end

    local success =
        pcall(function()
            instance:Destroy()
        end)

    return success
end


function Helpers:SetParent(
    instance,
    parent
)
    if not instance then
        return false
    end

    local success =
        pcall(function()
            instance.Parent = parent
        end)

    return success
end



-- Character Helpers


function Helpers:GetCharacter(
    player
)
    if not player then
        return nil
    end

    return player.Character
end


function Helpers:GetHumanoid(
    character
)
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end


function Helpers:GetRoot(
    character
)
    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end


function Helpers:GetRootPosition(
    character
)
    local root =
        self:GetRoot(character)

    if not root then
        return nil
    end

    return root.Position
end


function Helpers:IsCharacterAlive(
    character
)
    local humanoid =
        self:GetHumanoid(
            character
        )

    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end


function Helpers:GetHealthPercent(
    character
)
    local humanoid =
        self:GetHumanoid(
            character
        )

    if not humanoid then
        return 0
    end

    if humanoid.MaxHealth <= 0 then
        return 0
    end

    return math.clamp(
        humanoid.Health
            / humanoid.MaxHealth,
        0,
        1
    )
end


function Helpers:GetCharacterDistance(
    characterA,
    characterB
)
    local rootA =
        self:GetRoot(characterA)

    local rootB =
        self:GetRoot(characterB)

    if not rootA
        or not rootB then

        return math.huge
    end

    return (
        rootA.Position
        - rootB.Position
    ).Magnitude
end



-- Player Helpers


function Helpers:GetLocalPlayer()
    return Players.LocalPlayer
end


function Helpers:GetPlayers()
    return Players:GetPlayers()
end


function Helpers:IsLocalPlayer(
    player
)
    return player
        ~= nil
        and player
        == Players.LocalPlayer
end


function Helpers:GetPlayerFromCharacter(
    character
)
    if not character then
        return nil
    end

    return Players:GetPlayerFromCharacter(
        character
    )
end


function Helpers:IsPlayerAlive(
    player
)
    if not player then
        return false
    end

    return self:IsCharacterAlive(
        player.Character
    )
end


function Helpers:GetPlayerDistance(
    playerA,
    playerB
)
    if not playerA
        or not playerB then

        return math.huge
    end

    return self:GetCharacterDistance(
        playerA.Character,
        playerB.Character
    )
end



-- Humanoid Helpers


function Helpers:GetHumanoidState(
    character
)
    local humanoid =
        self:GetHumanoid(
            character
        )

    if not humanoid then
        return nil
    end

    return humanoid:GetState()
end


function Helpers:IsGrounded(
    character
)
    local humanoid =
        self:GetHumanoid(
            character
        )

    if not humanoid then
        return false
    end

    local state =
        humanoid:GetState()

    return state
        == Enum.HumanoidStateType.Running
        or state
        == Enum.HumanoidStateType.RunningNoPhysics
end


function Helpers:IsMoving(
    character
)
    local humanoid =
        self:GetHumanoid(
            character
        )

    if not humanoid then
        return false
    end

    return humanoid.MoveDirection.Magnitude > 0
end



-- Connection Helpers


function Helpers:Disconnect(
    connection
)
    if not connection then
        return false
    end

    if typeof(connection)
        ~= "RBXScriptConnection" then

        return false
    end

    local success =
        pcall(function()
            connection:Disconnect()
        end)

    return success
end


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
        warn(
            "[Lua Test] Helpers.Connect:",
            connection
        )

        return nil
    end

    return connection
end



-- Path Helpers


function Helpers:SplitPath(path)
    local result = {}

    if type(path) ~= "string" then
        return result
    end

    for part in string.gmatch(
        path,
        "[^%.]+"
    ) do
        table.insert(
            result,
            part
        )
    end

    return result
end


function Helpers:GetPath(
    root,
    path
)
    if type(root) ~= "table"
        or type(path) ~= "string" then

        return nil
    end

    local parts =
        self:SplitPath(path)

    if #parts == 0 then
        return nil
    end

    local current = root

    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return nil
        end

        current =
            current[part]

        if current == nil then
            return nil
        end
    end

    return current
end


function Helpers:SetPath(
    root,
    path,
    value
)
    if type(root) ~= "table"
        or type(path) ~= "string" then

        return false
    end

    local parts =
        self:SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current = root

    for index = 1, #parts - 1 do
        local part =
            parts[index]

        if type(current[part])
            ~= "table" then

            current[part] = {}
        end

        current =
            current[part]
    end

    current[
        parts[#parts]
    ] = value

    return true
end



-- Initialization


function Helpers:Initialize()
    if self.Initialized then
        return self
    end

    self.Initialized = true

    return self
end



-- Destroy


function Helpers:Destroy()
    self.Initialized = false
end


return Helpers