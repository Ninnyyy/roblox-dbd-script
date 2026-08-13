local Notifications = {}

function Notifications:Init(parent)
    self.Parent = parent

    return self
end

function Notifications:Show(message, duration)
    duration = duration or 3

    if not self.Parent then
        warn("[Lua Test] " .. tostring(message))
        return
    end

    local notification = Instance.new("TextLabel")

    notification.Size = UDim2.new(0, 280, 0, 40)
    notification.BackgroundTransparency = 0.1
    notification.Text = tostring(message)
    notification.TextSize = 14
    notification.Parent = self.Parent

    task.delay(duration, function()
        if notification and notification.Parent then
            notification:Destroy()
        end
    end)

    return notification
end

return Notifications