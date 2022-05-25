return function(switches)
    for i = 2, #switches, 2 do
        local key, value = switches[i], switches[i + 1]
        if key then
            if type(value) ~= "function" then
                return value
            end

            return value()
        end
    end

    return switches[1]
end