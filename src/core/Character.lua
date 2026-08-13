local Players = game:GetService("Players")

local Character = {
    Name = "Character",

    Initialized = false,

    Player = nil,

    Current = nil,
    Humanoid = nil,
    Root = nil,

    Connections = nil,

    Ready = false,
    Generation = 0,
}


-- Helpers


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
            "[Lua Test] Character:",
            result
        )

        return false, result
    end

    return true, result
end


-- Basic access


function Character:GetPlayer()
    return self.Player
end

function Character:Get()
    return self.Current
end

function Character:GetHumanoid()
    return self.Humanoid
end

function Character:GetRoot()
    return self.Root
end

function Character:IsReady()
    return self.Ready
        and self.Current ~= nil
        and self.Humanoid ~= nil
        and self.Root ~= nil
end

function Character:GetGeneration()
    return self.Generation
end


-- Character discovery


function Character:FindHumanoid(
    character
)
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end

function Character:FindRoot(
    character
)
    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

function Character:Refresh(
    character
)
    character =
        character
        or (
            self.Player
            and self.Player.Character
        )

    self.Current =
        character

    if not character then
        self.Humanoid = nil
        self.Root = nil
        self.Ready = false

        return false
    end

    self.Humanoid =
        self:FindHumanoid(
            character
        )

    self.Root =
        self:FindRoot(
            character
        )

    self.Ready =
        self.Humanoid ~= nil
        and self.Root ~= nil

    return self.Ready
end


-- Wait helpers


function Character:WaitForCharacter(
    timeout
)
    local player =
        self.Player

    if not player then
        return nil
    end

    if player.Character then
        self:Refresh(
            player.Character
        )

        return player.Character
    end

    local character

    local success =
        pcall(function()
            character =
                player
                    :CharacterAdded
                    :Wait()
        end)

    if not success then
        return nil
    end

    self:Refresh(
        character
    )

    return character
end

function Character:WaitForRoot(
    timeout
)
    local character =
        self:WaitForCharacter(
            timeout
        )

    if not character then
        return nil
    end

    local root =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    if root then
        self.Root = root
        return root
    end

    local success

    success =
        pcall(function()
            root =
                character
                    :WaitForChild(
                        "HumanoidRootPart",
                        timeout
                    )
        end)

    if success and root then
        self.Root = root
        self.Ready =
            self.Humanoid ~= nil

        return root
    end

    return nil
end

function Character:WaitForHumanoid(
    timeout
)
    local character =
        self:WaitForCharacter(
            timeout
        )

    if not character then
        return nil
    end

    local humanoid =
        self:FindHumanoid(
            character
        )

    if humanoid then
        self.Humanoid =
            humanoid

        self.Ready =
            self.Root ~= nil

        return humanoid
    end

    local success

    success =
        pcall(function()
            humanoid =
                character
                    :WaitForChild(
                        "Humanoid",
                        timeout
                    )
        end)

    if success and humanoid then
        self.Humanoid =
            humanoid

        self.Ready =
            self.Root ~= nil

        return humanoid
    end

    return nil
end


-- Character state


function Character:IsAlive()
    local humanoid =
        self.Humanoid

    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end

function Character:GetHealth()
    local humanoid =
        self.Humanoid

    if not humanoid then
        return 0
    end

    return humanoid.Health
end

function Character:GetMaxHealth()
    local humanoid =
        self.Humanoid

    if not humanoid then
        return 0
    end

    return humanoid.MaxHealth
end

function Character:GetHealthPercent()
    local health =
        self:GetHealth()

    local maxHealth =
        self:GetMaxHealth()

    if maxHealth <= 0 then
        return 0
    end

    return math.clamp(
        health / maxHealth,
        0,
        1
    )
end


-- Position


function Character:GetPosition()
    local root =
        self.Root

    if not root then
        return nil
    end

    return root.Position
end

function Character:GetCFrame()
    local root =
        self.Root

    if not root then
        return nil
    end

    return root.CFrame
end

function Character:SetCFrame(
    cframe
)
    if not self.Root then
        return false,
            "Root not available"
    end

    if typeof(cframe) ~= "CFrame" then
        return false,
            "CFrame required"
    end

    local success, result =
        SafeCall(function()
            self.Root.CFrame =
                cframe
        end)

    if not success then
        return false,
            result
    end

    return true
end


-- Humanoid movement


function Character:GetWalkSpeed()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid.WalkSpeed
end

function Character:SetWalkSpeed(
    speed
)
    if not self.Humanoid then
        return false,
            "Humanoid not available"
    end

    speed =
        tonumber(speed)

    if not speed then
        return false,
            "Invalid speed"
    end

    self.Humanoid.WalkSpeed =
        speed

    return true
end

function Character:GetJumpPower()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid.JumpPower
end

function Character:SetJumpPower(
    power
)
    if not self.Humanoid then
        return false,
            "Humanoid not available"
    end

    power =
        tonumber(power)

    if not power then
        return false,
            "Invalid jump power"
    end

    self.Humanoid.JumpPower =
        power

    return true
end

function Character:GetJumpHeight()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid.JumpHeight
end

function Character:SetJumpHeight(
    height
)
    if not self.Humanoid then
        return false,
            "Humanoid not available"
    end

    height =
        tonumber(height)

    if not height then
        return false,
            "Invalid jump height"
    end

    self.Humanoid.JumpHeight =
        height

    return true
end

function Character:GetHipHeight()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid.HipHeight
end

function Character:SetHipHeight(
    height
)
    if not self.Humanoid then
        return false,
            "Humanoid not available"
    end

    height =
        tonumber(height)

    if not height then
        return false,
            "Invalid hip height"
    end

    self.Humanoid.HipHeight =
        height

    return true
end

function Character:GetAutoRotate()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid.AutoRotate
end

function Character:SetAutoRotate(
    enabled
)
    if not self.Humanoid then
        return false,
            "Humanoid not available"
    end

    self.Humanoid.AutoRotate =
        enabled == true

    return true
end


-- Movement state


function Character:GetMoveDirection()
    if not self.Humanoid then
        return Vector3.zero
    end

    return self.Humanoid.MoveDirection
end

function Character:IsMoving()
    return self:GetMoveDirection().Magnitude > 0
end

function Character:IsGrounded()
    if not self.Humanoid then
        return false
    end

    local state =
        self.Humanoid:GetState()

    return state
        == Enum.HumanoidStateType.Running
        or state
        == Enum.HumanoidStateType.RunningNoPhysics
end

function Character:GetState()
    if not self.Humanoid then
        return nil
    end

    return self.Humanoid:GetState()
end


-- Character parts


function Character:GetPart(name)
    if not self.Current then
        return nil
    end

    if type(name) ~= "string"
        or name == "" then
        return nil
    end

    return self.Current:FindFirstChild(
        name
    )
end

function Character:GetRootPosition()
    local root =
        self:GetRoot()

    return root
        and root.Position
end

function Character:GetRootVelocity()
    local root =
        self:GetRoot()

    if not root then
        return Vector3.zero
    end

    return root.AssemblyLinearVelocity
end


-- Events


function Character:BindEvents()
    if not self.Player then
        return
    end

    if not self.Connections then
        return
    end

    self.Connections:Connect(
        self.Player.CharacterAdded,
        function(character)
            self.Generation += 1

            self:Refresh(
                character
            )
        end,
        "Character"
    )

    self.Connections:Connect(
        self.Player.CharacterRemoving,
        function(character)
            if self.Current == character then
                self.Current = nil
                self.Humanoid = nil
                self.Root = nil
                self.Ready = false
            end
        end,
        "Character"
    )
end


-- Initialize


function Character:Initialize(
    modules
)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Connections =
        modules.Connections

    self.Player =
        Players.LocalPlayer

    if not self.Player then
        warn(
            "[Lua Test] Character: LocalPlayer unavailable"
        )

        return self
    end

    self:Refresh()

    self:BindEvents()

    self.Initialized = true

    return self
end


-- Reset


function Character:Reset()
    self.Current = nil
    self.Humanoid = nil
    self.Root = nil
    self.Ready = false
end


-- Destroy


function Character:Destroy()
    if self.Connections then
        self.Connections:DisconnectGroup(
            "Character"
        )
    end

    self:Reset()

    self.Player = nil
    self.Connections = nil

    self.Initialized = false
end

return Character