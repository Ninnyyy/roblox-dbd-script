local Math = {
    Name = "Math",
}


-- Constants


Math.EPSILON = 1e-6


-- Basic helpers


function Math:Clamp(
    value,
    minimum,
    maximum
)
    value = tonumber(value)
    minimum = tonumber(minimum)
    maximum = tonumber(maximum)

    if not value then
        return minimum
    end

    if not minimum then
        minimum = value
    end

    if not maximum then
        maximum = value
    end

    if minimum > maximum then
        minimum, maximum =
            maximum, minimum
    end

    return math.clamp(
        value,
        minimum,
        maximum
    )
end

function Math:Lerp(
    a,
    b,
    alpha
)
    alpha =
        self:Clamp(
            alpha,
            0,
            1
        )

    return a + (
        (b - a)
        * alpha
    )
end

function Math:InverseLerp(
    a,
    b,
    value
)
    if math.abs(b - a)
        <= self.EPSILON then
        return 0
    end

    return self:Clamp(
        (value - a)
        / (b - a),
        0,
        1
    )
end

function Math:Map(
    value,
    inMin,
    inMax,
    outMin,
    outMax
)
    local alpha =
        self:InverseLerp(
            inMin,
            inMax,
            value
        )

    return self:Lerp(
        outMin,
        outMax,
        alpha
    )
end


-- Number helpers


function Math:Round(
    value,
    decimals
)
    value =
        tonumber(value)

    if not value then
        return 0
    end

    decimals =
        tonumber(decimals)
        or 0

    local multiplier =
        10 ^ decimals

    return math.floor(
        value * multiplier
        + 0.5
    ) / multiplier
end

function Math:Floor(value)
    return math.floor(
        tonumber(value) or 0
    )
end

function Math:Ceil(value)
    return math.ceil(
        tonumber(value) or 0
    )
end

function Math:Abs(value)
    return math.abs(
        tonumber(value) or 0
    )
end

function Math:Sign(value)
    value =
        tonumber(value)
        or 0

    if value > 0 then
        return 1
    end

    if value < 0 then
        return -1
    end

    return 0
end

function Math:Approach(
    current,
    target,
    amount
)
    current =
        tonumber(current)
        or 0

    target =
        tonumber(target)
        or 0

    amount =
        math.abs(
            tonumber(amount)
            or 0
        )

    if current < target then
        return math.min(
            current + amount,
            target
        )
    end

    if current > target then
        return math.max(
            current - amount,
            target
        )
    end

    return target
end


-- Percentage helpers


function Math:Percent(
    current,
    maximum
)
    current =
        tonumber(current)
        or 0

    maximum =
        tonumber(maximum)
        or 0

    if maximum <= 0 then
        return 0
    end

    return self:Clamp(
        current / maximum,
        0,
        1
    )
end

function Math:Percent100(
    current,
    maximum
)
    return self:Percent(
        current,
        maximum
    ) * 100
end

function Math:FromPercent(
    percent,
    minimum,
    maximum
)
    return self:Lerp(
        minimum,
        maximum,
        self:Clamp(
            tonumber(percent)
                or 0,
            0,
            1
        )
    )
end


-- Vector helpers


function Math:IsVector3(value)
    return typeof(value) == "Vector3"
end

function Math:IsVector2(value)
    return typeof(value) == "Vector2"
end

function Math:Distance(
    a,
    b
)
    if not self:IsVector3(a)
        or not self:IsVector3(b) then
        return math.huge
    end

    return (
        a - b
    ).Magnitude
end

function Math:Distance2D(
    a,
    b
)
    if not self:IsVector2(a)
        or not self:IsVector2(b) then
        return math.huge
    end

    return (
        a - b
    ).Magnitude
end

function Math:HorizontalDistance(
    a,
    b
)
    if not self:IsVector3(a)
        or not self:IsVector3(b) then
        return math.huge
    end

    local delta =
        a - b

    return Vector3.new(
        delta.X,
        0,
        delta.Z
    ).Magnitude
end

function Math:Normalize(
    vector
)
    if not self:IsVector3(vector) then
        return Vector3.zero
    end

    if vector.Magnitude
        <= self.EPSILON then
        return Vector3.zero
    end

    return vector.Unit
end

function Math:Dot(
    a,
    b
)
    if not self:IsVector3(a)
        or not self:IsVector3(b) then
        return 0
    end

    return a:Dot(b)
end

function Math:Cross(
    a,
    b
)
    if not self:IsVector3(a)
        or not self:IsVector3(b) then
        return Vector3.zero
    end

    return a:Cross(b)
end


-- Vector interpolation


function Math:LerpVector3(
    a,
    b,
    alpha
)
    if not self:IsVector3(a)
        or not self:IsVector3(b) then
        return Vector3.zero
    end

    alpha =
        self:Clamp(
            alpha,
            0,
            1
        )

    return a:Lerp(
        b,
        alpha
    )
end

function Math:LerpVector2(
    a,
    b,
    alpha
)
    if not self:IsVector2(a)
        or not self:IsVector2(b) then
        return Vector2.zero
    end

    alpha =
        self:Clamp(
            alpha,
            0,
            1
        )

    return a:Lerp(
        b,
        alpha
    )
end


-- CFrame helpers


function Math:IsCFrame(value)
    return typeof(value) == "CFrame"
end

function Math:GetPosition(
    value
)
    if self:IsCFrame(value) then
        return value.Position
    end

    if self:IsVector3(value) then
        return value
    end

    return nil
end

function Math:DistanceCFrame(
    a,
    b
)
    local positionA =
        self:GetPosition(a)

    local positionB =
        self:GetPosition(b)

    if not positionA
        or not positionB then
        return math.huge
    end

    return self:Distance(
        positionA,
        positionB
    )
end


-- Angle helpers


function Math:Degrees(
    radians
)
    return math.deg(
        tonumber(radians)
            or 0
    )
end

function Math:Radians(
    degrees
)
    return math.rad(
        tonumber(degrees)
            or 0
    )
end

function Math:NormalizeAngle(
    degrees
)
    degrees =
        tonumber(degrees)
        or 0

    degrees =
        degrees % 360

    if degrees > 180 then
        degrees =
            degrees - 360
    end

    return degrees
end

function Math:AngleDifference(
    a,
    b
)
    return self:NormalizeAngle(
        a - b
    )
end


-- Direction helpers


function Math:Direction(
    from,
    to
)
    if not self:IsVector3(from)
        or not self:IsVector3(to) then
        return Vector3.zero
    end

    return self:Normalize(
        to - from
    )
end

function Math:Direction2D(
    from,
    to
)
    if not self:IsVector2(from)
        or not self:IsVector2(to) then
        return Vector2.zero
    end

    local direction =
        to - from

    if direction.Magnitude
        <= self.EPSILON then
        return Vector2.zero
    end

    return direction.Unit
end


-- Screen-space helpers


function Math:IsOnScreen(
    screenPosition,
    viewportSize
)
    if not self:IsVector2(
        screenPosition
    ) then
        return false
    end

    if not self:IsVector2(
        viewportSize
    ) then
        return false
    end

    return screenPosition.X >= 0
        and screenPosition.X <= viewportSize.X
        and screenPosition.Y >= 0
        and screenPosition.Y <= viewportSize.Y
end

function Math:ScreenDistance(
    a,
    b
)
    return self:Distance2D(
        a,
        b
    )
end

function Math:CenterOfViewport(
    viewportSize
)
    if not self:IsVector2(
        viewportSize
    ) then
        return Vector2.zero
    end

    return viewportSize / 2
end


-- Bounding-box helpers


function Math:GetBoundingBox2D(
    points
)
    if type(points) ~= "table"
        or #points == 0 then
        return nil
    end

    local minX = math.huge
    local minY = math.huge

    local maxX = -math.huge
    local maxY = -math.huge

    local valid = false

    for _, point in ipairs(points) do
        if self:IsVector2(point) then
            valid = true

            minX =
                math.min(
                    minX,
                    point.X
                )

            minY =
                math.min(
                    minY,
                    point.Y
                )

            maxX =
                math.max(
                    maxX,
                    point.X
                )

            maxY =
                math.max(
                    maxY,
                    point.Y
                )
        end
    end

    if not valid then
        return nil
    end

    return {
        Min = Vector2.new(
            minX,
            minY
        ),

        Max = Vector2.new(
            maxX,
            maxY
        ),

        Size = Vector2.new(
            maxX - minX,
            maxY - minY
        ),

        Center = Vector2.new(
            (minX + maxX) / 2,
            (minY + maxY) / 2
        ),
    }
end


-- Health helpers


function Math:HealthRatio(
    health,
    maxHealth
)
    return self:Percent(
        health,
        maxHealth
    )
end

function Math:HealthBarHeight(
    health,
    maxHealth,
    fullHeight
)
    fullHeight =
        tonumber(fullHeight)
        or 0

    return fullHeight
        * self:HealthRatio(
            health,
            maxHealth
        )
end


-- Distance scaling


function Math:DistanceScale(
    distance,
    minimumDistance,
    maximumDistance,
    minimumScale,
    maximumScale
)
    distance =
        tonumber(distance)
        or 0

    minimumDistance =
        tonumber(minimumDistance)
        or 0

    maximumDistance =
        tonumber(maximumDistance)
        or 100

    minimumScale =
        tonumber(minimumScale)
        or 0

    maximumScale =
        tonumber(maximumScale)
        or 1

    return self:Map(
        distance,
        minimumDistance,
        maximumDistance,
        maximumScale,
        minimumScale
    )
end

function Math:ClampDistanceScale(
    distance,
    minimumDistance,
    maximumDistance
)
    return self:DistanceScale(
        distance,
        minimumDistance,
        maximumDistance,
        0,
        1
    )
end


-- Safe division


function Math:SafeDivide(
    numerator,
    denominator,
    fallback
)
    numerator =
        tonumber(numerator)
        or 0

    denominator =
        tonumber(denominator)

    if not denominator
        or math.abs(denominator)
            <= self.EPSILON then
        return fallback
            or 0
    end

    return numerator
        / denominator
end


-- Range helpers


function Math:InRange(
    value,
    minimum,
    maximum
)
    value =
        tonumber(value)

    minimum =
        tonumber(minimum)

    maximum =
        tonumber(maximum)

    if not value
        or not minimum
        or not maximum then
        return false
    end

    if minimum > maximum then
        minimum, maximum =
            maximum, minimum
    end

    return value >= minimum
        and value <= maximum
end

function Math:Wrap(
    value,
    minimum,
    maximum
)
    value =
        tonumber(value)
        or 0

    minimum =
        tonumber(minimum)
        or 0

    maximum =
        tonumber(maximum)
        or 1

    local range =
        maximum - minimum

    if math.abs(range)
        <= self.EPSILON then
        return minimum
    end

    return (
        (value - minimum)
        % range
    ) + minimum
end

return Math