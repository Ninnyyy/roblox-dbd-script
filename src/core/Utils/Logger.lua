--[[
    Lua Test Script
    Logger.lua

    Centralized runtime logging system.

    Responsibilities:
        - Debug / Info / Success / Warn / Error logging
        - Log levels
        - Timestamps
        - Module/source names
        - Log history
        - History limits
        - Filtering
        - Runtime-safe logging
        - Config integration
        - Module-specific logger helpers
        - History export / clear
        - Enable / disable controls
        - Level filtering
        - Formatted output
]]

local Logger = {
    Name = "Logger",
    Version = "2.0.0",

    Initialized = false,

    Enabled = true,
    ConsoleEnabled = true,

    MinimumLevel = 1,

    MaxHistory = 500,

    History = {},

    Connections = nil,
    Config = nil,

    Prefix = "[Lua Test]",

    Counters = {
        Debug = 0,
        Info = 0,
        Success = 0,
        Warn = 0,
        Error = 0,
    },
}



-- Constants



Logger.Levels = {
    Debug = 1,
    Info = 2,
    Success = 3,
    Warn = 4,
    Error = 5,
}


Logger.LevelNames = {
    [1] = "Debug",
    [2] = "Info",
    [3] = "Success",
    [4] = "Warn",
    [5] = "Error",
}



-- Helpers



local function SafeToString(value)
    if value == nil then
        return "nil"
    end

    local success, result =
        pcall(
            tostring,
            value
        )

    if success then
        return result
    end

    return "<unprintable>"
end


local function GetClock()
    local success, result =
        pcall(
            os.clock
        )

    if success then
        return result
    end

    return 0
end


local function GetTime()
    local success, result =
        pcall(
            os.date,
            "%H:%M:%S"
        )

    if success then
        return result
    end

    return "00:00:00"
end


local function NormalizeLevel(level)
    if type(level) == "number" then
        if Logger.LevelNames[level] then
            return level
        end

        return Logger.Levels.Info
    end

    if type(level) == "string" then
        local normalized =
            string.lower(level)

        if normalized == "debug" then
            return Logger.Levels.Debug
        end

        if normalized == "info" then
            return Logger.Levels.Info
        end

        if normalized == "success" then
            return Logger.Levels.Success
        end

        if normalized == "warn"
            or normalized == "warning" then

            return Logger.Levels.Warn
        end

        if normalized == "error" then
            return Logger.Levels.Error
        end
    end

    return Logger.Levels.Info
end


local function NormalizeSource(source)
    if source == nil then
        return "Core"
    end

    source =
        SafeToString(source)

    if source == "" then
        return "Core"
    end

    return source
end


local function NormalizeMessage(message)
    if message == nil then
        return ""
    end

    return SafeToString(message)
end



-- Formatting



function Logger:GetLevelName(level)
    level =
        NormalizeLevel(level)

    return self.LevelNames[level]
        or "Info"
end


function Logger:GetLevelNumber(level)
    return NormalizeLevel(level)
end


function Logger:Format(entry)
    if type(entry) ~= "table" then
        return ""
    end

    local level =
        entry.LevelName
        or self:GetLevelName(
            entry.Level
        )

    local source =
        entry.Source
        or "Core"

    local message =
        entry.Message
        or ""

    return string.format(
        "%s [%s] [%s] %s",
        self.Prefix,
        level,
        source,
        message
    )
end


function Logger:FormatDetailed(entry)
    if type(entry) ~= "table" then
        return ""
    end

    local timestamp =
        entry.Timestamp
        or "00:00:00"

    local level =
        entry.LevelName
        or self:GetLevelName(
            entry.Level
        )

    local source =
        entry.Source
        or "Core"

    local message =
        entry.Message
        or ""

    return string.format(
        "%s %s [%s] [%s] %s",
        timestamp,
        self.Prefix,
        level,
        source,
        message
    )
end



-- Console Output



function Logger:_Output(entry)
    if not self.ConsoleEnabled then
        return
    end

    local level =
        NormalizeLevel(
            entry.Level
        )

    local message =
        self:Format(
            entry
        )

    if level == self.Levels.Error then

        warn(
            message
        )

        return
    end

    if level == self.Levels.Warn then

        warn(
            message
        )

        return
    end

    print(
        message
    )
end



-- History



function Logger:_AddHistory(entry)
    table.insert(
        self.History,
        entry
    )

    while #self.History >
        self.MaxHistory do

        table.remove(
            self.History,
            1
        )
    end
end


function Logger:GetHistory()
    local result = {}

    for index, entry in ipairs(
        self.History
    ) do

        result[index] = {
            Time =
                entry.Time,

            Timestamp =
                entry.Timestamp,

            Level =
                entry.Level,

            LevelName =
                entry.LevelName,

            Source =
                entry.Source,

            Message =
                entry.Message,
        }
    end

    return result
end


function Logger:GetHistoryCount()
    return #self.History
end


function Logger:ClearHistory()
    table.clear(
        self.History
    )

    return self
end


function Logger:GetLast()
    return self.History[
        #self.History
    ]
end


function Logger:GetRecent(amount)
    amount =
        tonumber(amount)
        or 10

    amount =
        math.max(
            0,
            math.floor(amount)
        )

    local result = {}

    local start =
        math.max(
            1,
            #self.History - amount + 1
        )

    for index = start,
        #self.History do

        table.insert(
            result,
            self.History[index]
        )
    end

    return result
end



-- Counters



function Logger:GetCount(level)
    if not level then
        local total = 0

        for _, count in pairs(
            self.Counters
        ) do
            total += count
        end

        return total
    end

    local levelName

    if type(level) == "number" then
        levelName =
            self:GetLevelName(
                level
            )
    else
        levelName =
            self:GetLevelName(
                level
            )
    end

    return self.Counters[
        levelName
    ] or 0
end


function Logger:GetCounters()
    local result = {}

    for name, count in pairs(
        self.Counters
    ) do

        result[name] = count
    end

    return result
end


function Logger:ResetCounters()
    for name in pairs(
        self.Counters
    ) do

        self.Counters[name] = 0
    end

    return self
end



-- Core Logging



function Logger:Log(
    level,
    source,
    message,
    ...
)
    if not self.Enabled then
        return false
    end

    level =
        NormalizeLevel(
            level
        )

    if level <
        self.MinimumLevel then

        return false
    end

    source =
        NormalizeSource(
            source
        )

    message =
        NormalizeMessage(
            message
        )

    local arguments = {
        ...
    }

    if #arguments > 0 then

        local formatted = {}

        for index, value in ipairs(
            arguments
        ) do

            table.insert(
                formatted,
                SafeToString(value)
            )
        end

        message =
            message
            .. " "
            .. table.concat(
                formatted,
                " "
            )
    end

    local levelName =
        self:GetLevelName(
            level
        )

    local entry = {
        Time =
            GetClock(),

        Timestamp =
            GetTime(),

        Level =
            level,

        LevelName =
            levelName,

        Source =
            source,

        Message =
            message,
    }

    self.Counters[levelName] =
        (
            self.Counters[levelName]
            or 0
        ) + 1

    self:_AddHistory(
        entry
    )

    self:_Output(
        entry
    )

    return true,
        entry
end



-- Standard Log Methods



function Logger:Debug(
    source,
    message,
    ...
)
    return self:Log(
        self.Levels.Debug,
        source,
        message,
        ...
    )
end


function Logger:Info(
    source,
    message,
    ...
)
    return self:Log(
        self.Levels.Info,
        source,
        message,
        ...
    )
end


function Logger:Success(
    source,
    message,
    ...
)
    return self:Log(
        self.Levels.Success,
        source,
        message,
        ...
    )
end


function Logger:Warn(
    source,
    message,
    ...
)
    return self:Log(
        self.Levels.Warn,
        source,
        message,
        ...
    )
end


function Logger:Error(
    source,
    message,
    ...
)
    return self:Log(
        self.Levels.Error,
        source,
        message,
        ...
    )
end



-- Convenience Methods



function Logger:Print(
    source,
    message,
    ...
)
    return self:Info(
        source,
        message,
        ...
    )
end


function Logger:Warning(
    source,
    message,
    ...
)
    return self:Warn(
        source,
        message,
        ...
    )
end


function Logger:Critical(
    source,
    message,
    ...
)
    return self:Error(
        source,
        message,
        ...
    )
end



-- Safe Logging



function Logger:Safe(
    source,
    callback,
    ...
)
    if type(callback) ~= "function" then
        return false,
            "Callback must be a function"
    end

    local success, result =
        pcall(
            callback,
            ...
        )

    if success then
        return true,
            result
    end

    self:Error(
        source,
        "Runtime error:",
        result
    )

    return false,
        result
end


function Logger:Assert(
    source,
    condition,
    message
)
    if condition then
        return true
    end

    self:Error(
        source,
        message
            or "Assertion failed"
    )

    return false
end



-- Source / Module Logger



function Logger:For(source)
    source =
        NormalizeSource(
            source
        )

    local logger = {}

    logger.Source = source

    function logger:Debug(
        message,
        ...
    )
        return Logger:Debug(
            self.Source,
            message,
            ...
        )
    end

    function logger:Info(
        message,
        ...
    )
        return Logger:Info(
            self.Source,
            message,
            ...
        )
    end

    function logger:Success(
        message,
        ...
    )
        return Logger:Success(
            self.Source,
            message,
            ...
        )
    end

    function logger:Warn(
        message,
        ...
    )
        return Logger:Warn(
            self.Source,
            message,
            ...
        )
    end

    function logger:Error(
        message,
        ...
    )
        return Logger:Error(
            self.Source,
            message,
            ...
        )
    end

    function logger:Safe(
        callback,
        ...
    )
        return Logger:Safe(
            self.Source,
            callback,
            ...
        )
    end

    function logger:Assert(
        condition,
        message
    )
        return Logger:Assert(
            self.Source,
            condition,
            message
        )
    end

    return logger
end



-- Filtering



function Logger:SetMinimumLevel(level)
    local normalized =
        NormalizeLevel(
            level
        )

    self.MinimumLevel =
        normalized

    return true
end


function Logger:GetMinimumLevel()
    return self.MinimumLevel
end


function Logger:GetMinimumLevelName()
    return self:GetLevelName(
        self.MinimumLevel
    )
end


function Logger:IsLevelEnabled(level)
    level =
        NormalizeLevel(
            level
        )

    return self.Enabled
        and level >= self.MinimumLevel
end



-- Enable / Disable



function Logger:Enable()
    self.Enabled = true

    return self
end


function Logger:Disable()
    self.Enabled = false

    return self
end


function Logger:IsEnabled()
    return self.Enabled == true
end


function Logger:SetEnabled(enabled)
    self.Enabled =
        enabled == true

    return self
end


function Logger:SetConsoleEnabled(enabled)
    self.ConsoleEnabled =
        enabled == true

    return self
end


function Logger:IsConsoleEnabled()
    return self.ConsoleEnabled == true
end



-- History Settings



function Logger:SetMaxHistory(amount)
    amount =
        tonumber(amount)

    if not amount then
        return false,
            "Amount must be a number"
    end

    amount =
        math.max(
            0,
            math.floor(amount)
        )

    self.MaxHistory =
        amount

    while #self.History >
        self.MaxHistory do

        table.remove(
            self.History,
            1
        )
    end

    return true
end


function Logger:GetMaxHistory()
    return self.MaxHistory
end



-- Searching



function Logger:Find(
    query,
    options
)
    if query == nil then
        return {}
    end

    query =
        string.lower(
            SafeToString(query)
        )

    options =
        options or {}

    local source =
        options.Source

    local level =
        options.Level

    local results = {}

    for _, entry in ipairs(
        self.History
    ) do

        local matchesQuery =
            string.find(
                string.lower(
                    entry.Message
                ),
                query,
                1,
                true
            ) ~= nil

        if not matchesQuery then
            matchesQuery =
                string.find(
                    string.lower(
                        entry.Source
                    ),
                    query,
                    1,
                    true
                ) ~= nil
        end

        local matchesSource = true

        if source then
            matchesSource =
                string.lower(
                    entry.Source
                )
                ==
                string.lower(
                    SafeToString(
                        source
                    )
                )
        end

        local matchesLevel = true

        if level then
            matchesLevel =
                entry.Level
                ==
                NormalizeLevel(
                    level
                )
        end

        if matchesQuery
            and matchesSource
            and matchesLevel then

            table.insert(
                results,
                entry
            )
        end
    end

    return results
end


function Logger:GetByLevel(level)
    local normalized =
        NormalizeLevel(
            level
        )

    local results = {}

    for _, entry in ipairs(
        self.History
    ) do

        if entry.Level ==
            normalized then

            table.insert(
                results,
                entry
            )
        end
    end

    return results
end


function Logger:GetBySource(source)
    source =
        NormalizeSource(
            source
        )

    local results = {}

    for _, entry in ipairs(
        self.History
    ) do

        if entry.Source ==
            source then

            table.insert(
                results,
                entry
            )
        end
    end

    return results
end



-- Export



function Logger:Export()
    return self:GetHistory()
end


function Logger:ExportFormatted(
    detailed
)
    local result = {}

    for _, entry in ipairs(
        self.History
    ) do

        if detailed then
            table.insert(
                result,
                self:FormatDetailed(
                    entry
                )
            )
        else
            table.insert(
                result,
                self:Format(
                    entry
                )
            )
        end
    end

    return result
end



-- Configuration



function Logger:Configure(options)
    if type(options) ~= "table" then
        return false,
            "Options must be a table"
    end

    if options.Enabled ~= nil then
        self.Enabled =
            options.Enabled == true
    end

    if options.ConsoleEnabled ~= nil then
        self.ConsoleEnabled =
            options.ConsoleEnabled == true
    end

    if options.MinimumLevel ~= nil then
        self:SetMinimumLevel(
            options.MinimumLevel
        )
    end

    if options.MaxHistory ~= nil then
        self:SetMaxHistory(
            options.MaxHistory
        )
    end

    if options.Prefix ~= nil then
        self.Prefix =
            SafeToString(
                options.Prefix
            )
    end

    return true
end


function Logger:GetConfig()
    return {
        Enabled =
            self.Enabled,

        ConsoleEnabled =
            self.ConsoleEnabled,

        MinimumLevel =
            self.MinimumLevel,

        MinimumLevelName =
            self:GetMinimumLevelName(),

        MaxHistory =
            self.MaxHistory,

        Prefix =
            self.Prefix,
    }
end



-- Config Integration



function Logger:BindConfig(config)
    if not config then
        return false,
            "Config unavailable"
    end

    self.Config =
        config

    local debugEnabled =
        config:Get(
            "General.Debug",
            false
        )

    if debugEnabled then
        self:SetMinimumLevel(
            self.Levels.Debug
        )
    else
        self:SetMinimumLevel(
            self.Levels.Info
        )
    end

    local notifications =
        config:Get(
            "General.Notifications",
            true
        )

    if notifications == false then
        self:SetConsoleEnabled(
            false
        )
    end

    return true
end


function Logger:RefreshConfig()
    if not self.Config then
        return false
    end

    local debugEnabled =
        self.Config:Get(
            "General.Debug",
            false
        )

    if debugEnabled then
        self:SetMinimumLevel(
            self.Levels.Debug
        )
    else
        self:SetMinimumLevel(
            self.Levels.Info
        )
    end

    local notifications =
        self.Config:Get(
            "General.Notifications",
            true
        )

    self:SetConsoleEnabled(
        notifications ~= false
    )

    return true
end



-- Status



function Logger:GetStatus()
    return {
        Name =
            self.Name,

        Version =
            self.Version,

        Initialized =
            self.Initialized,

        Enabled =
            self.Enabled,

        ConsoleEnabled =
            self.ConsoleEnabled,

        MinimumLevel =
            self.MinimumLevel,

        MinimumLevelName =
            self:GetMinimumLevelName(),

        MaxHistory =
            self.MaxHistory,

        HistoryCount =
            #self.History,

        Counters =
            self:GetCounters(),
    }
end



-- Initialization



function Logger:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Config =
        modules.Config

    self.Connections =
        modules.Connections

    self.History = {}

    self:ResetCounters()

    if self.Config then
        self:BindConfig(
            self.Config
        )
    end

    self.Initialized = true

    self:Info(
        self.Name,
        "Logger initialized",
        "Version:",
        self.Version
    )

    return self
end



-- Reset



function Logger:Reset()
    self.History = {}

    self:ResetCounters()

    return self
end



-- Destroy



function Logger:Destroy()
    self.History = {}

    self:ResetCounters()

    self.Config = nil
    self.Connections = nil

    self.Initialized = false

    return self
end


return Logger