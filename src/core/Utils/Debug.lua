local Debug = {
    Name = "Debug",
    Version = "1.0.0",
    Enabled = true,
    Level = "Info",
    History = {},
    MaxHistory = 150,
}

local function NormalizeLevel(level)
    if type(level) ~= "string" then
        return "Info"
    end

    local normalized = string.lower(level)
    if normalized == "debug" then
        return "Debug"
    end
    if normalized == "warn" or normalized == "warning" then
        return "Warn"
    end
    if normalized == "error" then
        return "Error"
    end
    return "Info"
end

local function FormatMessage(level, message, ...)
    local parts = {"[LuaTest]"}
    if level then
        table.insert(parts, "[" .. tostring(level) .. "]")
    end
    table.insert(parts, tostring(message or ""))

    local extra = { ... }
    for _, value in ipairs(extra) do
        table.insert(parts, tostring(value))
    end

    return table.concat(parts, " ")
end

local function PushHistory(level, text)
    table.insert(Debug.History, {
        Level = level,
        Text = text,
        Time = os.clock and os.clock() or 0,
    })

    if #Debug.History > Debug.MaxHistory then
        table.remove(Debug.History, 1)
    end
end

function Debug:SetEnabled(value)
    self.Enabled = value == true
    return self.Enabled
end

function Debug:IsEnabled()
    return self.Enabled == true
end

function Debug:SetLevel(level)
    self.Level = NormalizeLevel(level)
    return self.Level
end

function Debug:GetHistory()
    return self.History
end

function Debug:Print(level, message, ...)
    if not self.Enabled then
        return false
    end

    local normalized = NormalizeLevel(level)
    local text = FormatMessage(normalized, message, ...)
    PushHistory(normalized, text)
    print(text)
    return true
end

function Debug:Log(message, ...)
    return self:Print("Info", message, ...)
end

function Debug:Info(message, ...)
    return self:Print("Info", message, ...)
end

function Debug:Warn(message, ...)
    return self:Print("Warn", message, ...)
end

function Debug:Error(message, ...)
    return self:Print("Error", message, ...)
end

function Debug:Dump(label, value)
    if not self.Enabled then
        return false
    end

    local text = FormatMessage("Debug", label or "Dump", value)
    PushHistory("Debug", text)
    print(text)
    return true
end

function Debug:Toggle()
    self.Enabled = not self.Enabled
    return self.Enabled
end

function Debug:Clear()
    self.History = {}
    return true
end

function Debug:Start()
    self.Enabled = true
    return true
end

function Debug:Stop()
    self.Enabled = false
    return true
end

function Debug:Destroy()
    self.History = {}
    self.Enabled = false
    return true
end

return Debug
