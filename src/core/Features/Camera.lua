local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraFeature = {
    Name = "Camera",
    Version = "1.0.0",

    Description = "Spectate and free camera mode",
    Category = "Camera",
    Dependencies = {},

    Enabled = false,
    Initialized = false,
    Running = false,

    Camera = nil,
    LocalPlayer = nil,

    Connections = {},

    Original = {
        CameraType = nil,
        CFrame = nil,
        FOV = nil,
    },

    Settings = {
        Enabled = true,
        FreeCam = false,
        Spectate = true,
        Speed = 60,
        VerticalSpeed = 40,
        Sensitivity = 0.75,
        FOV = 70,
        Collision = false,
        Distance = 10,
        Height = 2,
        Smoothness = 0.2,
        TargetName = nil,
        Target = nil,
    },

    State = {
        Position = Vector3.new(0, 5, 10),
        Yaw = 0,
        Pitch = 0,
        Spectating = false,
        Locked = false,
    },
}

local function Disconnect(connection)
    if connection and typeof(connection) == "RBXScriptConnection" then
        pcall(function()
            connection:Disconnect()
        end)
    end
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result = pcall(callback, ...)
    if not success then
        warn("[Camera]", result)
        return false, result
    end

    return true, result
end

local function ClampNumber(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.clamp(value, minimum, maximum)
end

function CameraFeature:GetCamera()
    if self.Camera then
        return self.Camera
    end

    self.Camera = Workspace.CurrentCamera
    return self.Camera
end

function CameraFeature:GetLocalPlayer()
    if self.LocalPlayer then
        return self.LocalPlayer
    end

    self.LocalPlayer = PlayersService.LocalPlayer
    return self.LocalPlayer
end

function CameraFeature:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config and type(self.Config.Get) == "function" then
        local success, value = pcall(function()
            return self.Config:Get("Camera." .. name, default)
        end)

        if success then
            return value
        end
    end

    return default
end

function CameraFeature:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value
    return true
end

function CameraFeature:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules = modules or {}
    self.Config = modules.Config
    self.Camera = Workspace.CurrentCamera
    self.LocalPlayer = PlayersService.LocalPlayer
    self.Initialized = true

    return self
end

function CameraFeature:SaveCameraState()
    local camera = self:GetCamera()
    if not camera then
        return
    end

    self.Original.CameraType = camera.CameraType
    self.Original.CFrame = camera.CFrame
    self.Original.FOV = camera.FieldOfView
end

function CameraFeature:RestoreCameraState()
    local camera = self:GetCamera()
    if not camera then
        return
    end

    if self.Original.CameraType ~= nil then
        camera.CameraType = self.Original.CameraType
    end

    if self.Original.CFrame ~= nil then
        camera.CFrame = self.Original.CFrame
    end

    if self.Original.FOV ~= nil then
        camera.FieldOfView = self.Original.FOV
    end
end

function CameraFeature:GetSpectateTarget()
    local player = self:GetLocalPlayer()
    if not player then
        return nil
    end

    local target = self.Settings.Target
    if target and target.Parent and target ~= player then
        return target
    end

    local candidates = {}
    for _, otherPlayer in ipairs(PlayersService:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            if character then
                local root = character:FindFirstChild("HumanoidRootPart")
                if root and (otherPlayer.Character and otherPlayer.Character:FindFirstChildOfClass("Humanoid") and otherPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0) then
                    table.insert(candidates, otherPlayer)
                end
            end
        end
    end

    if #candidates == 0 then
        return nil
    end

    local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local nearest = candidates[1]
    local nearestDistance = math.huge

    for _, candidate in ipairs(candidates) do
        local candidateRoot = candidate.Character and candidate.Character:FindFirstChild("HumanoidRootPart")
        if candidateRoot then
            local distance = localRoot and (candidateRoot.Position - localRoot.Position).Magnitude or math.huge
            if distance < nearestDistance then
                nearestDistance = distance
                nearest = candidate
            end
        end
    end

    self.Settings.Target = nearest
    self.State.Target = nearest
    return nearest
end

function CameraFeature:UpdateSpectate(dt)
    local camera = self:GetCamera()
    if not camera then
        return
    end

    local targetPlayer = self:GetSpectateTarget()
    if not targetPlayer then
        self.State.Spectating = false
        return
    end

    local targetCharacter = targetPlayer.Character
    if not targetCharacter then
        return
    end

    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        return
    end

    local targetPosition = targetRoot.Position
    local offset = Vector3.new(0, 2.5, 0)
    local lookOffset = Vector3.new(0, 1.5, 0)
    local desiredCFrame = CFrame.new(targetPosition + offset, targetPosition + lookOffset)
    local currentCFrame = camera.CFrame

    camera.CFrame = currentCFrame:Lerp(desiredCFrame, math.clamp(dt * 8, 0, 1))
    camera.FieldOfView = self:GetSetting("FOV", 70)
end

function CameraFeature:UpdateFreeCam(dt)
    local camera = self:GetCamera()
    if not camera then
        return
    end

    local moveSpeed = self:GetSetting("Speed", 60)
    local verticalSpeed = self:GetSetting("VerticalSpeed", 40)
    local sensitivity = self:GetSetting("Sensitivity", 0.75)

    local delta = UserInputService:GetMouseDelta()
    self.State.Yaw = self.State.Yaw - delta.X * 0.0025 * sensitivity
    self.State.Pitch = math.clamp(self.State.Pitch - delta.Y * 0.002 * sensitivity, -1.55, 1.55)

    local forward = Vector3.new(math.cos(self.State.Yaw), 0, math.sin(self.State.Yaw))
    local right = Vector3.new(math.cos(self.State.Yaw - math.pi / 2), 0, math.sin(self.State.Yaw - math.pi / 2))
    local up = Vector3.new(0, 1, 0)

    local inputVector = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        inputVector += forward
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        inputVector -= forward
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        inputVector -= right
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        inputVector += right
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        inputVector += up
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        inputVector -= up
    end

    if inputVector.Magnitude > 0 then
        local direction = inputVector.Unit
        local velocity = direction * (moveSpeed * dt)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            velocity = direction * (verticalSpeed * dt)
        end
        self.State.Position += velocity
    end

    local look = Vector3.new(
        math.cos(self.State.Pitch) * math.sin(self.State.Yaw),
        math.sin(self.State.Pitch),
        math.cos(self.State.Pitch) * math.cos(self.State.Yaw)
    )

    local lookAt = self.State.Position + look
    camera.CFrame = CFrame.new(self.State.Position, lookAt)
    camera.FieldOfView = self:GetSetting("FOV", 70)
end

function CameraFeature:Update(dt)
    if not self.Running then
        return
    end

    local camera = self:GetCamera()
    if not camera then
        return
    end

    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = self:GetSetting("FOV", 70)

    if self:GetSetting("FreeCam", false) then
        self:UpdateFreeCam(dt)
        return
    end

    if self:GetSetting("Spectate", true) then
        self:UpdateSpectate(dt)
    end
end

function CameraFeature:Start()
    if self.Running then
        return true
    end

    self:SaveCameraState()
    self.Camera = Workspace.CurrentCamera
    self.LocalPlayer = PlayersService.LocalPlayer

    self.Enabled = true
    self.Running = true

    if self.Camera then
        self.Camera.CameraType = Enum.CameraType.Scriptable
        self.State.Position = self.Camera.CFrame.Position
        self.State.Yaw = math.atan2(self.Camera.CFrame.LookVector.X, self.Camera.CFrame.LookVector.Z)
        self.State.Pitch = math.asin(self.Camera.CFrame.LookVector.Y)
    end

    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        SafeCall(function()
            self:Update(dt)
        end)
    end))

    return true
end

function CameraFeature:Stop()
    self.Enabled = false
    self.Running = false
    self.Settings.FreeCam = false

    for _, connection in ipairs(self.Connections) do
        Disconnect(connection)
    end
    self.Connections = {}

    self:RestoreCameraState()
    return true
end

function CameraFeature:SetEnabled(enabled)
    enabled = enabled == true
    self.Settings.Enabled = enabled
    if enabled then
        self:Start()
    else
        self:Stop()
    end
    return self.Enabled
end

function CameraFeature:Toggle()
    return self:SetEnabled(not self.Enabled)
end

function CameraFeature:SetFreeCam(enabled)
    self.Settings.FreeCam = enabled == true
    if enabled == true then
        self.Settings.Spectate = false
        self.State.Spectating = false
    end
    return self.Settings.FreeCam
end

function CameraFeature:SetSpectate(enabled)
    self.Settings.Spectate = enabled == true
    if enabled == true then
        self.Settings.FreeCam = false
    end
    return self.Settings.Spectate
end

function CameraFeature:GetState()
    return {
        Running = self.Running,
        FreeCam = self:GetSetting("FreeCam", false),
        Spectate = self:GetSetting("Spectate", true),
        Position = self.State.Position,
        Target = self.Settings.Target,
    }
end

return CameraFeature
