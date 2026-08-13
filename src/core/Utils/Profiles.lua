local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Profiles = {
    Name = "Profiles",
    Version = "1.0.0",
    Initialized = false,
    Running = false,
    FolderName = "LuaTestProfiles",
    Profiles = {},
    StorageRoot = nil,
}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, child in pairs(value) do
        copy[key] = DeepCopy(child, seen)
    end

    return copy
end

local function GetStorageRoot()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local folder = playerGui:FindFirstChild(Profiles.FolderName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = Profiles.FolderName
        folder.Parent = playerGui
    end

    return folder
end

local function SafeJSONEncode(value)
    if not HttpService or not HttpService.JSONEncode then
        return nil
    end

    local success, encoded = pcall(function()
        return HttpService:JSONEncode(value)
    end)

    if success then
        return encoded
    end

    return nil
end

local function SafeJSONDecode(value)
    if not HttpService or not HttpService.JSONDecode then
        return nil
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(value)
    end)

    if success then
        return decoded
    end

    return nil
end

function Profiles:Initialize()
    if self.Initialized then
        return true
    end

    self.StorageRoot = GetStorageRoot()
    self.Initialized = true
    self.Running = true

    return true
end

function Profiles:EnsureFolder()
    self:Initialize()

    if not self.StorageRoot then
        self.StorageRoot = GetStorageRoot()
    end

    return self.StorageRoot
end

function Profiles:GetNames()
    local folder = self:EnsureFolder()
    if not folder then
        return {}
    end

    local names = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("StringValue") then
            table.insert(names, child.Name)
        end
    end

    table.sort(names)
    return names
end

function Profiles:Save(name, data)
    if type(name) ~= "string" or name == "" then
        return false, "Profile name is required"
    end

    local folder = self:EnsureFolder()
    if not folder then
        return false, "Unable to access profile storage"
    end

    local profileName = tostring(name)
    local encoded = SafeJSONEncode(data or {})
    if not encoded then
        return false, "Profile encoding failed"
    end

    local value = folder:FindFirstChild(profileName)
    if not value then
        value = Instance.new("StringValue")
        value.Name = profileName
        value.Parent = folder
    end

    value.Value = encoded
    self.Profiles[profileName] = DeepCopy(data or {})
    return true, profileName
end

function Profiles:Load(name, default)
    if type(name) ~= "string" or name == "" then
        return default
    end

    local folder = self:EnsureFolder()
    if not folder then
        return default
    end

    local value = folder:FindFirstChild(tostring(name))
    if not value or type(value.Value) ~= "string" then
        if self.Profiles[name] ~= nil then
            return DeepCopy(self.Profiles[name])
        end

        return default
    end

    local decoded = SafeJSONDecode(value.Value)
    if type(decoded) == "table" then
        self.Profiles[name] = DeepCopy(decoded)
        return DeepCopy(decoded)
    end

    return default
end

function Profiles:Delete(name)
    if type(name) ~= "string" or name == "" then
        return false
    end

    local folder = self:EnsureFolder()
    if not folder then
        return false
    end

    local profile = folder:FindFirstChild(tostring(name))
    if profile then
        profile:Destroy()
    end

    self.Profiles[name] = nil
    return true
end

function Profiles:Reset()
    local folder = self:EnsureFolder()
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("StringValue") then
                child:Destroy()
            end
        end
    end

    self.Profiles = {}
    return true
end

function Profiles:Get(name, default)
    return self:Load(name, default)
end

function Profiles:Set(name, value)
    return self:Save(name, value)
end

function Profiles:Export(name)
    return self:Load(name, {})
end

function Profiles:Import(name, data)
    return self:Save(name, data)
end

function Profiles:Start()
    self:Initialize()
    self.Running = true
    return true
end

function Profiles:Stop()
    self.Running = false
    return true
end

function Profiles:Destroy()
    self:Stop()
    self.Profiles = {}
    self.StorageRoot = nil
    self.Initialized = false
    return true
end

return Profiles
