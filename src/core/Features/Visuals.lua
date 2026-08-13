local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Visuals = {
    Name = "Visuals",

    Description = "Player and world visual features",

    Category = "Visuals",

    Dependencies = {},

    Enabled = false,
    Initialized = false,

    Modules = nil,

    Connections = {},

    Objects = {},

    Settings = {
        ESP = {
            Enabled = true,

            TeamCheck = false,
            AliveOnly = true,

            MaxDistance = 2000,

            Boxes = true,
            Names = true,
            Health = true,
            Distance = true,

            BoxThickness = 1,
            BoxTransparency = 0,

            NameOffset = 18,
            DistanceOffset = 32,

            ShowOffscreen = false,
        },

        Tracers = {
            Enabled = false,

            TeamCheck = false,
            MaxDistance = 2000,

            Thickness = 1,
            Transparency = 0.75,
        },
    },
}


-- Helpers


function Visuals:_Players()
    if self.Modules then
        return self.Modules.Players
    end

    return nil
end

function Visuals:_Math()
    if self.Modules then
        return self.Modules.Math
    end

    return nil
end

function Visuals:_Cleanup()
    if self.Modules then
        return self.Modules.Cleanup
    end

    return nil
end

function Visuals:_Camera()
    return Workspace.CurrentCamera
end

function Visuals:_LocalPlayer()
    return PlayersService.LocalPlayer
end


-- Initialization


function Visuals:Initialize(modules)
    if self.Initialized then
        return self
    end

    self.Modules = modules or {}

    self.Objects = {}
    self.Connections = {}

    self.Initialized = true

    return self
end


-- Settings


function Visuals:Set(
    section,
    option,
    value
)
    if type(section) ~= "string"
        or type(option) ~= "string" then
        return false
    end

    if type(self.Settings[section]) ~= "table" then
        return false
    end

    if self.Settings[section][option] == nil then
        return false
    end

    self.Settings[section][option] = value

    return true
end

function Visuals:Get(
    section,
    option
)
    if type(section) ~= "string"
        or type(option) ~= "string" then
        return nil
    end

    if type(self.Settings[section]) ~= "table" then
        return nil
    end

    return self.Settings[section][option]
end


-- Character validation


function Visuals:IsValidPlayer(
    player
)
    local players = self:_Players()

    if not players then
        return false
    end

    return players:IsValidTarget(
        player,
        {
            ExcludeLocal = true,

            AliveOnly =
                self.Settings.ESP.AliveOnly,

            TeamCheck =
                self.Settings.ESP.TeamCheck,

            MaxDistance =
                self.Settings.ESP.MaxDistance,
        }
    )
end

function Visuals:GetRoot(
    player
)
    local players = self:_Players()

    if not players then
        return nil
    end

    return players:GetRoot(player)
end


-- Screen projection


function Visuals:Project(
    worldPosition
)
    local camera =
        self:_Camera()

    if not camera
        or typeof(worldPosition)
            ~= "Vector3" then
        return nil
    end

    local screenPosition,
        visible =
        camera:WorldToViewportPoint(
            worldPosition
        )

    return {
        Position = Vector2.new(
            screenPosition.X,
            screenPosition.Y
        ),

        Depth = screenPosition.Z,

        Visible = visible
            and screenPosition.Z > 0,
    }
end


-- Bounding box


function Visuals:GetBoundingBox(
    player
)
    local character =
        player.Character

    if not character then
        return nil
    end

    local camera =
        self:_Camera()

    if not camera then
        return nil
    end

    local success,
        cframe,
        size =
        pcall(function()
            return character:GetBoundingBox()
        end)

    if not success
        or not cframe
        or not size then
        return nil
    end

    local half =
        size / 2

    local corners = {
        Vector3.new(
            -half.X,
            -half.Y,
            -half.Z
        ),

        Vector3.new(
            -half.X,
            -half.Y,
            half.Z
        ),

        Vector3.new(
            -half.X,
            half.Y,
            -half.Z
        ),

        Vector3.new(
            -half.X,
            half.Y,
            half.Z
        ),

        Vector3.new(
            half.X,
            -half.Y,
            -half.Z
        ),

        Vector3.new(
            half.X,
            -half.Y,
            half.Z
        ),

        Vector3.new(
            half.X,
            half.Y,
            -half.Z
        ),

        Vector3.new(
            half.X,
            half.Y,
            half.Z
        ),
    }

    local points = {}

    for _, corner in ipairs(corners) do
        local projected =
            self:Project(
                cframe:PointToWorldSpace(
                    corner
                )
            )

        if projected
            and projected.Depth > 0 then

            table.insert(
                points,
                projected.Position
            )
        end
    end

    if #points < 2 then
        return nil
    end

    local mathModule =
        self:_Math()

    if mathModule then
        return mathModule:GetBoundingBox2D(
            points
        )
    end

    return nil
end


-- Visual object creation


function Visuals:_CreateDrawing(
    className
)
    -- Visual rendering is intentionally
    -- kept behind this function so the
    -- project can use a legitimate
    -- Roblox UI implementation.

    return nil
end

function Visuals:_CreateESPObject(
    player
)
    if self.Objects[player] then
        return self.Objects[player]
    end

    local object = {
        Player = player,

        Box = nil,
        Name = nil,
        Health = nil,
        Distance = nil,
        Tracer = nil,

        Visible = false,
    }

    self.Objects[player] = object

    return object
end

function Visuals:_RemoveESPObject(
    player
)
    local object =
        self.Objects[player]

    if not object then
        return
    end

    for key, instance in pairs(object) do
        if typeof(instance) == "Instance" then
            pcall(function()
                instance:Destroy()
            end)
        end

        object[key] = nil
    end

    self.Objects[player] = nil
end

function Visuals:ClearObjects()
    for player in pairs(
        self.Objects
    ) do
        self:_RemoveESPObject(
            player
        )
    end

    self.Objects = {}
end


-- Player update


function Visuals:UpdatePlayer(
    player
)
    if not self.Enabled then
        return
    end

    local object =
        self:_CreateESPObject(
            player
        )

    if not self:IsValidPlayer(player) then
        object.Visible = false

        return
    end

    local root =
        self:GetRoot(player)

    if not root then
        object.Visible = false

        return
    end

    local projected =
        self:Project(
            root.Position
        )

    if not projected
        or not projected.Visible then

        object.Visible = false

        return
    end

    local bounds =
        self:GetBoundingBox(
            player
        )

    if not bounds then
        object.Visible = false

        return
    end

    object.Visible = true

    object.Position =
        bounds.Center

    object.Size =
        bounds.Size

    object.Distance =
        self:_Players()
            :GetDistanceFromLocal(
                player
            )

    object.Health =
        self:_Players()
            :GetHealthPercent(
                player
            )

    object.DisplayName =
        player.DisplayName

    object.Name =
        player.Name
end

function Visuals:UpdateAll()
    if not self.Enabled then
        return
    end

    local players =
        self:_Players()

    if not players then
        return
    end

    for _, player in ipairs(
        players:GetAll()
    ) do
        if player ~= self:_LocalPlayer() then
            self:UpdatePlayer(
                player
            )
        end
    end

    for player in pairs(
        self.Objects
    ) do
        if not player.Parent then
            self:_RemoveESPObject(
                player
            )
        end
    end
end


-- Player events


function Visuals:_Connect(
    signal,
    callback
)
    if not signal
        or type(callback) ~= "function" then
        return nil
    end

    local connection =
        signal:Connect(
            callback
        )

    table.insert(
        self.Connections,
        connection
    )

    return connection
end

function Visuals:ConnectPlayerEvents()
    self:_Connect(
        PlayersService.PlayerRemoving,
        function(player)
            self:_RemoveESPObject(
                player
            )
        end
    )
end


-- Render loop


function Visuals:StartRenderLoop()
    if self.RenderConnection then
        return
    end

    self.RenderConnection =
        RunService.RenderStepped:Connect(
            function()
                if self.Enabled then
                    self:UpdateAll()
                end
            end
        )

    table.insert(
        self.Connections,
        self.RenderConnection
    )
end

function Visuals:StopRenderLoop()
    if not self.RenderConnection then
        return
    end

    pcall(function()
        self.RenderConnection:Disconnect()
    end)

    self.RenderConnection = nil
end


-- Enable


function Visuals:Enable()
    if self.Enabled then
        return true
    end

    if not self.Initialized then
        self:Initialize(
            self.Modules
        )
    end

    self.Enabled = true

    self:ConnectPlayerEvents()
    self:StartRenderLoop()

    return true
end


-- Disable


function Visuals:Disable()
    if not self.Enabled then
        return true
    end

    self.Enabled = false

    self:StopRenderLoop()
    self:ClearObjects()

    for index = #self.Connections, 1, -1 do
        local connection =
            self.Connections[index]

        pcall(function()
            connection:Disconnect()
        end)

        table.remove(
            self.Connections,
            index
        )
    end

    return true
end


-- Destroy


function Visuals:Destroy()
    self:Disable()

    self.Modules = nil
    self.Initialized = false

    return true
end

return Visuals