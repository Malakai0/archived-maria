local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ODM = require(ReplicatedStorage.Source.Modules.ODM)

local ODMController = Knit.CreateController({
    Name = "ODMController",
    ODMChanged = Signal.new(),

    _currentODM = nil,
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
    self.ODMChanged:Fire(self._currentODM)

    Character.Humanoid.Died:Connect(function()
        self._currentODM:Destroy()
    end)
end

function ODMController:KnitStart()
    self:EquipGear()

    Players.LocalPlayer.CharacterAdded:Connect(function()
        self:EquipGear()
    end)

    local ODMService = Knit.GetService("ODMService")

    ODMService.ODMEffectRequested:Connect(function(Type: boolean, Part: BasePart, Wire: Beam, OriginA: Attachment, Destination: Vector3)
        if Type and Destination then
            local DestinationA = Instance.new("Attachment")
            DestinationA.Parent = Part
            DestinationA.WorldPosition = Destination
            DestinationA.Name = "DestinationAttachment"

            Wire.Attachment0 = OriginA
            Wire.Attachment1 = DestinationA
            Wire.Enabled = true
        else
            local Attachment = Wire.Attachment1
            Attachment:Destroy()

            Wire.Enabled = false
        end
    end)
end

return ODMController