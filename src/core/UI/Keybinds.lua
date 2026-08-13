local Keybinds = {}
Keybinds.__index = Keybinds

local UserInputService = game:GetService("UserInputService")

local DEFAULTS = {
    IgnoreProcessed = true,
    AllowMouse = true,
    AllowGamepad = true,
    AllowKeyboard = true,

    PreventDuplicateKeys = false,
    TriggerOnInputEnded = false,

    AllowUnknown = false,
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

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = table.pack(...)

    task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(args, 1, args.n))
        end)

        if not success then
            warn(
                "[Lua Test] Keybind callback error:",
                err
            )
        end
    end)
end

local function isInputAllowed(input, options)
    local inputType = input.UserInputType

    if inputType == Enum.UserInputType.Keyboard then
        return options.AllowKeyboard
    end

    if inputType == Enum.UserInputType.MouseButton1
        or inputType == Enum.UserInputType.MouseButton2
        or inputType == Enum.UserInputType.MouseButton3 then

        return options.AllowMouse
    end

    if inputType == Enum.UserInputType.Gamepad1
        or inputType == Enum.UserInputType.Gamepad2
        or inputType == Enum.UserInputType.Gamepad3
        or inputType == Enum.UserInputType.Gamepad4
        or inputType == Enum.UserInputType.Gamepad5
        or inputType == Enum.UserInputType.Gamepad6
        or inputType == Enum.UserInputType.Gamepad7
        or inputType == Enum.UserInputType.Gamepad8 then

        return options.AllowGamepad
    end

    return false
end

function Keybinds.new(connections, options)
    local self =
        setmetatable({}, Keybinds)

    self.Connections = connections

    self.Options =
        merge(
            DEFAULTS,
            options
        )

    self.Bindings = {}

    self.Listening = false
    self.ListeningName = nil
    self.ListenCallback = nil

    self.ConnectionBegan = nil
    self.ConnectionEnded = nil

    self.Started = false
    self.Destroyed = false

    self._nextId = 0

    return self
end

function Keybinds:_newId()
    self._nextId += 1

    return self._nextId
end

function Keybinds:_isValidInput(input)
    if not input then
        return false
    end

    if not isInputAllowed(
        input,
        self.Options
    ) then
        return false
    end

    if input.UserInputType
        == Enum.UserInputType.Keyboard then

        if input.KeyCode
            == Enum.KeyCode.Unknown
            and not self.Options.AllowUnknown then

            return false
        end
    end

    return true
end

function Keybinds:_getInputCode(input)
    if input.UserInputType
        == Enum.UserInputType.Keyboard then

        return input.KeyCode
    end

    return input.UserInputType
end

function Keybinds:_sameInput(a, b)
    if not a or not b then
        return false
    end

    return a == b
end

function Keybinds:_hasConflict(
    name,
    inputCode
)
    if not inputCode then
        return false
    end

    for bindingName, binding in
        pairs(self.Bindings) do

        if bindingName ~= name
            and binding.Enabled
            and self:_sameInput(
                binding.KeyCode,
                inputCode
            ) then

            return bindingName
        end
    end

    return false
end

function Keybinds:Bind(
    name,
    keyCode,
    callback,
    options
)
    if type(name) ~= "string"
        or name == "" then

        return false
    end

    options = options or {}

    if self.Bindings[name] then
        self:Unbind(name)
    end

    if keyCode == nil
        and options.RequireKey ~= false then

        -- Allow a binding to start unassigned.
        keyCode = nil
    end

    if self.Options.PreventDuplicateKeys
        and keyCode then

        local conflict =
            self:_hasConflict(
                name,
                keyCode
            )

        if conflict then
            return false, conflict
        end
    end

    local binding = {
        Id = self:_newId(),

        Name = name,

        KeyCode = keyCode,

        Callback = callback,

        Enabled =
            options.Enabled ~= false,

        TriggerOnEnded =
            options.TriggerOnEnded
            == true
            or self.Options.TriggerOnInputEnded,

        IgnoreProcessed =
            options.IgnoreProcessed
            ~= nil
            and options.IgnoreProcessed
            or self.Options.IgnoreProcessed,

        Metadata =
            options.Metadata
    }

    self.Bindings[name] = binding

    return true, binding
end

function Keybinds:Rebind(
    name,
    keyCode
)
    local binding =
        self.Bindings[name]

    if not binding then
        return false
    end

    if self.Options.PreventDuplicateKeys
        and keyCode then

        local conflict =
            self:_hasConflict(
                name,
                keyCode
            )

        if conflict then
            return false, conflict
        end
    end

    binding.KeyCode = keyCode

    return true
end

function Keybinds:Unbind(name)
    if not self.Bindings[name] then
        return false
    end

    self.Bindings[name] = nil

    if self.ListeningName == name then
        self:CancelListening()
    end

    return true
end

function Keybinds:Clear()
    self.Bindings = {}

    self:CancelListening()

    return true
end

function Keybinds:SetEnabled(
    name,
    enabled
)
    local binding =
        self.Bindings[name]

    if not binding then
        return false
    end

    binding.Enabled =
        enabled == true

    return true
end

function Keybinds:Toggle(name)
    local binding =
        self.Bindings[name]

    if not binding then
        return false
    end

    binding.Enabled =
        not binding.Enabled

    return binding.Enabled
end

function Keybinds:IsEnabled(name)
    local binding =
        self.Bindings[name]

    if not binding then
        return false
    end

    return binding.Enabled
end

function Keybinds:Get(name)
    return self.Bindings[name]
end

function Keybinds:GetKey(name)
    local binding =
        self.Bindings[name]

    if not binding then
        return nil
    end

    return binding.KeyCode
end

function Keybinds:GetAll()
    return self.Bindings
end

function Keybinds:GetCount()
    local count = 0

    for _ in pairs(self.Bindings) do
        count += 1
    end

    return count
end

function Keybinds:GetByKey(keyCode)
    local results = {}

    for name, binding in
        pairs(self.Bindings) do

        if binding.KeyCode == keyCode then
            table.insert(
                results,
                binding
            )
        end
    end

    return results
end

function Keybinds:FindConflict(
    keyCode,
    ignoreName
)
    for name, binding in
        pairs(self.Bindings) do

        if name ~= ignoreName
            and binding.Enabled
            and binding.KeyCode
                == keyCode then

            return binding
        end
    end

    return nil
end

function Keybinds:_trigger(
    binding,
    input
)
    if not binding
        or not binding.Enabled then

        return false
    end

    if not binding.KeyCode then
        return false
    end

    local inputCode =
        self:_getInputCode(input)

    if inputCode ~= binding.KeyCode then
        return false
    end

    safeCallback(
        binding.Callback,
        input,
        binding
    )

    return true
end

function Keybinds:HandleInput(
    input,
    processed,
    ended
)
    if self.Destroyed then
        return false
    end

    if not self:_isValidInput(input) then
        return false
    end

    if self.Listening then
        return self:HandleListening(
            input,
            processed
        )
    end

    for _, binding in
        pairs(self.Bindings) do

        if binding.Enabled then
            local shouldIgnore =
                processed
                and binding.IgnoreProcessed

            if not shouldIgnore then
                local shouldTrigger =
                    binding.TriggerOnEnded
                    == ended

                if shouldTrigger then
                    self:_trigger(
                        binding,
                        input
                    )
                end
            end
        end
    end

    return true
end

function Keybinds:Start()
    if self.Destroyed then
        return self
    end

    self:Stop()

    self.Started = true

    self.ConnectionBegan =
        UserInputService.InputBegan:Connect(
            function(input, processed)
                self:HandleInput(
                    input,
                    processed,
                    false
                )
            end
        )

    self.ConnectionEnded =
        UserInputService.InputEnded:Connect(
            function(input, processed)
                self:HandleInput(
                    input,
                    processed,
                    true
                )
            end
        )

    if self.Connections
        and self.Connections.Add then

        self.Connections:Add(
            "Keybinds_Began",
            self.ConnectionBegan
        )

        self.Connections:Add(
            "Keybinds_Ended",
            self.ConnectionEnded
        )
    end

    return self
end

function Keybinds:Stop()
    if self.ConnectionBegan then
        self.ConnectionBegan:Disconnect()
        self.ConnectionBegan = nil
    end

    if self.ConnectionEnded then
        self.ConnectionEnded:Disconnect()
        self.ConnectionEnded = nil
    end

    self.Started = false

    return self
end

function Keybinds:IsStarted()
    return self.Started
end

function Keybinds:Listen(
    name,
    callback,
    options
)
    options = options or {}

    if type(name) ~= "string"
        or name == "" then

        return false
    end

    if not self.Bindings[name] then
        return false
    end

    if self.Listening then
        self:CancelListening()
    end

    self.Listening = true
    self.ListeningName = name
    self.ListenCallback = callback

    self.ListenOptions = options

    return true
end

function Keybinds:CancelListening()
    self.Listening = false
    self.ListeningName = nil
    self.ListenCallback = nil
    self.ListenOptions = nil
end

function Keybinds:StopListening()
    self:CancelListening()
end

function Keybinds:IsListening()
    return self.Listening
end

function Keybinds:GetListeningName()
    return self.ListeningName
end

function Keybinds:HandleListening(
    input,
    processed
)
    if not self.Listening then
        return false
    end

    if not self:_isValidInput(input) then
        return false
    end

    local options =
        self.ListenOptions
        or {}

    if processed
        and options.IgnoreProcessed ~= false then

        return false
    end

    local inputCode =
        self:_getInputCode(input)

    if inputCode == Enum.KeyCode.Escape
        and options.AllowEscape ~= true then

        self:CancelListening()

        return true
    end

    local name =
        self.ListeningName

    local callback =
        self.ListenCallback

    if name
        and self.Bindings[name] then

        local conflict =
            self:_hasConflict(
                name,
                inputCode
            )

        if conflict
            and (
                options.AllowConflict
                ~= true
            ) then

            safeCallback(
                callback,
                nil,
                conflict
            )

            return true
        end

        self.Bindings[name].KeyCode =
            inputCode
    end

    self:CancelListening()

    safeCallback(
        callback,
        inputCode
    )

    return true
end

function Keybinds:WaitForKey(
    name,
    timeout
)
    if not self.Bindings[name] then
        return nil
    end

    local finished = false
    local result = nil

    self:Listen(
        name,
        function(keyCode)
            result = keyCode
            finished = true
        end
    )

    local start = os.clock()

    while not finished do
        if self.Destroyed then
            break
        end

        if timeout
            and os.clock() - start >= timeout then

            self:CancelListening()
            break
        end

        task.wait()
    end

    return result
end

function Keybinds:Fire(
    name,
    ...)
    local binding =
        self.Bindings[name]

    if not binding
        or not binding.Enabled then

        return false
    end

    safeCallback(
        binding.Callback,
        ...
    )

    return true
end

function Keybinds:SetOptions(options)
    if type(options) ~= "table" then
        return false
    end

    self.Options =
        merge(
            self.Options,
            options
        )

    return true
end

function Keybinds:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    self:Stop()
    self:CancelListening()

    self.Bindings = {}
    self.Connections = nil
end

return Keybinds