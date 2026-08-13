local FeatureRegistry = {}

FeatureRegistry.Items = {}

function FeatureRegistry:Register(name, feature)
    assert(
        type(name) == "string",
        "Feature name must be a string"
    )

    assert(
        type(feature) == "table",
        "Feature must be a table"
    )

    if self.Items[name] then
        return false
    end

    self.Items[name] = feature

    return true
end

function FeatureRegistry:Get(name)
    return self.Items[name]
end

function FeatureRegistry:Remove(name)
    self.Items[name] = nil
end

function FeatureRegistry:Exists(name)
    return self.Items[name] ~= nil
end

function FeatureRegistry:GetAll()
    return self.Items
end

function FeatureRegistry:Clear()
    table.clear(self.Items)
end

return FeatureRegistry