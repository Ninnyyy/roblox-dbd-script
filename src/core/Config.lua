local Config = {
    Name = "Config",
    Version = "2.0.0",

    Initialized = false,

    Values = {},

    Defaults = {
        -- =====================================================
        -- General
        -- =====================================================

        General = {
            Enabled = true,
            Notifications = true,
            Debug = false,
        },

        -- =====================================================
        -- ESP
        -- =====================================================

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

        -- =====================================================
        -- Movement
        -- =====================================================

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

        -- =====================================================
        -- Teleports
        -- =====================================================

        Teleports = {
            Enabled = true,

            OffsetDistance = 4,
        },

        -- =====================================================
        -- Game Features
        -- =====================================================

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

        -- =====================================================
        -- UI
        -- =====================================================

        UI = {
            Enabled = true,

            Theme = "Default",

            Notifications = true,

            ShowFeatureStatus = true,

            ToggleKey = Enum.KeyCode.RightShift,
        },
    },
}


-- Internal helpers


local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[key] = DeepCopy(child)
    end

    return copy
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


-- Initialization


function Config:Initialize()
    if self.Initialized then
        return self
    end

    self.Values =
        DeepCopy(self.Defaults)

    self.Initialized = true

    return self
end


-- Get


function Config:Get(path, default)
    if not self.Initialized then
        self:Initialize()
    end

    local parts =
        SplitPath(path)

    if #parts == 0 then
        return default
    end

    local current =
        self.Values

    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return default
        end

        current =
            current[part]

        if current == nil then
            return default
        end
    end

    return current
end


-- Set


function Config:Set(path, value)
    if not self.Initialized then
        self:Initialize()
    end

    local parts =
        SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current =
        self.Values

    for index = 1, #parts - 1 do
        local part =
            parts[index]

        if type(current[part]) ~= "table" then
            current[part] = {}
        end

        current =
            current[part]
    end

    current[parts[#parts]] =
        value

    return true
end


-- Exists


function Config:Has(path)
    return self:Get(
        path,
        nil
    ) ~= nil
end


-- Remove


function Config:Remove(path)
    local parts =
        SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current =
        self.Values

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


-- Reset


function Config:Reset(path)
    if not path then
        self.Values =
            DeepCopy(
                self.Defaults
            )

        return true
    end

    local defaultValue =
        self:GetDefault(path)

    if defaultValue == nil then
        return false
    end

    return self:Set(
        path,
        DeepCopy(
            defaultValue
        )
    )
end


-- Defaults


function Config:GetDefault(path)
    local parts =
        SplitPath(path)

    if #parts == 0 then
        return nil
    end

    local current =
        self.Defaults

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


-- Sections


function Config:GetSection(name)
    local section =
        self:Get(name)

    if type(section) ~= "table" then
        return nil
    end

    return section
end

function Config:SetSection(
    name,
    values
)
    if type(name) ~= "string"
        or type(values) ~= "table" then

        return false
    end

    self.Values[name] =
        DeepCopy(values)

    return true
end

function Config:GetAll()
    return DeepCopy(
        self.Values
    )
end

function Config:GetDefaults()
    return DeepCopy(
        self.Defaults
    )
end


-- Feature helpers


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


-- Validation


function Config:Validate()
    if not self.Initialized then
        self:Initialize()
    end

    local errors = {}

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

    return #errors == 0,
        errors
end


-- Utility


function Config:Clone()
    local clone = {
        Name = self.Name,
        Version = self.Version,
        Initialized = true,

        Defaults =
            DeepCopy(
                self.Defaults
            ),

        Values =
            DeepCopy(
                self.Values
            ),
    }

    setmetatable(
        clone,
        {
            __index = self,
        }
    )

    return clone
end


-- Destroy


function Config:Destroy()
    self.Values = {}
    self.Initialized = false
end

return Config