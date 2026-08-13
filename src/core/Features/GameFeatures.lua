--[[
    Lua Test Script
    GameFeatures.lua

    General gameplay-feature manager.

    This module is intentionally modular:
        - Movement settings
        - WalkSpeed / JumpPower helpers
        - Gravity helpers
        - Infinite-jump style input handling
        - No-clip state management
        - Flight state management
        - Character utility functions
        - Respawn-aware character binding
        - Safe start/stop lifecycle
        - Config integration
        - Cleanup integration

    NOTE:
        Features are kept disabled by default.
]]

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameFeatures = {
    Name = "GameFeatures",

    Enabled = false,
    Running = false,
    Initialized = false,

    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    LocalPlayer = nil,

    CharacterModel = nil,
    Humanoid = nil,
    RootPart = nil,

    Connections = {},

    Original = {
        WalkSpeed = nil,
        JumpPower = nil,
        JumpHeight = nil,
        AutoRotate = nil,
        Gravity = nil,
    },

    Settings = {
        Enabled = true,

        -- Movement
        WalkSpeed = 16,
        JumpPower = 50,
        JumpHeight = 7.2,

        -- Movement toggles
        SpeedEnabled = false,
        JumpEnabled = false,

        -- Gravity
        GravityEnabled = false,
        Gravity = 196.2,

        -- Character
        AutoRotate = true,

        -- Utility movement
        InfiniteJump = false,
        NoClip = false,
        Flight = false,

        -- Flight
        FlightSpeed = 50,
        FlightVerticalSpeed = 50,

        -- Update
        UpdateRate = 60,
    },

    State = {
        Jumping = false,
        NoClip = false,
        Flight = false,
    },

    _accumulator = 0,
}



-- Helpers


local function Disconnect(connection)
    if not connection then
        return
    end

    pcall(function()
        connection:Disconnect()
    end)
end


local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result = pcall(
        callback,
        ...
    )

    if not success then
        warn(
            "[Lua Test] GameFeatures error:",
            result
        )

        return false, result
    end

    return true, result
end


local function New(className)
    return Instance.new(className)
end



-- Configuration


function GameFeatures:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(
            function()
                return self.Config:Get(
                    "GameFeatures." .. name,
                    default
                )
            end
        )

        if success then
            return value
        end
    end

    return default
end


function GameFeatures:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


function GameFeatures:GetSettings()
    return self.Settings
end



-- Character


function GameFeatures:GetLocalPlayer()
    if self.LocalPlayer then
        return self.LocalPlayer
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    return self.LocalPlayer
end


function GameFeatures:GetCharacter()
    local player =
        self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetCharacter) == "function" then

        local success, character =
            pcall(function()
                return self.Players:GetCharacter(
                    player
                )
            end)

        if success and character then
            return character
        end
    end

    return player.Character
end


function GameFeatures:GetHumanoid()
    local character =
        self:GetCharacter()

    if not character then
        return nil
    end

    if self.Players
        and type(self.Players.GetHumanoid) == "function" then

        local success, humanoid =
            pcall(function()
                return self.Players:GetHumanoid(
                    self:GetLocalPlayer()
                )
            end)

        if success and humanoid then
            return humanoid
        end
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end


function GameFeatures:GetRoot()
    local character =
        self:GetCharacter()

    if not character then
        return nil
    end

    if self.Players
        and type(self.Players.GetRoot) == "function" then

        local success, root =
            pcall(function()
                return self.Players:GetRoot(
                    self:GetLocalPlayer()
                )
            end)

        if success and root then
            return root
        end
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end


function GameFeatures:RefreshCharacter()
    local character =
        self:GetCharacter()

    local humanoid =
        self:GetHumanoid()

    local root =
        self:GetRoot()

    self.CharacterModel =
        character

    self.Humanoid =
        humanoid

    self.RootPart =
        root

    if humanoid then
        if self.Original.WalkSpeed == nil then
            self.Original.WalkSpeed =
                humanoid.WalkSpeed
        end

        if self.Original.JumpPower == nil then
            self.Original.JumpPower =
                humanoid.JumpPower
        end

        if self.Original.JumpHeight == nil then
            self.Original.JumpHeight =
                humanoid.JumpHeight
        end

        if self.Original.AutoRotate == nil then
            self.Original.AutoRotate =
                humanoid.AutoRotate
        end
    end

    return character ~= nil
end



-- Movement


function GameFeatures:SetWalkSpeed(speed)
    speed =
        tonumber(speed)

    if not speed then
        return false
    end

    speed =
        math.clamp(
            speed,
            0,
            1000
        )

    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    humanoid.WalkSpeed =
        speed

    self.Settings.WalkSpeed =
        speed

    return true
end


function GameFeatures:GetWalkSpeed()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return nil
    end

    return humanoid.WalkSpeed
end


function GameFeatures:SetJumpPower(power)
    power =
        tonumber(power)

    if not power then
        return false
    end

    power =
        math.clamp(
            power,
            0,
            1000
        )

    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    humanoid.UseJumpPower = true
    humanoid.JumpPower = power

    self.Settings.JumpPower =
        power

    return true
end


function GameFeatures:GetJumpPower()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return nil
    end

    return humanoid.JumpPower
end


function GameFeatures:SetJumpHeight(height)
    height =
        tonumber(height)

    if not height then
        return false
    end

    height =
        math.clamp(
            height,
            0,
            1000
        )

    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    humanoid.UseJumpPower = false
    humanoid.JumpHeight = height

    self.Settings.JumpHeight =
        height

    return true
end


function GameFeatures:GetJumpHeight()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return nil
    end

    return humanoid.JumpHeight
end


function GameFeatures:SetSpeedEnabled(enabled)
    enabled =
        enabled == true

    self.Settings.SpeedEnabled =
        enabled

    if enabled then
        return self:SetWalkSpeed(
            self:GetSetting(
                "WalkSpeed",
                16
            )
        )
    end

    return self:RestoreWalkSpeed()
end


function GameFeatures:SetJumpEnabled(enabled)
    enabled =
        enabled == true

    self.Settings.JumpEnabled =
        enabled

    if enabled then
        return self:SetJumpPower(
            self:GetSetting(
                "JumpPower",
                50
            )
        )
    end

    return self:RestoreJump()
end



-- Restore movement


function GameFeatures:RestoreWalkSpeed()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    local value =
        self.Original.WalkSpeed

    if value == nil then
        value = 16
    end

    humanoid.WalkSpeed =
        value

    return true
end


function GameFeatures:RestoreJump()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    if self.Original.JumpPower ~= nil then
        humanoid.UseJumpPower = true
        humanoid.JumpPower =
            self.Original.JumpPower
    end

    if self.Original.JumpHeight ~= nil then
        humanoid.JumpHeight =
            self.Original.JumpHeight
    end

    return true
end


function GameFeatures:RestoreAutoRotate()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    if self.Original.AutoRotate ~= nil then
        humanoid.AutoRotate =
            self.Original.AutoRotate
    else
        humanoid.AutoRotate = true
    end

    return true
end



-- Gravity


function GameFeatures:SetGravity(gravity)
    gravity =
        tonumber(gravity)

    if not gravity then
        return false
    end

    gravity =
        math.clamp(
            gravity,
            0,
            1000
        )

    workspace.Gravity =
        gravity

    self.Settings.Gravity =
        gravity

    return true
end


function GameFeatures:GetGravity()
    return workspace.Gravity
end


function GameFeatures:SetGravityEnabled(enabled)
    enabled =
        enabled == true

    self.Settings.GravityEnabled =
        enabled

    if enabled then
        return self:SetGravity(
            self:GetSetting(
                "Gravity",
                196.2
            )
        )
    end

    return self:RestoreGravity()
end


function GameFeatures:RestoreGravity()
    if self.Original.Gravity ~= nil then
        workspace.Gravity =
            self.Original.Gravity
    else
        workspace.Gravity =
            196.2
    end

    return true
end



-- Infinite jump


function GameFeatures:SetInfiniteJump(enabled)
    enabled =
        enabled == true

    self.Settings.InfiniteJump =
        enabled

    return true
end


function GameFeatures:HandleJumpRequest()
    if not self.Enabled then
        return
    end

    if not self:GetSetting(
        "InfiniteJump",
        false
    ) then
        return
    end

    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return
    end

    if humanoid.Health <= 0 then
        return
    end

    self.State.Jumping = true

    pcall(function()
        humanoid:ChangeState(
            Enum.HumanoidStateType.Jumping
        )
    end)
end



-- No-clip


function GameFeatures:SetNoClip(enabled)
    enabled =
        enabled == true

    self.Settings.NoClip =
        enabled

    self.State.NoClip =
        enabled

    return true
end


function GameFeatures:ApplyNoClip()
    if not self.State.NoClip then
        return
    end

    local character =
        self:GetCharacter()

    if not character then
        return
    end

    for _, object in ipairs(
        character:GetDescendants()
    ) do
        if object:IsA("BasePart") then
            object.CanCollide = false
        end
    end
end


function GameFeatures:RestoreCollision()
    local character =
        self:GetCharacter()

    if not character then
        return
    end

    for _, object in ipairs(
        character:GetDescendants()
    ) do
        if object:IsA("BasePart") then
            object.CanCollide = true
        end
    end
end



-- Flight


function GameFeatures:SetFlight(enabled)
    enabled =
        enabled == true

    self.Settings.Flight =
        enabled

    self.State.Flight =
        enabled

    return true
end


function GameFeatures:GetFlightDirection()
    local camera =
        workspace.CurrentCamera

    if not camera then
        return Vector3.zero
    end

    local direction =
        Vector3.zero

    if UserInputService:IsKeyDown(
        Enum.KeyCode.W
    ) then
        direction +=
            camera.CFrame.LookVector
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.S
    ) then
        direction -=
            camera.CFrame.LookVector
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.A
    ) then
        direction -=
            camera.CFrame.RightVector
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.D
    ) then
        direction +=
            camera.CFrame.RightVector
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.Space
    ) then
        direction +=
            Vector3.new(
                0,
                1,
                0
            )
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.LeftControl
    ) then
        direction -=
            Vector3.new(
                0,
                1,
                0
            )
    end

    if direction.Magnitude > 0 then
        direction =
            direction.Unit
    end

    return direction
end


function GameFeatures:UpdateFlight()
    if not self.State.Flight then
        return
    end

    local root =
        self:GetRoot()

    local humanoid =
        self:GetHumanoid()

    if not root or not humanoid then
        return
    end

    if humanoid.Health <= 0 then
        return
    end

    local direction =
        self:GetFlightDirection()

    local speed =
        tonumber(
            self:GetSetting(
                "FlightSpeed",
                50
            )
        ) or 50

    root.AssemblyLinearVelocity =
        direction * speed

    humanoid.AutoRotate = false

    local camera =
        workspace.CurrentCamera

    if camera then
        local look =
            camera.CFrame.LookVector

        local horizontal =
            Vector3.new(
                look.X,
                0,
                look.Z
            )

        if horizontal.Magnitude > 0 then
            horizontal =
                horizontal.Unit

            root.CFrame =
                CFrame.lookAt(
                    root.Position,
                    root.Position
                        + horizontal
                )
        end
    end
end


function GameFeatures:StopFlight()
    self.State.Flight = false
    self.Settings.Flight = false

    local root =
        self:GetRoot()

    if root then
        root.AssemblyLinearVelocity =
            Vector3.zero
    end

    self:RestoreAutoRotate()
end



-- Character reset


function GameFeatures:ResetCharacter()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    pcall(function()
        humanoid.Health = 0
    end)

    return true
end


function GameFeatures:ForceSit()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    pcall(function()
        humanoid.Sit = true
    end)

    return true
end


function GameFeatures:ForceStand()
    local humanoid =
        self:GetHumanoid()

    if not humanoid then
        return false
    end

    pcall(function()
        humanoid.Sit = false
        humanoid:ChangeState(
            Enum.HumanoidStateType.GettingUp
        )
    end)

    return true
end



-- Main update


function GameFeatures:Update(deltaTime)
    if not self.Enabled then
        return
    end

    self._accumulator +=
        deltaTime

    local updateRate =
        math.max(
            1,
            tonumber(
                self:GetSetting(
                    "UpdateRate",
                    60
                )
            ) or 60
        )

    local interval =
        1 / updateRate

    if self._accumulator < interval then
        return
    end

    self._accumulator = 0

    if not self.CharacterModel
        or not self.CharacterModel.Parent then

        self:RefreshCharacter()
    end

    if self:GetSetting(
        "SpeedEnabled",
        false
    ) then
        local humanoid =
            self:GetHumanoid()

        if humanoid then
            humanoid.WalkSpeed =
                tonumber(
                    self:GetSetting(
                        "WalkSpeed",
                        16
                    )
                ) or 16
        end
    end

    if self:GetSetting(
        "JumpEnabled",
        false
    ) then
        local humanoid =
            self:GetHumanoid()

        if humanoid then
            humanoid.UseJumpPower = true

            humanoid.JumpPower =
                tonumber(
                    self:GetSetting(
                        "JumpPower",
                        50
                    )
                ) or 50
        end
    end

    if self:GetSetting(
        "GravityEnabled",
        false
    ) then
        workspace.Gravity =
            tonumber(
                self:GetSetting(
                    "Gravity",
                    196.2
                )
            ) or 196.2
    end

    self:ApplyNoClip()

    self:UpdateFlight()
end



-- Character events


function GameFeatures:CharacterAdded(character)
    self.CharacterModel =
        character

    self.Humanoid = nil
    self.RootPart = nil

    self.Original.WalkSpeed = nil
    self.Original.JumpPower = nil
    self.Original.JumpHeight = nil
    self.Original.AutoRotate = nil

    task.defer(function()
        if not character
            or not character.Parent then
            return
        end

        self:RefreshCharacter()
    end)
end


function GameFeatures:CharacterRemoving(character)
    if self.CharacterModel ~= character then
        return
    end

    self.CharacterModel = nil
    self.Humanoid = nil
    self.RootPart = nil

    self.State.NoClip = false
    self.State.Flight = false
end



-- Start


function GameFeatures:Start()
    if self.Running then
        return
    end

    self.Running = true
    self.Enabled = true

    self.Original.Gravity =
        workspace.Gravity

    self:RefreshCharacter()

    local player =
        self:GetLocalPlayer()

    if player then
        table.insert(
            self.Connections,

            player.CharacterAdded:Connect(
                function(character)
                    self:CharacterAdded(
                        character
                    )
                end
            )
        )

        table.insert(
            self.Connections,

            player.CharacterRemoving:Connect(
                function(character)
                    self:CharacterRemoving(
                        character
                    )
                end
            )
        )
    end

    table.insert(
        self.Connections,

        UserInputService.JumpRequest:Connect(
            function()
                self:HandleJumpRequest()
            end
        )
    )

    table.insert(
        self.Connections,

        RunService.Heartbeat:Connect(
            function(deltaTime)
                SafeCall(
                    function()
                        self:Update(
                            deltaTime
                        )
                    end
                )
            end
        )
    )
end



-- Stop


function GameFeatures:Stop()
    self.Enabled = false
    self.Running = false

    for _, connection in ipairs(
        self.Connections
    ) do
        Disconnect(connection)
    end

    self.Connections = {}

    self.State.NoClip = false
    self.State.Flight = false

    self.Settings.NoClip = false
    self.Settings.Flight = false

    self:RestoreCollision()
    self:RestoreWalkSpeed()
    self:RestoreJump()
    self:RestoreAutoRotate()
    self:RestoreGravity()
end



-- Toggle


function GameFeatures:SetEnabled(enabled)
    enabled =
        enabled == true

    if enabled then
        self:Start()
    else
        self:Stop()
    end

    return self.Enabled
end


function GameFeatures:Toggle()
    return self:SetEnabled(
        not self.Enabled
    )
end



-- Initialize


function GameFeatures:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Players =
        modules.Players

    self.Character =
        modules.Character

    self.Math =
        modules.Math

    self.Cleanup =
        modules.Cleanup

    self.Config =
        modules.Config

    self.LocalPlayer =
        PlayersService.LocalPlayer

    self.Initialized = true

    return self
end



-- Cleanup


function GameFeatures:Destroy()
    self:Stop()

    self.Players = nil
    self.Character = nil
    self.Math = nil
    self.Cleanup = nil
    self.Config = nil

    self.LocalPlayer = nil

    self.CharacterModel = nil
    self.Humanoid = nil
    self.RootPart = nil

    self.Initialized = false
end


return GameFeatures