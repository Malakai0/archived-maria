local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
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

    local ODMService = Knit.GetService("ODMService")

    ODMService.ODMEffectRequested:Connect(function(Caller: Player, Client: Player, Type: string, Wire: RopeConstraint, OriginA: Attachment, DestinationVector: Vector3?)
        if Type == "Create" then

            local Destination = Instance.new("Attachment")
            Destination.Parent = OriginA:FindFirstAncestorOfClass("BasePart")
            Destination.WorldPosition = DestinationVector
            Destination.Name = "DestinationAttachment"

            Wire.Attachment0 = OriginA
            Wire.Attachment1 = Destination
            Wire.Enabled = true

        elseif Type == "Retract" then

            local Attachment = Wire.Attachment1
            Attachment:Destroy()

            Wire.Enabled = false

        end
    end)
end

return ODMController