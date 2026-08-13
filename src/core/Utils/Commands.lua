local Commands = {
    Name = "Commands",
    Version = "1.0.0",
    Bindings = {},
    Aliases = {},
    History = {},
    Enabled = true,
}

local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = name:match("^%s*(.-)%s*$")
    if normalized == nil then
        normalized = name
    end

    normalized = string.lower(normalized)
    if normalized == "" then
        return nil
    end

    return normalized
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, "Callback is not a function"
    end

    local success, result = pcall(callback, ...)
    if not success then
        return false, result
    end

    return true, result
end

function Commands:SetEnabled(value)
    self.Enabled = value == true
    return self.Enabled
end

function Commands:IsEnabled()
    return self.Enabled == true
end

function Commands:Register(name, callback, description)
    local normalized = NormalizeName(name)
    if not normalized or type(callback) ~= "function" then
        return false, "Invalid command registration"
    end

    self.Bindings[normalized] = {
        Name = normalized,
        Description = description or "",
        Callback = callback,
    }

    table.insert(self.History, {
        Type = "Register",
        Name = normalized,
        Description = description or "",
    })

    return true, normalized
end

function Commands:Unregister(name)
    local normalized = NormalizeName(name)
    if not normalized then
        return false
    end

    self.Bindings[normalized] = nil
    return true
end

function Commands:RegisterAlias(name, alias)
    local commandName = NormalizeName(name)
    local aliasName = NormalizeName(alias)

    if not commandName or not aliasName then
        return false, "Invalid alias registration"
    end

    self.Aliases[aliasName] = commandName
    return true, aliasName
end

function Commands:RemoveAlias(name)
    local aliasName = NormalizeName(name)
    if not aliasName then
        return false
    end

    self.Aliases[aliasName] = nil
    return true
end

function Commands:Execute(name, ...)
    if not self.Enabled then
        return false, "Commands are disabled"
    end

    local normalized = NormalizeName(name)
    if not normalized then
        return false, "Command name is invalid"
    end

    local targetName = self.Aliases[normalized] or normalized
    local binding = self.Bindings[targetName]
    if not binding then
        return false, "Command not found: " .. tostring(normalized)
    end

    table.insert(self.History, {
        Type = "Execute",
        Name = targetName,
    })

    return SafeCall(binding.Callback, ...)
end

function Commands:HandleText(input, ...)
    if type(input) ~= "string" then
        return false, "Input must be a string"
    end

    local trimmed = input:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return false, "No command entered"
    end

    local commandText, argumentsText = trimmed:match("^([^%s]+)%s*(.*)$")
    if not commandText then
        return false, "Unable to parse command"
    end

    local args = {}
    if argumentsText and argumentsText ~= "" then
        for part in string.gmatch(argumentsText, "[^%s]+") do
            table.insert(args, part)
        end
    end

    if ... then
        table.insert(args, ...)
    end

    return self:Execute(commandText, table.unpack(args))
end

function Commands:GetCommands()
    local list = {}
    for name, binding in pairs(self.Bindings) do
        table.insert(list, {
            Name = binding.Name,
            Description = binding.Description,
        })
    end

    table.sort(list, function(a, b)
        return a.Name < b.Name
    end)

    return list
end

function Commands:ClearHistory()
    self.History = {}
    return true
end

function Commands:Start()
    self.Enabled = true
    return true
end

function Commands:Stop()
    self.Enabled = false
    return true
end

function Commands:Destroy()
    self.Bindings = {}
    self.Aliases = {}
    self.History = {}
    self.Enabled = false
    return true
end

return Commands
