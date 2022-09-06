return function(value, choices)
	for choice, func in pairs(choices) do
		if choice == value then
			if type(func) == "function" then
				return func()
			end

			return func
		end
	end

	if choices.Default then
		local def = choices.Default
		if type(def) == "function" then
			return def()
		end

		return def
	end
end
