local weightedRandom = {}

weightedRandom.Choose = function (subjects, variable, subVariable)
    local total = 0
    for key, value in pairs(subjects) do
        local weight = value
        if variable ~= nil then
            weight = value[variable]
            if subVariable ~= nil then
                weight = weight[subVariable]
            end
        end
        total = total + weight
    end

    local rng = Random.Range(0, total)

    local step = 0
    for key, value in pairs(subjects) do
        local weight = value
        if variable ~= nil then
            weight = value[variable]
            if subVariable ~= nil then
                weight = weight[subVariable]
            end
        end
        step = step + weight

        if rng > step - weight and rng < step then
            return key
        end
    end

    for key, value in pairs(subjects) do
        return key
    end
end

return weightedRandom