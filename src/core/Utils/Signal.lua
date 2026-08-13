--[[
    Lua Test Script
    Signal.lua

    Internal event / signal system.

    Responsibilities:
        - Connect callbacks
        - Fire events
        - Once listeners
        - Wait for events
        - Disconnect listeners
        - Disconnect all listeners
        - Connection tracking
        - Safe callback execution
        - Optional Logger integration
        - Signal cloning
        - Signal state inspection
]]

local Signal = {
    Name = "Signal",
    Version = "2.0.0",

    Initialized = false,

    Logger = nil,

    Signals = {},
    TotalConnections = 0,
}



-- Internal Connection


local Connection = {}
Connection.__index = Connection


function Connection.new(
    signal,
    callback,
    once
)
    local self = setmetatable(
        {},
        Connection
    )

    self.Signal = signal
    self.Callback = callback
    self.Once = once == true
    self.Connected = true

    return self
end


function Connection:Disconnect()
    if not self.Connected then
        return false
    end

    self.Connected = false

    local signal =
        self.Signal

    if signal then
        signal:_RemoveConnection(
            self
        )
    end

    self.Signal = nil
    self.Callback = nil

    return true
end


function Connection:IsConnected()
    return self.Connected == true
end


function Connection:Destroy()
    return self:Disconnect()
end



-- Signal Object


local SignalObject = {}
SignalObject.__index = SignalObject


function SignalObject.new(
    name,
    logger
)
    local self = setmetatable(
        {},
        SignalObject
    )

    self.Name =
        type(name) == "string"
        and name
        or "Signal"

    self.Logger = logger

    self.Connections = {}

    self.ConnectionCount = 0

    self.Firing = false

    self.Destroyed = false

    return self
end



-- Helpers



function SignalObject:_Log(
    level,
    message,
    ...
)
    if not self.Logger then
        return
    end

    local method =
        self.Logger[level]

    if type(method) ~= "function" then
        return
    end

    pcall(
        method,
        self.Logger,
        self.Name,
        message,
        ...
    )
end


function SignalObject:_RemoveConnection(
    connection
)
    if not connection then
        return false
    end

    for index, current in ipairs(
        self.Connections
    ) do

        if current == connection then

            table.remove(
                self.Connections,
                index
            )

            self.ConnectionCount =
                math.max(
                    0,
                    self.ConnectionCount - 1
                )

            Signal.TotalConnections =
                math.max(
                    0,
                    Signal.TotalConnections - 1
                )

            return true
        end
    end

    return false
end


function SignalObject:_AddConnection(
    callback,
    once
)
    if self.Destroyed then
        return nil
    end

    if type(callback) ~= "function" then
        return nil
    end

    local connection =
        Connection.new(
            self,
            callback,
            once
        )

    table.insert(
        self.Connections,
        connection
    )

    self.ConnectionCount += 1

    Signal.TotalConnections += 1

    return connection
end



-- Connect



function SignalObject:Connect(
    callback
)
    return self:_AddConnection(
        callback,
        false
    )
end



-- Once



function SignalObject:Once(
    callback
)
    return self:_AddConnection(
        callback,
        true
    )
end



-- Fire



function SignalObject:Fire(...)
    if self.Destroyed then
        return false
    end

    if self.ConnectionCount <= 0 then
        return true
    end

    self.Firing = true

    local arguments = {
        ...
    }

    local snapshot = {}

    for index, connection in ipairs(
        self.Connections
    ) do

        snapshot[index] =
            connection
    end

    for _, connection in ipairs(
        snapshot
    ) do

        if connection
            and connection.Connected
            and type(connection.Callback)
                == "function" then

            if connection.Once then
                connection:Disconnect()
            end

            task.spawn(
                function()

                    local success, err =
                        pcall(
                            connection.Callback,
                            table.unpack(
                                arguments
                            )
                        )

                    if not success then

                        self:_Log(
                            "Error",
                            "Signal callback error:",
                            err
                        )

                    end
                end
            )
        end
    end

    self.Firing = false

    return true
end



-- Fire Synchronously



function SignalObject:FireSync(...)
    if self.Destroyed then
        return false
    end

    if self.ConnectionCount <= 0 then
        return true
    end

    self.Firing = true

    local arguments = {
        ...
    }

    local snapshot = {}

    for index, connection in ipairs(
        self.Connections
    ) do

        snapshot[index] =
            connection
    end

    for _, connection in ipairs(
        snapshot
    ) do

        if connection
            and connection.Connected
            and type(connection.Callback)
                == "function" then

            if connection.Once then
                connection:Disconnect()
            end

            local success, err =
                pcall(
                    connection.Callback,
                    table.unpack(
                        arguments
                    )
                )

            if not success then

                self:_Log(
                    "Error",
                    "Signal callback error:",
                    err
                )

            end
        end
    end

    self.Firing = false

    return true
end



-- Wait



function SignalObject:Wait(
    timeout
)
    if self.Destroyed then
        return nil
    end

    local thread =
        coroutine.running()

    if not thread then
        return nil
    end

    local connection

    local completed = false

    local function Resume(...)
        if completed then
            return
        end

        completed = true

        if connection then
            connection:Disconnect()
        end

        task.spawn(
            function()
                coroutine.resume(
                    thread,
                    ...
                )
            end
        )
    end

    connection =
        self:Connect(
            Resume
        )

    if not connection then
        return nil
    end

    if timeout ~= nil then

        timeout =
            tonumber(timeout)

        if timeout
            and timeout >= 0 then

            task.delay(
                timeout,
                function()

                    if completed then
                        return
                    end

                    completed = true

                    if connection then
                        connection:Disconnect()
                    end

                    task.spawn(
                        function()
                            coroutine.resume(
                                thread
                            )
                        end
                    )

                end
            )
        end
    end

    return coroutine.yield()
end



-- Disconnect



function SignalObject:Disconnect(
    connection
)
    if not connection then
        return false
    end

    if type(connection.Disconnect)
        ~= "function" then

        return false
    end

    return connection:Disconnect()
end



-- Disconnect All



function SignalObject:DisconnectAll()
    local connections = {}

    for index, connection in ipairs(
        self.Connections
    ) do

        connections[index] =
            connection
    end

    for _, connection in ipairs(
        connections
    ) do

        if connection then
            connection:Disconnect()
        end
    end

    return self
end



-- State



function SignalObject:GetConnectionCount()
    return self.ConnectionCount
end


function SignalObject:HasConnections()
    return self.ConnectionCount > 0
end


function SignalObject:IsFiring()
    return self.Firing == true
end


function SignalObject:IsDestroyed()
    return self.Destroyed == true
end


function SignalObject:GetName()
    return self.Name
end



-- Rename



function SignalObject:SetName(
    name
)
    if type(name) ~= "string"
        or name == "" then

        return false
    end

    self.Name = name

    return true
end



-- Clone



function SignalObject:Clone(
    name
)
    return SignalObject.new(
        name or self.Name,
        self.Logger
    )
end



-- Destroy



function SignalObject:Destroy()
    if self.Destroyed then
        return false
    end

    self:DisconnectAll()

    self.Destroyed = true

    self.Connections = {}

    self.ConnectionCount = 0

    self.Logger = nil

    return true
end



-- Signal Manager



function Signal:Create(
    name
)
    local signal =
        SignalObject.new(
            name,
            self.Logger
        )

    table.insert(
        self.Signals,
        signal
    )

    return signal
end


function Signal:Register(
    name
)
    if type(name) ~= "string"
        or name == "" then

        return nil
    end

    local existing =
        self:Get(
            name
        )

    if existing then
        return existing
    end

    local signal =
        self:Create(
            name
        )

    return signal
end


function Signal:Get(
    name
)
    if type(name) ~= "string" then
        return nil
    end

    for _, signal in ipairs(
        self.Signals
    ) do

        if signal
            and not signal:IsDestroyed()
            and signal:GetName() == name then

            return signal
        end
    end

    return nil
end


function Signal:Has(
    name
)
    return self:Get(name) ~= nil
end


function Signal:GetAll()
    local result = {}

    for _, signal in ipairs(
        self.Signals
    ) do

        if signal
            and not signal:IsDestroyed() then

            table.insert(
                result,
                signal
            )
        end
    end

    return result
end


function Signal:GetCount()
    local count = 0

    for _, signal in ipairs(
        self.Signals
    ) do

        if signal
            and not signal:IsDestroyed() then

            count += 1
        end
    end

    return count
end


function Signal:GetTotalConnections()
    return self.TotalConnections
end



-- Fire Named Signal



function Signal:Fire(
    name,
    ...
)
    local signal =
        self:Get(name)

    if not signal then
        return false,
            "Signal not found"
    end

    return signal:Fire(...)
end


function Signal:FireSync(
    name,
    ...
)
    local signal =
        self:Get(name)

    if not signal then
        return false,
            "Signal not found"
    end

    return signal:FireSync(...)
end



-- Connect Named Signal



function Signal:Connect(
    name,
    callback
)
    local signal =
        self:Get(name)

    if not signal then
        signal =
            self:Register(name)
    end

    if not signal then
        return nil
    end

    return signal:Connect(
        callback
    )
end


function Signal:Once(
    name,
    callback
)
    local signal =
        self:Get(name)

    if not signal then
        signal =
            self:Register(name)
    end

    if not signal then
        return nil
    end

    return signal:Once(
        callback
    )
end


function Signal:Wait(
    name,
    timeout
)
    local signal =
        self:Get(name)

    if not signal then
        signal =
            self:Register(name)
    end

    if not signal then
        return nil
    end

    return signal:Wait(
        timeout
    )
end



-- Destroy Signal



function Signal:Destroy(
    name
)
    local signal =
        self:Get(name)

    if not signal then
        return false
    end

    signal:Destroy()

    for index, current in ipairs(
        self.Signals
    ) do

        if current == signal then

            table.remove(
                self.Signals,
                index
            )

            break
        end
    end

    return true
end


function Signal:DestroyAll()
    local signals = {}

    for index, signal in ipairs(
        self.Signals
    ) do

        signals[index] =
            signal
    end

    for _, signal in ipairs(
        signals
    ) do

        if signal then
            signal:Destroy()
        end
    end

    self.Signals = {}

    self.TotalConnections = 0

    return self
end



-- Logger



function Signal:SetLogger(
    logger
)
    self.Logger = logger

    for _, signal in ipairs(
        self.Signals
    ) do

        if signal then
            signal.Logger = logger
        end
    end

    return self
end


function Signal:GetLogger()
    return self.Logger
end



-- Status



function Signal:GetStatus()
    local signalInfo = {}

    for _, signal in ipairs(
        self.Signals
    ) do

        if signal
            and not signal:IsDestroyed() then

            table.insert(
                signalInfo,
                {
                    Name =
                        signal:GetName(),

                    Connections =
                        signal:GetConnectionCount(),

                    Firing =
                        signal:IsFiring(),

                    Destroyed =
                        signal:IsDestroyed(),
                }
            )
        end
    end

    return {
        Name =
            self.Name,

        Version =
            self.Version,

        Initialized =
            self.Initialized,

        SignalCount =
            #signalInfo,

        TotalConnections =
            self.TotalConnections,

        Signals =
            signalInfo,
    }
end



-- Initialize



function Signal:Initialize(
    modules
)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Logger =
        modules.Logger

    self.Signals = {}

    self.TotalConnections = 0

    self.Initialized = true

    if self.Logger then
        self.Logger:Info(
            self.Name,
            "Signal system initialized",
            "Version:",
            self.Version
        )
    end

    return self
end



-- Reset



function Signal:Reset()
    self:DestroyAll()

    self.Signals = {}

    self.TotalConnections = 0

    return self
end



-- Destroy Manager



function Signal:Shutdown()
    self:DestroyAll()

    self.Logger = nil

    self.Initialized = false

    return self
end


return Signal