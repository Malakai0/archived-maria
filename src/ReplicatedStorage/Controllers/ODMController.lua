local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ODM = require(ReplicatedStorage.Source.Modules.ODM)

local ODMController = Knit.CreateController({
    Name = "ODMController",
    _currentODM = nil
})

function ODMController:GetODM()
    return self._currentODM
end

function ODMController:SetupCharacter()
    local ODMService = Knit.GetService("ODMService")
    local _, Value = ODMService:RequestODM():await()

    return Value
end

function ODMController:EquipGear()
    local Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

    local Rig = self:SetupCharacter()

    if not Rig then
        return
    end

    if self._currentODM and self._currentODM.Destroy then
        self._currentODM:Destroy()
    end

    self._currentODM = ODM.new(Rig)

    Character.Humanoid.Died:Connect(function()
        self._currentODM:Destroy()
    end)
end

function ODMController:KnitStart()
    self:EquipGear()

    Players.LocalPlayer.CharacterAdded:Connect(function()
        self:EquipGear()
    end)
end

return ODMController