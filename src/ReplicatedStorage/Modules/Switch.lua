return function(value, choices)
    for choice, func in pairs(choices) do
        if choice == value then
            return func()
        end
    end

    if choices.Default then
        return choices.Default()
    end
end