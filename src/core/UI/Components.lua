local Components = {}

local function Create(className, properties)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        object[property] = value
    end

    return object
end

function Components:Frame(parent, properties)
    properties = properties or {}
    properties.Parent = parent

    return Create("Frame", properties)
end

function Components:TextLabel(parent, properties)
    properties = properties or {}
    properties.Parent = parent

    return Create("TextLabel", properties)
end

function Components:TextButton(parent, properties)
    properties = properties or {}
    properties.Parent = parent

    return Create("TextButton", properties)
end

function Components:ScrollingFrame(parent, properties)
    properties = properties or {}
    properties.Parent = parent

    return Create("ScrollingFrame", properties)
end

function Components:Corner(parent, radius)
    return Create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or 6)
    })
end

function Components:Padding(parent, amount)
    return Create("UIPadding", {
        Parent = parent,
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount)
    })
end

return Components