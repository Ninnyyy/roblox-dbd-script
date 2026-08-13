--[[
    Lua Test Script
    Utils/Init.lua

    Utility bootstrap / manager.

    Responsibilities:
        - Load utility modules
        - Expose utility modules
        - Initialize utility modules
        - Setup utility modules
        - Provide utility lookup
        - Track utility load errors
        - Track initialization state
        - Provide runtime status
        - Safely destroy utility modules
]]

local Utils = {
    Name = "Utils",
    Version = "3.0.0",

    Initialized = false,
    Running = false,

    BaseURL =
        "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/",

    Modules = {},

    Helpers = nil,
    Math = nil,
    Players = nil,

    Errors = {},
}



-- INTERNAL STATE


local LoadedPaths = {}



-- SAFE STRING


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



-- ERROR TRACKING


local function RecordError(
    path,
    message
)

    table.insert(
        Utils.Errors,
        {
            Path = path,
            Error = SafeToString(message),
        }
    )
end



-- REMOTE LOADER


local function LoadRemote(
    path
)

    if type(path) ~= "string"
        or path == "" then

        error(
            "Invalid utility module path"
        )
    end

    if LoadedPaths[path] ~= nil then
        return LoadedPaths[path]
    end

    local url =
        Utils.BaseURL .. path

    local requestSuccess, source =
        pcall(
            function()
                return game:HttpGet(
                    url,
                    true
                )
            end
        )

    if not requestSuccess then

        RecordError(
            path,
            source
        )

        error(
            "Failed to download utility module '"
                .. path
                .. "': "
                .. SafeToString(source)
        )
    end

    if type(source) ~= "string"
        or source == "" then

        local message =
            "Empty source returned for utility module: "
                .. path

        RecordError(
            path,
            message
        )

        error(message)
    end

    local loader,
        compileError =
        loadstring(source)

    if type(loader) ~= "function" then

        local message =
            "Failed to compile utility module '"
                .. path
                .. "': "
                .. SafeToString(
                    compileError
                )

        RecordError(
            path,
            message
        )

        error(message)
    end

    local executeSuccess,
        module =
        pcall(loader)

    if not executeSuccess then

        RecordError(
            path,
            module
        )

        error(
            "Utility module execution failed '"
                .. path
                .. "': "
                .. SafeToString(module)
        )
    end

    if module == nil then

        local message =
            "Utility module returned nil: "
                .. path

        RecordError(
            path,
            message
        )

        error(message)
    end

    LoadedPaths[path] =
        module

    return module
end



-- SAFE INITIALIZE


local function SafeInitialize(
    module,
    ...
)

    if type(module) ~= "table" then
        return true
    end

    if type(module.Initialize)
        ~= "function" then

        return true
    end

    local success,
        result =
        pcall(
            function()
                return module:Initialize(...)
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Utility rejected initialization"
    end

    return true, result
end



-- SAFE SETUP


local function SafeSetup(
    module,
    ...
)

    if type(module) ~= "table" then
        return true
    end

    if type(module.Setup)
        ~= "function" then

        return true
    end

    local success,
        result =
        pcall(
            function()
                return module:Setup(...)
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Utility rejected setup"
    end

    return true, result
end



-- SAFE START


local function SafeStart(
    module
)

    if type(module) ~= "table" then
        return true
    end

    if type(module.Start)
        ~= "function" then

        return true
    end

    local success,
        result =
        pcall(
            function()
                return module:Start()
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Utility rejected start"
    end

    return true, result
end



-- SAFE STOP


local function SafeStop(
    module
)

    if type(module) ~= "table" then
        return true
    end

    if type(module.Stop)
        ~= "function" then

        return true
    end

    local success,
        result =
        pcall(
            function()
                return module:Stop()
            end
        )

    if not success then
        return false, result
    end

    return true, result
end



-- SAFE DESTROY


local function SafeDestroy(
    module
)

    if type(module) ~= "table" then
        return true
    end

    if type(module.Destroy)
        ~= "function" then

        return true
    end

    local success,
        result =
        pcall(
            function()
                return module:Destroy()
            end
        )

    if not success then
        return false, result
    end

    return true, result
end



-- LOAD MODULES


local function LoadModules()

    Utils.Helpers =
        LoadRemote(
            "src/core/Utils/Helpers.lua"
        )

    Utils.Math =
        LoadRemote(
            "src/core/Utils/Math.lua"
        )

    Utils.Players =
        LoadRemote(
            "src/core/Utils/Players.lua"
        )

    Utils.Modules = {
        Helpers =
            Utils.Helpers,

        Math =
            Utils.Math,

        Players =
            Utils.Players,
    }
end



-- BUILD CONTEXT


local function BuildContext()

    return {
        Utils =
            Utils,

        Modules =
            Utils.Modules,

        Helpers =
            Utils.Helpers,

        Math =
            Utils.Math,

        Players =
            Utils.Players,
    }
end



-- INITIALIZE MODULES


local function InitializeModules()

    local context =
        BuildContext()

    for name, module in pairs(
        Utils.Modules
    ) do

        if type(module) == "table" then

            local success,
                errorMessage =
                SafeInitialize(
                    module,
                    context
                )

            if not success then

                RecordError(
                    name,
                    errorMessage
                )

                warn(
                    "[Lua Test] Utility initialization failed:",
                    name,
                    errorMessage
                )
            end
        end
    end
end



-- SETUP MODULES


local function SetupModules()

    local context =
        BuildContext()

    for name, module in pairs(
        Utils.Modules
    ) do

        if type(module) == "table" then

            local success,
                errorMessage =
                SafeSetup(
                    module,
                    context
                )

            if not success then

                RecordError(
                    name,
                    errorMessage
                )

                warn(
                    "[Lua Test] Utility setup failed:",
                    name,
                    errorMessage
                )
            end
        end
    end
end



-- START MODULES


local function StartModules()

    for name, module in pairs(
        Utils.Modules
    ) do

        if type(module) == "table" then

            local success,
                errorMessage =
                SafeStart(
                    module
                )

            if not success then

                RecordError(
                    name,
                    errorMessage
                )

                warn(
                    "[Lua Test] Utility start failed:",
                    name,
                    errorMessage
                )
            end
        end
    end
end



-- PUBLIC API


function Utils:Get(
    name
)

    if type(name) ~= "string" then
        return nil
    end

    return self.Modules[name]
end


function Utils:GetModule(
    name
)

    return self:Get(name)
end


function Utils:Has(
    name
)

    return self:Get(name) ~= nil
end


function Utils:GetHelpers()

    return self.Helpers
end


function Utils:GetMath()

    return self.Math
end


function Utils:GetPlayers()

    return self.Players
end


function Utils:GetErrors()

    local result = {}

    for index, item in ipairs(
        self.Errors
    ) do

        result[index] = {
            Path = item.Path,
            Error = item.Error,
        }
    end

    return result
end


function Utils:GetStatus()

    local moduleStatus = {}

    for name, module in pairs(
        self.Modules
    ) do

        local status = {
            Loaded = module ~= nil,
        }

        if type(module) == "table" then

            if type(module.IsInitialized)
                == "function" then

                local success,
                    initialized =
                    pcall(
                        function()
                            return module:IsInitialized()
                        end
                    )

                if success then
                    status.Initialized =
                        initialized
                end

            elseif module.Initialized ~= nil then

                status.Initialized =
                    module.Initialized
            end

            if type(module.IsRunning)
                == "function" then

                local success,
                    running =
                    pcall(
                        function()
                            return module:IsRunning()
                        end
                    )

                if success then
                    status.Running =
                        running
                end

            elseif module.Running ~= nil then

                status.Running =
                    module.Running
            end
        end

        moduleStatus[name] =
            status
    end

    return {
        Name =
            self.Name,

        Version =
            self.Version,

        Initialized =
            self.Initialized,

        Running =
            self.Running,

        Modules =
            moduleStatus,

        Errors =
            self:GetErrors(),
    }
end


function Utils:IsInitialized()

    return self.Initialized == true
end


function Utils:IsRunning()

    return self.Running == true
end



-- START


function Utils:Start()

    if self.Running then
        return true
    end

    if not self.Initialized then

        local success,
            errorMessage =
            self:Initialize()

        if not success then
            return false,
                errorMessage
        end
    end

    StartModules()

    self.Running = true

    return true
end



-- INITIALIZE


function Utils:Initialize()

    if self.Initialized then
        return true
    end

    local success,
        errorMessage =
        pcall(function()

            LoadModules()

            InitializeModules()

            SetupModules()

        end)

    if not success then

        RecordError(
            "Utils/Init.lua",
            errorMessage
        )

        return false,
            errorMessage
    end

    self.Initialized =
        true

    return true
end



-- STOP


function Utils:Stop()

    if not self.Running then
        return true
    end

    local success = true

    local stopOrder = {
        "Players",
        "Math",
        "Helpers",
    }

    for _, name in ipairs(
        stopOrder
    ) do

        local module =
            self.Modules[name]

        if module then

            local stopped =
                SafeStop(module)

            if not stopped then
                success = false
            end
        end
    end

    self.Running = false

    return success
end



-- DESTROY


function Utils:Destroy()

    self:Stop()

    local destroyOrder = {
        "Players",
        "Math",
        "Helpers",
    }

    for _, name in ipairs(
        destroyOrder
    ) do

        local module =
            self.Modules[name]

        if module then

            SafeDestroy(
                module
            )
        end
    end

    self.Helpers = nil
    self.Math = nil
    self.Players = nil

    self.Modules = {}

    self.Initialized = false
    self.Running = false

    LoadedPaths = {}

    return true
end



-- BOOTSTRAP


local success,
    errorMessage =
    pcall(function()

        Utils:Initialize()

    end)

if not success then

    warn(
        "[Lua Test] Utils initialization failed:",
        errorMessage
    )

    return Utils
end


return Utils