local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SystemController = Knit.CreateController({
    Name = "SystemController",
    _systems = {},
})

function SystemController:KnitStart()
    for _, System in pairs(self._systems) do
        task.spawn(System)
    end
end

function SystemController:KnitInit()
    for _, System in pairs(ReplicatedStorage.Source.Modules.Systems:GetChildren()) do
        self._systems[System.Name] = require(System)
    end
end

return SystemController