local Config = {}

Config.__index = Config


-- Metadata


Config.Name = "Config"
Config.Version = "2.0.0"

Config.Initialized = false
Config.Locked = false

Config.Values = {}
Config.Defaults = {}

Config.Changed = {}
Config.History = {}

Config.MaxHistory = 100


-- Defaults


Config.Defaults = {

    -- ========================================================
    -- General
    -- ========================================================

    General = {
        Enabled = true,
        Notifications = true,
        Debug = false,
    },

    -- ========================================================
    -- ESP
    -- ========================================================

    ESP = {
        Enabled = false,

        Box = true,
        BoxStyle = "Corner",

        Name = true,
        Distance = true,

        HealthBar = true,
        HealthText = false,

        Tracer = false,

        Highlight = false,

        TeamCheck = false,

        MaxDistance = 1000,

        RefreshRate = 30,
    },

    -- ========================================================
    -- Movement
    -- ========================================================

    Movement = {
        Enabled = false,

        WalkSpeedEnabled = false,
        WalkSpeed = 16,

        JumpPowerEnabled = false,
        JumpPower = 50,

        JumpHeightEnabled = false,
        JumpHeight = 7.2,

        HipHeightEnabled = false,
        HipHeight = 2,

        AutoRotateEnabled = true,

        RestoreOnDisable = true,
    },

    -- ========================================================
    -- Teleports
    -- ========================================================

    Teleports = {
        Enabled = true,

        OffsetDistance = 4,
    },

    -- ========================================================
    -- Game Features
    -- ========================================================

    GameFeatures = {
        Enabled = false,

        CameraFOVEnabled = false,
        CameraFOV = 70,

        Fullbright = false,

        ReduceVisualEffects = false,

        AutoRespawnTracking = true,
        KeepCharacterReady = true,

        UpdateRate = 30,
    },

    -- ========================================================
    -- UI
    -- ========================================================

    UI = {
        Enabled = true,

        Theme = "Default",

        Notifications = true,

        ShowFeatureStatus = true,

        ToggleKey = Enum.KeyCode.RightShift,
    },
}


-- Helpers


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
        copy[
            DeepCopy(key, seen)
        ] = DeepCopy(child, seen)
    end

    return copy
end

local function DeepMerge(original, incoming)
    local result = DeepCopy(original)

    if type(incoming) ~= "table" then
        return result
    end

    for key, value in pairs(incoming) do

        if type(value) == "table"
            and type(result[key]) == "table" then

            result[key] =
                DeepMerge(
                    result[key],
                    value
                )

        else
            result[key] =
                DeepCopy(value)
        end
    end

    return result
end

local function SplitPath(path)
    local parts = {}

    if type(path) ~= "string" then
        return parts
    end

    for part in string.gmatch(
        path,
        "[^%.]+"
    ) do

        table.insert(
            parts,
            part
        )
    end

    return parts
end

local function JoinPath(parts)
    return table.concat(parts, ".")
end

local function GetPathFromTable(root, path)
    local parts =
        SplitPath(path)

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

local function SetPathInTable(root, path, value)
    local parts =
        SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current = root

    for index = 1, #parts - 1 do

        local part =
            parts[index]

        if type(current[part]) ~= "table" then
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

local function RemovePathFromTable(root, path)
    local parts =
        SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current = root

    for index = 1, #parts - 1 do

        local part =
            parts[index]

        if type(current) ~= "table"
            or current[part] == nil then

            return false
        end

        current =
            current[part]
    end

    local finalKey =
        parts[#parts]

    if current[finalKey] == nil then
        return false
    end

    current[finalKey] = nil

    return true
end

local function ValuesEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    for key, value in pairs(a) do
        if not ValuesEqual(
            value,
            b[key]
        ) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end


-- Internal Events


function Config:_FireChanged(
    path,
    newValue,
    oldValue
)
    local listeners =
        self.Changed[path]

    if not listeners then
        return
    end

    for _, callback in ipairs(listeners) do

        if type(callback) == "function" then

            task.spawn(
                function()

                    local success, err =
                        pcall(
                            callback,
                            newValue,
                            oldValue,
                            path
                        )

                    if not success
                        and self:Get(
                            "General.Debug",
                            false
                        ) then

                        warn(
                            "[Config] Change callback error:",
                            err
                        )
                    end

                end
            )

        end
    end
end

function Config:_RecordHistory(
    path,
    newValue,
    oldValue
)
    table.insert(
        self.History,
        {
            Path = path,

            NewValue =
                DeepCopy(newValue),

            OldValue =
                DeepCopy(oldValue),

            Time = os.clock(),
        }
    )

    while #self.History >
        self.MaxHistory do

        table.remove(
            self.History,
            1
        )
    end
end


-- Initialize


function Config:Initialize(initialValues)
    if self.Initialized then
        return self
    end

    self.Values =
        DeepCopy(
            self.Defaults
        )

    self.History = {}

    if type(initialValues) == "table" then
        self.Values =
            DeepMerge(
                self.Values,
                initialValues
            )
    end

    self.Initialized = true
    self.Locked = false

    return self
end


-- Ensure


function Config:_EnsureInitialized()
    if not self.Initialized then
        self:Initialize()
    end
end


-- Get


function Config:Get(path, default)
    self:_EnsureInitialized()

    local value =
        GetPathFromTable(
            self.Values,
            path
        )

    if value == nil then
        return default
    end

    return value
end


-- Get Raw


function Config:GetRaw(path)
    self:_EnsureInitialized()

    return GetPathFromTable(
        self.Values,
        path
    )
end


-- Set


function Config:Set(path, value)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    local oldValue =
        self:GetRaw(path)

    if ValuesEqual(
        oldValue,
        value
    ) then

        return true
    end

    local success =
        SetPathInTable(
            self.Values,
            path,
            DeepCopy(value)
        )

    if not success then
        return false, "Invalid path"
    end

    self:_RecordHistory(
        path,
        value,
        oldValue
    )

    self:_FireChanged(
        path,
        value,
        oldValue
    )

    return true
end


-- Set Multiple


function Config:SetMany(values)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    if type(values) ~= "table" then
        return false, "Values must be a table"
    end

    local changed = 0

    for path, value in pairs(values) do

        local success =
            self:Set(
                path,
                value
            )

        if success then
            changed += 1
        end
    end

    return true, changed
end


-- Has


function Config:Has(path)
    self:_EnsureInitialized()

    return GetPathFromTable(
        self.Values,
        path
    ) ~= nil
end


-- Remove


function Config:Remove(path)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    local oldValue =
        self:GetRaw(path)

    if oldValue == nil then
        return false
    end

    local success =
        RemovePathFromTable(
            self.Values,
            path
        )

    if not success then
        return false
    end

    self:_RecordHistory(
        path,
        nil,
        oldValue
    )

    self:_FireChanged(
        path,
        nil,
        oldValue
    )

    return true
end


-- Defaults


function Config:GetDefault(path)
    return GetPathFromTable(
        self.Defaults,
        path
    )
end

function Config:GetDefaults()
    return DeepCopy(
        self.Defaults
    )
end


-- Reset


function Config:Reset(path)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    if not path then

        self.Values =
            DeepCopy(
                self.Defaults
            )

        table.insert(
            self.History,
            {
                Path = "*",
                NewValue =
                    DeepCopy(
                        self.Values
                    ),
                OldValue = nil,
                Time = os.clock(),
            }
        )

        return true
    end

    local defaultValue =
        self:GetDefault(path)

    if defaultValue == nil then
        return false, "No default exists"
    end

    return self:Set(
        path,
        DeepCopy(
            defaultValue
        )
    )
end


-- Reset Section


function Config:ResetSection(section)
    if type(section) ~= "string" then
        return false
    end

    return self:Reset(section)
end

function Config:ResetAll()
    return self:Reset()
end


-- Sections


function Config:GetSection(name)
    local section =
        self:Get(name)

    if type(section) ~= "table" then
        return nil
    end

    return DeepCopy(section)
end

function Config:SetSection(name, values)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    if type(name) ~= "string"
        or type(values) ~= "table" then

        return false
    end

    local oldValue =
        self:GetRaw(name)

    self.Values[name] =
        DeepCopy(values)

    self:_RecordHistory(
        name,
        values,
        oldValue
    )

    self:_FireChanged(
        name,
        values,
        oldValue
    )

    return true
end


-- Feature Helpers


function Config:IsFeatureEnabled(
    featureName
)
    return self:Get(
        featureName .. ".Enabled",
        false
    ) == true
end

function Config:SetFeatureEnabled(
    featureName,
    enabled
)
    return self:Set(
        featureName .. ".Enabled",
        enabled == true
    )
end

function Config:Toggle(featureName)
    local current =
        self:IsFeatureEnabled(
            featureName
        )

    return self:SetFeatureEnabled(
        featureName,
        not current
    )
end


-- Increment


function Config:Increment(
    path,
    amount
)
    amount = amount or 1

    local current =
        self:Get(
            path,
            0
        )

    if type(current) ~= "number"
        or type(amount) ~= "number" then

        return false
    end

    return self:Set(
        path,
        current + amount
    )
end


-- Change Listeners


function Config:OnChanged(
    path,
    callback
)
    if type(path) ~= "string"
        or type(callback) ~= "function" then

        return function() end
    end

    self.Changed[path] =
        self.Changed[path]
        or {}

    table.insert(
        self.Changed[path],
        callback
    )

    local removed = false

    return function()

        if removed then
            return
        end

        removed = true

        local listeners =
            self.Changed[path]

        if not listeners then
            return
        end

        for index, listener
            in ipairs(listeners) do

            if listener == callback then

                table.remove(
                    listeners,
                    index
                )

                break
            end
        end

        if #listeners == 0 then
            self.Changed[path] = nil
        end
    end
end


-- Global Change Listener


function Config:OnAnyChanged(callback)
    return self:OnChanged(
        "*",
        callback
    )
end

-- Override event firing for global listeners
local OriginalFireChanged =
    Config._FireChanged

function Config:_FireChanged(
    path,
    newValue,
    oldValue
)
    OriginalFireChanged(
        self,
        path,
        newValue,
        oldValue
    )

    local listeners =
        self.Changed["*"]

    if not listeners then
        return
    end

    for _, callback in ipairs(listeners) do

        if type(callback) == "function" then

            task.spawn(
                function()

                    pcall(
                        callback,
                        newValue,
                        oldValue,
                        path
                    )

                end
            )

        end
    end
end


-- Lock


function Config:Lock()
    self.Locked = true

    return self
end

function Config:Unlock()
    self.Locked = false

    return self
end

function Config:IsLocked()
    return self.Locked == true
end


-- Snapshot


function Config:Snapshot()
    self:_EnsureInitialized()

    return DeepCopy(
        self.Values
    )
end

function Config:Restore(snapshot)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    if type(snapshot) ~= "table" then
        return false, "Invalid snapshot"
    end

    self.Values =
        DeepCopy(snapshot)

    return true
end


-- Import / Export


function Config:Export()
    self:_EnsureInitialized()

    return DeepCopy(
        self.Values
    )
end

function Config:Import(values, merge)
    self:_EnsureInitialized()

    if self.Locked then
        return false, "Config is locked"
    end

    if type(values) ~= "table" then
        return false, "Values must be a table"
    end

    if merge then

        self.Values =
            DeepMerge(
                self.Values,
                values
            )

    else

        self.Values =
            DeepCopy(values)

    end

    return true
end


-- Compare


function Config:IsDefault(path)
    local current =
        self:GetRaw(path)

    local default =
        self:GetDefault(path)

    return ValuesEqual(
        current,
        default
    )
end

function Config:Diff()
    self:_EnsureInitialized()

    local differences = {}

    local function compare(
        current,
        defaults,
        prefix
    )
        if type(defaults) ~= "table" then

            if not ValuesEqual(
                current,
                defaults
            ) then

                differences[prefix] = {
                    Current =
                        DeepCopy(current),

                    Default =
                        DeepCopy(defaults),
                }

            end

            return
        end

        for key, defaultValue
            in pairs(defaults) do

            local currentValue =
                current
                and current[key]

            local path

            if prefix == "" then
                path =
                    tostring(key)
            else
                path =
                    prefix
                    .. "."
                    .. tostring(key)
            end

            compare(
                currentValue,
                defaultValue,
                path
            )
        end
    end

    compare(
        self.Values,
        self.Defaults,
        ""
    )

    return differences
end


-- Validation


function Config:Validate()
    self:_EnsureInitialized()

    local errors = {}

    -- ESP

    local maxDistance =
        self:Get(
            "ESP.MaxDistance"
        )

    if type(maxDistance) ~= "number"
        or maxDistance < 0 then

        table.insert(
            errors,
            "ESP.MaxDistance must be >= 0"
        )
    end

    local refreshRate =
        self:Get(
            "ESP.RefreshRate"
        )

    if type(refreshRate) ~= "number"
        or refreshRate <= 0 then

        table.insert(
            errors,
            "ESP.RefreshRate must be > 0"
        )
    end

    local boxStyle =
        self:Get(
            "ESP.BoxStyle"
        )

    if type(boxStyle) ~= "string" then

        table.insert(
            errors,
            "ESP.BoxStyle must be a string"
        )
    end

    -- Movement

    local walkSpeed =
        self:Get(
            "Movement.WalkSpeed"
        )

    if type(walkSpeed) ~= "number"
        or walkSpeed < 0 then

        table.insert(
            errors,
            "Movement.WalkSpeed must be >= 0"
        )
    end

    local jumpPower =
        self:Get(
            "Movement.JumpPower"
        )

    if type(jumpPower) ~= "number"
        or jumpPower < 0 then

        table.insert(
            errors,
            "Movement.JumpPower must be >= 0"
        )
    end

    local jumpHeight =
        self:Get(
            "Movement.JumpHeight"
        )

    if type(jumpHeight) ~= "number"
        or jumpHeight < 0 then

        table.insert(
            errors,
            "Movement.JumpHeight must be >= 0"
        )
    end

    -- Teleports

    local offset =
        self:Get(
            "Teleports.OffsetDistance"
        )

    if type(offset) ~= "number"
        or offset < 0 then

        table.insert(
            errors,
            "Teleports.OffsetDistance must be >= 0"
        )
    end

    -- FOV

    local fov =
        self:Get(
            "GameFeatures.CameraFOV"
        )

    if type(fov) ~= "number"
        or fov < 1
        or fov > 120 then

        table.insert(
            errors,
            "GameFeatures.CameraFOV must be between 1 and 120"
        )
    end

    -- Update rate

    local updateRate =
        self:Get(
            "GameFeatures.UpdateRate"
        )

    if type(updateRate) ~= "number"
        or updateRate <= 0 then

        table.insert(
            errors,
            "GameFeatures.UpdateRate must be > 0"
        )
    end

    return #errors == 0,
        errors
end


-- History


function Config:GetHistory()
    return DeepCopy(
        self.History
    )
end

function Config:ClearHistory()
    self.History = {}

    return self
end


-- Clone


function Config:Clone()
    local clone =
        setmetatable(
            {
                Name = self.Name,

                Version = self.Version,

                Initialized = self.Initialized,

                Locked = false,

                Values =
                    DeepCopy(
                        self.Values
                    ),

                Defaults =
                    DeepCopy(
                        self.Defaults
                    ),

                Changed = {},

                History = {},

                MaxHistory =
                    self.MaxHistory,
            },
            Config
        )

    return clone
end


-- Get Everything


function Config:GetAll()
    self:_EnsureInitialized()

    return DeepCopy(
        self.Values
    )
end


-- Set Max History


function Config:SetMaxHistory(amount)
    if type(amount) ~= "number"
        or amount < 0 then

        return false
    end

    self.MaxHistory =
        math.floor(amount)

    while #self.History >
        self.MaxHistory do

        table.remove(
            self.History,
            1
        )
    end

    return true
end


-- Destroy


function Config:Destroy()
    self.Values = {}

    self.Changed = {}

    self.History = {}

    self.Initialized = false
    self.Locked = false
end

return Config