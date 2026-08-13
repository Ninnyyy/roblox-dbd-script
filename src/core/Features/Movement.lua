--[[
    Lua Test Script
    Movement.lua

    Handles movement-related features in a modular way.

    Features:
        - WalkSpeed
        - JumpPower / JumpHeight
        - Infinite Jump
        - NoClip
        - Fly
        - Flight speed
        - Gravity control
        - Auto jump
        - Movement state preservation
        - Character respawn handling
        - Safe enable/disable
        - Connection cleanup
        - Runtime configuration
]]

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Movement = {
    Name = "Movement",

    Enabled = false,
    Initialized = false,
    Running = false,

    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    Connections = {},
    CharacterConnections = {},

    LocalPlayer = nil,
    CharacterModel = nil,
    Humanoid = nil,
    RootPart = nil,

    Original = {
        WalkSpeed = nil,
        JumpPower = nil,
        JumpHeight = nil,
        UseJumpPower = nil,
        Gravity = nil,
        AutoRotate = nil,
    },

    Settings = {
        Enabled = false,

        -- Walk
        WalkSpeed = 16,
        WalkSpeedEnabled = false,

        -- Jump
        JumpPower = 50,
        JumpHeight = 7.2,
        JumpEnabled = false,

        -- Infinite jump
        InfiniteJump = false,

        -- NoClip
        NoClip = false,

        -- Fly
        Fly = false,
        FlySpeed = 60,
        FlyVerticalSpeed = 60,

        -- Gravity
        Gravity = 196.2,
        GravityEnabled = false,

        -- Auto jump
        AutoJump = false,
        AutoJumpDelay = 0.5,

        -- Character behavior
        AutoRotate = true,

        -- Update
        UpdateRate = 60,
    },

    State = {
        FlyUp = false,
        FlyDown = false,

        LastAutoJump = 0,

        NoclipParts = {},

        LastPosition = nil,
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
            "[Lua Test] Movement error:",
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


function Movement:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(
            function()
                return self.Config:Get(
                    "Movement." .. name,
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


function Movement:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


function Movement:GetSettings()
    return self.Settings
end


function Movement:GetState()
    return self.State
end



-- Character


function Movement:GetLocalPlayer()
    if self.LocalPlayer then
        return self.LocalPlayer
    end

    self.LocalPlayer = PlayersService.LocalPlayer

    return self.LocalPlayer
end


function Movement:GetCharacter()
    local player = self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetCharacter) == "function" then

        local success, character =
            pcall(function()
                return self.Players:GetCharacter(player)
            end)

        if success and character then
            return character
        end
    end

    return player.Character
end


function Movement:GetHumanoid()
    local character = self:GetCharacter()

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


function Movement:GetRootPart()
    local character = self:GetCharacter()

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



-- Original values


function Movement:CaptureOriginal()
    local humanoid = self:GetHumanoid()

    if humanoid then
        self.Original.WalkSpeed =
            humanoid.WalkSpeed

        self.Original.UseJumpPower =
            humanoid.UseJumpPower

        self.Original.JumpPower =
            humanoid.JumpPower

        self.Original.JumpHeight =
            humanoid.JumpHeight

        self.Original.AutoRotate =
            humanoid.AutoRotate
    end

    self.Original.Gravity =
        workspace.Gravity
end


function Movement:RestoreOriginal()
    local humanoid = self:GetHumanoid()

    if humanoid then
        if self.Original.WalkSpeed ~= nil then
            pcall(function()
                humanoid.WalkSpeed =
                    self.Original.WalkSpeed
            end)
        end

        if self.Original.UseJumpPower ~= nil then
            pcall(function()
                humanoid.UseJumpPower =
                    self.Original.UseJumpPower
            end)
        end

        if self.Original.JumpPower ~= nil then
            pcall(function()
                humanoid.JumpPower =
                    self.Original.JumpPower
            end)
        end

        if self.Original.JumpHeight ~= nil then
            pcall(function()
                humanoid.JumpHeight =
                    self.Original.JumpHeight
            end)
        end

        if self.Original.AutoRotate ~= nil then
            pcall(function()
                humanoid.AutoRotate =
                    self.Original.AutoRotate
            end)
        end
    end

    if self.Original.Gravity ~= nil then
        pcall(function()
            workspace.Gravity =
                self.Original.Gravity
        end)
    end
end



-- WalkSpeed


function Movement:UpdateWalkSpeed()
    local humanoid = self:GetHumanoid()

    if not humanoid then
        return
    end

    local enabled =
        self:GetSetting(
            "WalkSpeedEnabled",
            false
        )

    if not enabled then
        return
    end

    local speed =
        tonumber(
            self:GetSetting(
                "WalkSpeed",
                16
            )
        ) or 16

    speed = math.clamp(
        speed,
        0,
        500
    )

    pcall(function()
        humanoid.WalkSpeed = speed
    end)
end


function Movement:SetWalkSpeed(speed)
    speed = tonumber(speed)

    if not speed then
        return false
    end

    self.Settings.WalkSpeed =
        math.clamp(
            speed,
            0,
            500
        )

    self.Settings.WalkSpeedEnabled = true

    self:UpdateWalkSpeed()

    return true
end



-- Jump


function Movement:UpdateJump()
    local humanoid = self:GetHumanoid()

    if not humanoid then
        return
    end

    if not self:GetSetting(
        "JumpEnabled",
        false
    ) then
        return
    end

    local jumpPower =
        tonumber(
            self:GetSetting(
                "JumpPower",
                50
            )
        ) or 50

    local jumpHeight =
        tonumber(
            self:GetSetting(
                "JumpHeight",
                7.2
            )
        ) or 7.2

    pcall(function()
        if humanoid.UseJumpPower then
            humanoid.JumpPower =
                math.clamp(
                    jumpPower,
                    0,
                    500
                )
        else
            humanoid.JumpHeight =
                math.clamp(
                    jumpHeight,
                    0,
                    100
                )
        end
    end)
end


function Movement:SetJumpPower(power)
    power = tonumber(power)

    if not power then
        return false
    end

    self.Settings.JumpPower =
        math.clamp(
            power,
            0,
            500
        )

    self.Settings.JumpEnabled = true

    self:UpdateJump()

    return true
end



-- Auto Rotate


function Movement:UpdateAutoRotate()
    local humanoid = self:GetHumanoid()

    if not humanoid then
        return
    end

    local enabled =
        self:GetSetting(
            "AutoRotate",
            true
        )

    pcall(function()
        humanoid.AutoRotate =
            enabled
    end)
end



-- Gravity


function Movement:UpdateGravity()
    local enabled =
        self:GetSetting(
            "GravityEnabled",
            false
        )

    if not enabled then
        return
    end

    local gravity =
        tonumber(
            self:GetSetting(
                "Gravity",
                196.2
            )
        ) or 196.2

    gravity = math.clamp(
        gravity,
        0,
        500
    )

    pcall(function()
        workspace.Gravity =
            gravity
    end)
end


function Movement:SetGravity(gravity)
    gravity = tonumber(gravity)

    if not gravity then
        return false
    end

    self.Settings.Gravity =
        math.clamp(
            gravity,
            0,
            500
        )

    self.Settings.GravityEnabled = true

    self:UpdateGravity()

    return true
end



-- Infinite Jump


function Movement:InfiniteJump()
    if not self:GetSetting(
        "InfiniteJump",
        false
    ) then
        return
    end

    local humanoid = self:GetHumanoid()

    if not humanoid then
        return
    end

    if humanoid.Health <= 0 then
        return
    end

    pcall(function()
        humanoid:ChangeState(
            Enum.HumanoidStateType.Jumping
        )
    end)
end



-- NoClip


function Movement:UpdateNoClip()
    local character = self:GetCharacter()

    if not character then
        return
    end

    local enabled =
        self:GetSetting(
            "NoClip",
            false
        )

    for _, object in ipairs(
        character:GetDescendants()
    ) do
        if object:IsA("BasePart") then
            if enabled then
                self.State.NoclipParts[object] =
                    object.CanCollide

                pcall(function()
                    object.CanCollide = false
                end)
            end
        end
    end
end


function Movement:RestoreNoClip()
    for part, original in pairs(
        self.State.NoclipParts
    ) do
        if part
            and part.Parent then

            pcall(function()
                part.CanCollide = original
            end)
        end
    end

    self.State.NoclipParts = {}
end


function Movement:SetNoClip(enabled)
    enabled = enabled == true

    self.Settings.NoClip =
        enabled

    if not enabled then
        self:RestoreNoClip()
    end

    return true
end



-- Fly


function Movement:SetFly(enabled)
    enabled = enabled == true

    self.Settings.Fly =
        enabled

    local humanoid = self:GetHumanoid()

    if enabled then
        if humanoid then
            pcall(function()
                humanoid.PlatformStand = true
            end)
        end
    else
        if humanoid then
            pcall(function()
                humanoid.PlatformStand = false
            end)
        end
    end

    return true
end


function Movement:GetFlyDirection()
    local camera =
        workspace.CurrentCamera

    if not camera then
        return Vector3.zero
    end

    local direction =
        Vector3.zero

    local look =
        camera.CFrame.LookVector

    local right =
        camera.CFrame.RightVector

    if UserInputService:IsKeyDown(
        Enum.KeyCode.W
    ) then
        direction += look
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.S
    ) then
        direction -= look
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.D
    ) then
        direction += right
    end

    if UserInputService:IsKeyDown(
        Enum.KeyCode.A
    ) then
        direction -= right
    end

    if self.State.FlyUp then
        direction += Vector3.yAxis
    end

    if self.State.FlyDown then
        direction -= Vector3.yAxis
    end

    if direction.Magnitude > 0 then
        direction =
            direction.Unit
    end

    return direction
end


function Movement:UpdateFly(deltaTime)
    if not self:GetSetting(
        "Fly",
        false
    ) then
        return
    end

    local root =
        self:GetRootPart()

    if not root then
        return
    end

    local humanoid =
        self:GetHumanoid()

    if humanoid then
        pcall(function()
            humanoid.PlatformStand =
                true
        end)
    end

    local direction =
        self:GetFlyDirection()

    local speed =
        tonumber(
            self:GetSetting(
                "FlySpeed",
                60
            )
        ) or 60

    local verticalSpeed =
        tonumber(
            self:GetSetting(
                "FlyVerticalSpeed",
                speed
            )
        ) or speed

    local velocity =
        Vector3.zero

    local horizontal =
        Vector3.new(
            direction.X,
            0,
            direction.Z
        )

    if horizontal.Magnitude > 0 then
        velocity +=
            horizontal.Unit * speed
    end

    if direction.Y > 0 then
        velocity +=
            Vector3.yAxis * verticalSpeed
    elseif direction.Y < 0 then
        velocity -=
            Vector3.yAxis * verticalSpeed
    end

    pcall(function()
        root.AssemblyLinearVelocity =
            velocity
    end)

    self.State.LastPosition =
        root.Position
end



-- Auto Jump


function Movement:UpdateAutoJump()
    if not self:GetSetting(
        "AutoJump",
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

    local now =
        os.clock()

    local delay =
        tonumber(
            self:GetSetting(
                "AutoJumpDelay",
                0.5
            )
        ) or 0.5

    if now - self.State.LastAutoJump < delay then
        return
    end

    self.State.LastAutoJump =
        now

    pcall(function()
        humanoid.Jump = true
    end)
end



-- Character Binding


function Movement:DisconnectCharacterConnections()
    for _, connection in ipairs(
        self.CharacterConnections
    ) do
        Disconnect(connection)
    end

    self.CharacterConnections = {}
end


function Movement:BindCharacter(character)
    self:DisconnectCharacterConnections()

    self:RestoreNoClip()

    self.CharacterModel =
        character

    self.Humanoid = nil
    self.RootPart = nil

    if not character then
        return
    end

    self.Humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    self.RootPart =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    table.insert(
        self.CharacterConnections,

        character.ChildAdded:Connect(
            function(child)
                if child:IsA("Humanoid") then
                    self.Humanoid = child

                elseif child.Name ==
                    "HumanoidRootPart" then

                    self.RootPart = child
                end
            end
        )
    )

    table.insert(
        self.CharacterConnections,

        character.AncestryChanged:Connect(
            function(_, parent)
                if not parent then
                    self.Humanoid = nil
                    self.RootPart = nil
                end
            end
        )
    )

    self:CaptureOriginal()

    self:UpdateWalkSpeed()
    self:UpdateJump()
    self:UpdateAutoRotate()

    if self:GetSetting(
        "Fly",
        false
    ) then
        self:SetFly(true)
    end
end



-- Input


function Movement:SetupInput()
    table.insert(
        self.Connections,

        UserInputService.InputBegan:Connect(
            function(input, processed)
                if processed then
                    return
                end

                if input.KeyCode ==
                    Enum.KeyCode.Space then

                    if self:GetSetting(
                        "InfiniteJump",
                        false
                    ) then
                        self:InfiniteJump()
                    end
                end

                if input.KeyCode ==
                    Enum.KeyCode.LeftControl then

                    self.State.FlyDown = true
                end

                if input.KeyCode ==
                    Enum.KeyCode.Space then

                    self.State.FlyUp = true
                end
            end
        )
    )

    table.insert(
        self.Connections,

        UserInputService.InputEnded:Connect(
            function(input)
                if input.KeyCode ==
                    Enum.KeyCode.LeftControl then

                    self.State.FlyDown = false
                end

                if input.KeyCode ==
                    Enum.KeyCode.Space then

                    self.State.FlyUp = false
                end
            end
        )
    )
end



-- Main Update


function Movement:Update(deltaTime)
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

    self:UpdateWalkSpeed()
    self:UpdateJump()
    self:UpdateAutoRotate()
    self:UpdateGravity()
    self:UpdateNoClip()
    self:UpdateAutoJump()

    self:UpdateFly(
        deltaTime
    )
end



-- Start


function Movement:Start()
    if self.Running then
        return
    end

    self.Running = true
    self.Enabled = true

    self.LocalPlayer =
        PlayersService.LocalPlayer

    if not self.LocalPlayer then
        self.Running = false
        self.Enabled = false
        return
    end

    self:BindCharacter(
        self.LocalPlayer.Character
    )

    table.insert(
        self.Connections,

        self.LocalPlayer.CharacterAdded:Connect(
            function(character)
                self:BindCharacter(
                    character
                )
            end
        )
    )

    table.insert(
        self.Connections,

        self.LocalPlayer.CharacterRemoving:Connect(
            function(character)
                if self.CharacterModel ==
                    character then

                    self:DisconnectCharacterConnections()

                    self:RestoreNoClip()

                    self.CharacterModel = nil
                    self.Humanoid = nil
                    self.RootPart = nil
                end
            end
        )
    )

    self:SetupInput()

    table.insert(
        self.Connections,

        RunService.RenderStepped:Connect(
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


function Movement:Stop()
    self.Enabled = false
    self.Running = false

    for _, connection in ipairs(
        self.Connections
    ) do
        Disconnect(connection)
    end

    self.Connections = {}

    self:DisconnectCharacterConnections()

    self:RestoreNoClip()

    if self:GetSetting(
        "Fly",
        false
    ) then
        self.Settings.Fly = false
    end

    local humanoid =
        self:GetHumanoid()

    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
        end)
    end

    self:RestoreOriginal()

    self.State.FlyUp = false
    self.State.FlyDown = false
    self.State.LastPosition = nil
end



-- Enable / Disable


function Movement:SetEnabled(enabled)
    enabled = enabled == true

    if enabled then
        self:Start()
    else
        self:Stop()
    end

    return self.Enabled
end


function Movement:Toggle()
    return self:SetEnabled(
        not self.Enabled
    )
end



-- Individual Feature Toggles


function Movement:SetWalkSpeedEnabled(enabled)
    self.Settings.WalkSpeedEnabled =
        enabled == true

    if not enabled then
        local humanoid =
            self:GetHumanoid()

        if humanoid
            and self.Original.WalkSpeed then

            pcall(function()
                humanoid.WalkSpeed =
                    self.Original.WalkSpeed
            end)
        end
    end

    return self.Settings.WalkSpeedEnabled
end


function Movement:SetJumpEnabled(enabled)
    self.Settings.JumpEnabled =
        enabled == true

    if self.Settings.JumpEnabled then
        self:UpdateJump()
    else
        local humanoid =
            self:GetHumanoid()

        if humanoid then
            if self.Original.JumpPower then
                pcall(function()
                    humanoid.JumpPower =
                        self.Original.JumpPower
                end)
            end

            if self.Original.JumpHeight then
                pcall(function()
                    humanoid.JumpHeight =
                        self.Original.JumpHeight
                end)
            end
        end
    end

    return self.Settings.JumpEnabled
end


function Movement:SetInfiniteJump(enabled)
    self.Settings.InfiniteJump =
        enabled == true

    return self.Settings.InfiniteJump
end


function Movement:SetAutoJump(enabled)
    self.Settings.AutoJump =
        enabled == true

    return self.Settings.AutoJump
end


function Movement:SetGravityEnabled(enabled)
    self.Settings.GravityEnabled =
        enabled == true

    if not enabled then
        if self.Original.Gravity ~= nil then
            pcall(function()
                workspace.Gravity =
                    self.Original.Gravity
            end)
        end
    else
        self:UpdateGravity()
    end

    return self.Settings.GravityEnabled
end



-- Initialize


function Movement:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules = modules or {}

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



-- Destroy


function Movement:Destroy()
    self:Stop()

    self:DisconnectCharacterConnections()

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


return Movement