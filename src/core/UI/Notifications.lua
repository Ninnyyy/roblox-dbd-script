local Notifications = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

Notifications.__index = Notifications

local DEFAULTS = {
    Width = 320,
    Height = 72,

    Padding = 8,
    Margin = 18,

    Duration = 3,

    MaxNotifications = 6,

    AnimationTime = 0.18,

    Background = Color3.fromRGB(24, 24, 31),
    Border = Color3.fromRGB(55, 55, 67),

    Text = Color3.fromRGB(238, 238, 244),
    MutedText = Color3.fromRGB(150, 150, 162),

    Info = Color3.fromRGB(120, 90, 255),
    Success = Color3.fromRGB(80, 210, 130),
    Warning = Color3.fromRGB(240, 185, 80),
    Error = Color3.fromRGB(235, 85, 95),

    EnableAnimations = true,
    EnableHoverPause = true,
    EnableProgress = true,
    EnableCloseButton = true,
}

local function merge(defaults, overrides)
    local result = {}

    for key, value in pairs(defaults) do
        result[key] = value
    end

    for key, value in pairs(overrides or {}) do
        result[key] = value
    end

    return result
end

local function Create(className, properties)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end

    return object
end

local function SafeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = table.pack(...)

    task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(args, 1, args.n))
        end)

        if not success then
            warn("[Lua Test] Notification callback error:", err)
        end
    end)
end

function Notifications.new(options)
    local self = setmetatable({}, Notifications)

    self.Options = merge(DEFAULTS, options)

    self.Parent = nil
    self.Container = nil

    self.Active = {}
    self.Destroyed = false

    return self
end

function Notifications:_tween(object, properties, duration)
    if not object then
        return nil
    end

    if not self.Options.EnableAnimations then
        for property, value in pairs(properties) do
            pcall(function()
                object[property] = value
            end)
        end

        return nil
    end

    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or self.Options.AnimationTime,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        properties
    )

    tween:Play()

    return tween
end

function Notifications:_getColor(notificationType)
    return self.Options[notificationType]
        or self.Options.Info
end

function Notifications:Init(parent, options)
    if self.Container then
        self:Destroy()
    end

    self.Destroyed = false
    self.Parent = parent

    if options then
        self.Options = merge(
            self.Options,
            options
        )
    end

    if not parent then
        return self
    end

    local container = Create("Frame", {
        Name = "Notifications",

        AnchorPoint = Vector2.new(1, 1),

        Position = UDim2.new(
            1,
            -self.Options.Margin,
            1,
            -self.Options.Margin
        ),

        Size = UDim2.fromOffset(
            self.Options.Width + 20,
            500
        ),

        BackgroundTransparency = 1,

        BorderSizePixel = 0,

        Parent = parent
    })

    container.ZIndex = 500

    local layout = Create("UIListLayout", {
        Parent = container,

        FillDirection =
            Enum.FillDirection.Vertical,

        HorizontalAlignment =
            Enum.HorizontalAlignment.Right,

        VerticalAlignment =
            Enum.VerticalAlignment.Bottom,

        Padding =
            UDim.new(
                0,
                self.Options.Padding
            ),

        SortOrder =
            Enum.SortOrder.LayoutOrder
    })

    self.Container = container
    self.Layout = layout

    return self
end

function Notifications:_removeOldest()
    if #self.Active <= self.Options.MaxNotifications then
        return
    end

    local oldest = table.remove(
        self.Active,
        1
    )

    if oldest then
        self:_closeNotification(
            oldest,
            true
        )
    end
end

function Notifications:_removeNotification(notification)
    for index, item in ipairs(self.Active) do
        if item == notification then
            table.remove(
                self.Active,
                index
            )

            break
        end
    end
end

function Notifications:_closeNotification(
    notification,
    instant
)
    if not notification
        or notification.Closed then
        return
    end

    notification.Closed = true

    if notification.Connections then
        for _, connection in pairs(
            notification.Connections
        ) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        notification.Connections = {}
    end

    self:_removeNotification(
        notification
    )

    local frame = notification.Frame

    if not frame then
        return
    end

    if instant
        or not self.Options.EnableAnimations then

        frame:Destroy()
        return
    end

    local tween = self:_tween(
        frame,
        {
            Position =
                UDim2.new(
                    1,
                    30,
                    0,
                    0
                ),

            BackgroundTransparency = 1
        },
        self.Options.AnimationTime
    )

    if notification.Title then
        self:_tween(
            notification.Title,
            {
                TextTransparency = 1
            },
            self.Options.AnimationTime
        )
    end

    if notification.Message then
        self:_tween(
            notification.Message,
            {
                TextTransparency = 1
            },
            self.Options.AnimationTime
        )
    end

    if notification.Icon then
        self:_tween(
            notification.Icon,
            {
                TextTransparency = 1
            },
            self.Options.AnimationTime
        )
    end

    if notification.Close then
        self:_tween(
            notification.Close,
            {
                TextTransparency = 1
            },
            self.Options.AnimationTime
        )
    end

    if notification.Progress then
        self:_tween(
            notification.Progress,
            {
                BackgroundTransparency = 1
            },
            self.Options.AnimationTime
        )
    end

    if tween then
        tween.Completed:Wait()
    else
        task.wait(
            self.Options.AnimationTime
        )
    end

    if frame
        and frame.Parent then

        frame:Destroy()
    end
end

function Notifications:Close(notification)
    if not notification then
        return
    end

    self:_closeNotification(
        notification,
        false
    )
end

function Notifications:Show(
    message,
    duration,
    title,
    notificationType
)
    if type(duration) == "table" then
        local options = duration

        title =
            options.Title
            or title

        notificationType =
            options.Type
            or notificationType

        duration =
            options.Duration
            or self.Options.Duration

        message =
            options.Message
            or message
    end

    duration =
        tonumber(duration)
        or self.Options.Duration

    notificationType =
        notificationType
        or "Info"

    notificationType =
        tostring(notificationType)

    if not self.Container then
        warn(
            "[Lua Test] "
                .. tostring(message)
        )

        return nil
    end

    if self.Destroyed then
        return nil
    end

    self:_removeOldest()

    local accent =
        self:_getColor(
            notificationType
        )

    local notification = {
        Closed = false,
        Paused = false,
        Remaining = duration,
        Connections = {}
    }

    local frame = Create("Frame", {
        Size = UDim2.fromOffset(
            self.Options.Width,
            self.Options.Height
        ),

        BackgroundColor3 =
            self.Options.Background,

        BackgroundTransparency = 1,

        BorderSizePixel = 0,

        Position =
            UDim2.new(
                1,
                30,
                0,
                0
            ),

        Parent = self.Container
    })

    frame.ZIndex = 500

    notification.Frame = frame

    Create("UICorner", {
        CornerRadius =
            UDim.new(0, 9),

        Parent = frame
    })

    Create("UIStroke", {
        Color =
            self.Options.Border,

        Thickness = 1,

        Transparency = 0.25,

        Parent = frame
    })

    local accentBar = Create("Frame", {
        Position =
            UDim2.fromOffset(
                0,
                8
            ),

        Size =
            UDim2.fromOffset(
                3,
                self.Options.Height - 16
            ),

        BackgroundColor3 = accent,

        BorderSizePixel = 0,

        Parent = frame
    })

    accentBar.ZIndex = 501

    Create("UICorner", {
        CornerRadius =
            UDim.new(0, 3),

        Parent = accentBar
    })

    local icon = Create("TextLabel", {
        Position =
            UDim2.fromOffset(
                14,
                10
            ),

        Size =
            UDim2.fromOffset(
                26,
                26
            ),

        BackgroundColor3 = accent,

        BackgroundTransparency = 0.85,

        BorderSizePixel = 0,

        Font = Enum.Font.GothamBold,

        Text =
            notificationType == "Success"
                and "✓"
                or notificationType == "Warning"
                and "!"
                or notificationType == "Error"
                and "×"
                or "i",

        TextColor3 = accent,

        TextSize = 13,

        TextTransparency = 1,

        ZIndex = 501,

        Parent = frame
    })

    Create("UICorner", {
        CornerRadius =
            UDim.new(1, 0),

        Parent = icon
    })

    notification.Icon = icon

    local titleLabel = Create("TextLabel", {
        Position =
            UDim2.fromOffset(
                49,
                9
            ),

        Size =
            UDim2.new(
                1,
                -84,
                0,
                19
            ),

        BackgroundTransparency = 1,

        Font = Enum.Font.GothamBold,

        Text =
            tostring(
                title
                or notificationType
            ),

        TextColor3 =
            self.Options.Text,

        TextSize = 12,

        TextTransparency = 1,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        TextTruncate =
            Enum.TextTruncate.AtEnd,

        ZIndex = 501,

        Parent = frame
    })

    notification.Title = titleLabel

    local messageLabel = Create("TextLabel", {
        Position =
            UDim2.fromOffset(
                49,
                30
            ),

        Size =
            UDim2.new(
                1,
                -62,
                0,
                25
            ),

        BackgroundTransparency = 1,

        Font = Enum.Font.Gotham,

        Text =
            tostring(message or ""),

        TextColor3 =
            self.Options.MutedText,

        TextSize = 10,

        TextTransparency = 1,

        TextWrapped = true,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        TextYAlignment =
            Enum.TextYAlignment.Top,

        TextTruncate =
            Enum.TextTruncate.AtEnd,

        ZIndex = 501,

        Parent = frame
    })

    notification.Message = messageLabel

    local closeButton

    if self.Options.EnableCloseButton then
        closeButton = Create("TextButton", {
            AnchorPoint =
                Vector2.new(1, 0),

            Position =
                UDim2.new(
                    1,
                    -8,
                    0,
                    7
                ),

            Size =
                UDim2.fromOffset(
                    22,
                    22
                ),

            BackgroundTransparency = 1,

            Text = "×",

            Font =
                Enum.Font.GothamBold,

            TextSize = 17,

            TextColor3 =
                self.Options.MutedText,

            TextTransparency = 1,

            AutoButtonColor = false,

            ZIndex = 502,

            Parent = frame
        })

        notification.Close = closeButton

        table.insert(
            notification.Connections,
            closeButton.MouseButton1Click:Connect(
                function()
                    self:Close(
                        notification
                    )
                end
            )
        )

        table.insert(
            notification.Connections,
            closeButton.MouseEnter:Connect(
                function()
                    closeButton.TextColor3 =
                        self.Options.Text
                end
            )
        )

        table.insert(
            notification.Connections,
            closeButton.MouseLeave:Connect(
                function()
                    closeButton.TextColor3 =
                        self.Options.MutedText
                end
            )
        )
    end

    local progress

    if self.Options.EnableProgress then
        progress = Create("Frame", {
            Position =
                UDim2.new(
                    0,
                    0,
                    1,
                    -2
                ),

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    2
                ),

            BackgroundColor3 = accent,

            BorderSizePixel = 0,

            Parent = frame
        })

        progress.ZIndex = 502

        notification.Progress =
            progress
    end

    table.insert(
        self.Active,
        notification
    )

    self:_removeOldest()

    local targetPosition =
        UDim2.new(
            1,
            0,
            0,
            0
        )

    self:_tween(
        frame,
        {
            Position = targetPosition,
            BackgroundTransparency = 0
        }
    )

    self:_tween(
        titleLabel,
        {
            TextTransparency = 0
        }
    )

    self:_tween(
        messageLabel,
        {
            TextTransparency = 0
        }
    )

    self:_tween(
        icon,
        {
            TextTransparency = 0
        }
    )

    if closeButton then
        self:_tween(
            closeButton,
            {
                TextTransparency = 0
            }
        )
    end

    if progress then
        self:_tween(
            progress,
            {
                Size = UDim2.new(
                    1,
                    0,
                    0,
                    2
                )
            },
            0
        )
    end

    if self.Options.EnableHoverPause then
        table.insert(
            notification.Connections,
            frame.MouseEnter:Connect(
                function()
                    notification.Paused = true
                end
            )
        )

        table.insert(
            notification.Connections,
            frame.MouseLeave:Connect(
                function()
                    notification.Paused = false
                end
            )
        )
    end

    task.spawn(function()
        local elapsed = 0

        while notification
            and not notification.Closed
            and elapsed < duration do

            task.wait(0.05)

            if notification.Paused then
                continue
            end

            elapsed += 0.05
            notification.Remaining =
                math.max(
                    duration - elapsed,
                    0
                )

            if progress
                and progress.Parent then

                local alpha =
                    math.clamp(
                        notification.Remaining
                            / duration,
                        0,
                        1
                    )

                progress.Size =
                    UDim2.new(
                        alpha,
                        0,
                        0,
                        2
                    )
            end
        end

        if notification
            and not notification.Closed then

            self:_closeNotification(
                notification,
                false
            )
        end
    end)

    return notification
end

function Notifications:Info(
    title,
    message,
    duration
)
    return self:Show(
        message,
        duration or 3,
        title or "Information",
        "Info"
    )
end

function Notifications:Success(
    title,
    message,
    duration
)
    return self:Show(
        message,
        duration or 3,
        title or "Success",
        "Success"
    )
end

function Notifications:Warning(
    title,
    message,
    duration
)
    return self:Show(
        message,
        duration or 4,
        title or "Warning",
        "Warning"
    )
end

function Notifications:Error(
    title,
    message,
    duration
)
    return self:Show(
        message,
        duration or 5,
        title or "Error",
        "Error"
    )
end

function Notifications:Clear()
    for _, notification in ipairs(
        table.clone(self.Active)
    ) do
        self:_closeNotification(
            notification,
            false
        )
    end

    self.Active = {}
end

function Notifications:ClearAll()
    for _, notification in ipairs(
        table.clone(self.Active)
    ) do
        self:_closeNotification(
            notification,
            true
        )
    end

    self.Active = {}
end

function Notifications:SetTheme(theme)
    if type(theme) ~= "table" then
        return
    end

    for key, value in pairs(theme) do
        if self.Options[key] ~= nil then
            self.Options[key] = value
        end
    end

    for _, notification in ipairs(
        self.Active
    ) do
        if notification.Frame then
            notification.Frame.BackgroundColor3 =
                self.Options.Background
        end

        if notification.Title then
            notification.Title.TextColor3 =
                self.Options.Text
        end

        if notification.Message then
            notification.Message.TextColor3 =
                self.Options.MutedText
        end
    end
end

function Notifications:GetCount()
    return #self.Active
end

function Notifications:Destroy()
    self.Destroyed = true

    self:ClearAll()

    if self.Container then
        self.Container:Destroy()
    end

    self.Container = nil
    self.Layout = nil
    self.Parent = nil
    self.Active = {}
end

return Notifications
