local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local ODM = {}
ODM.__index = ODM

function ODM.new()
    local self = {

    }

    setmetatable(self, ODM)

    return self
end

return ODM