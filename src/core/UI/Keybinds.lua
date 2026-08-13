local Keybinds = {}
Keybinds.__index = Keybinds

local UserInputService = game:GetService("UserInputService")

function Keybinds.new(connections)
    local self = setmetatable({}, Keybinds)

    self.Connections = connections
    self.Bindings = {}
    self.Listening = nil

    return self
end

function Keybinds:Bind(name, keyCode, callback)
    self.Bindings[name] = {
        KeyCode = keyCode,
        Callback = callback,
        Enabled = true
    }
end

function Keybinds:Unbind(name)
    self.Bindings[name] = nil
end

function Keybinds:SetEnabled(name, enabled)
    local binding = self.Bindings[name]

    if binding then
        binding.Enabled = enabled
    end
end

function Keybinds:Get(name)
    return self.Bindings[name]
end

function Keybinds:Start()
    if self.Connection then
        self.Connection:Disconnect()
    end

    self.Connection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if self.Listening then
            return
        end

        for _, binding in pairs(self.Bindings) do
            if binding.Enabled and binding.KeyCode == input.KeyCode then
                if binding.Callback then
                    task.spawn(binding.Callback)
                end
            end
        end
    end)

    if self.Connections then
        self.Connections:Add("Keybinds", self.Connection)
    end

    return self
end

function Keybinds:Listen(callback)
    self.Listening = callback
end

function Keybinds:StopListening()
    self.Listening = nil
end

function Keybinds:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    self.Bindings = {}
    self.Listening = nil
end

return Keybinds