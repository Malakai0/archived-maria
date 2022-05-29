local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BLADES_PER_SIDE = 4

local Knit = require(ReplicatedStorage.Packages.Knit)

local RigHelper = require(ReplicatedStorage.Source.Modules.Helper.RigHelper)

local RigPrefab = ReplicatedStorage.Objects.ODM.Default
local BladePrefab = ReplicatedStorage.Objects.Blades.Default

local ODMService = Knit.CreateService({
    Name = "ODMService",
    Client = {},

    _odms = {},
    _blades = {},
    _bladeCount = {},
})

function ODMService.Client:RequestHoldHandles(Client: Player)
    local CurrentODM = self.Server._odms[Client]

    if not CurrentODM then
        return
    end

    local Character = Client.Character

    local LeftArm, RightArm = Character:FindFirstChild("Left Arm"), Character:FindFirstChild("Right Arm")

    if not (LeftArm and RightArm) then
        return
    end

    RigHelper.WeldHandleToArm("Left", CurrentODM, LeftArm)
    RigHelper.WeldHandleToArm("Right", CurrentODM, RightArm)
end

function ODMService.Client:RequestStopHoldingHandles(Client: Player)
    local CurrentODM = self.Server._odms[Client]

    if not CurrentODM then
        return
    end

    local Character = Client.Character

    local LeftArm, RightArm = Character:FindFirstChild("Left Arm"), Character:FindFirstChild("Right Arm")

    if not (LeftArm and RightArm) then
        return
    end

    RigHelper.WeldHandleToRig("Left", CurrentODM, LeftArm)
    RigHelper.WeldHandleToRig("Right", CurrentODM, RightArm)
end

function ODMService.Client:RequestODM(Client: Player)
    local CurrentODM = self.Server._odms[Client]

    if CurrentODM and CurrentODM.Parent then
        return CurrentODM
    end

    local Character = Client.Character
    local Root = Character and Character:WaitForChild("Torso")

    if not Root then
        return
    end

    local Rig = RigPrefab.MainRig:Clone()

    RigHelper.WeldToCharacter(Rig, Character)

    Rig.Parent = Root
    self.Server._odms[Client] = Rig

    return Rig
end

function ODMService.Client:RequestBlades(Client: Player)
    if self.Server._bladeCount[Client] <= 0 then
        return
    end

    local CurrentBlade = self.Server._blades[Client]
    local CurrentODM = self.Server._odms[Client]

    if not (CurrentODM and CurrentODM.Parent) then
        return
    end

    if CurrentBlade and CurrentBlade.Left and CurrentBlade.Left.Parent then
        return CurrentBlade
    end

    local LeftBlade = BladePrefab:Clone()
    local RightBlade = BladePrefab:Clone()

    LeftBlade:SetAttribute("Side", "Left")
    RightBlade:SetAttribute("Side", "Right")

    local LeftHandle = CurrentODM.Handles.Left
    local RightHandle = CurrentODM.Handles.Right

    LeftBlade.Parent, RightBlade.Parent = Client.Character, Client.Character

    RigHelper.WeldBladeToHandle(LeftHandle, LeftBlade)
    RigHelper.WeldBladeToHandle(RightHandle, RightBlade)

    self.Server._blades[Client] = {
        Left = LeftBlade,
        Right = RightBlade
    }
end

function ODMService.Client:DestroyBlades(Client: Player)
    local CurrentBlade = self.Server._blades[Client]

    if not (CurrentBlade and self.Server._odms[Client]) then
        return
    end

    self.Server:DestroyBlade(Client, CurrentBlade.Left)
    self.Server:DestroyBlade(Client, CurrentBlade.Right)

    self.Server._blades[Client] = nil
end

function ODMService:DestroyBlade(Client: Player, Blade: BasePart)
    if not (Blade and Blade.Parent) then
        return
    end

    local Handle = self:GetHandleForBlade(Client, Blade)

    RigHelper.UnweldBladeToHandle(Handle)
end

function ODMService:GetHandleForBlade(Client: Player, Blade: BasePart)
    local CurrentODM = self._odms[Client]

    if not CurrentODM then
        return
    end

    local BladeSide = Blade:GetAttribute("Side")

    return CurrentODM.Handles:FindFirstChild(BladeSide)
end

function ODMService:ClientSpawned(Client: Player)
    self._bladeCount[Client] = BLADES_PER_SIDE
end

function ODMService:ClientLeaving(Client: Player)
    self._bladeCount[Client] = nil
end

function ODMService:KnitInit()
    Players.PlayerAdded:Connect(function(Client: Player)
        local FirstCharacter = Client.Character or Client.CharacterAdded:Wait()

        self:ClientSpawned(Client, FirstCharacter)

        Client.CharacterAdded:Connect(function(Character: Model)
            self:ClientSpawned(Client, Character)
        end)
    end)

    Players.PlayerRemoving:Connect(function(Client: Player)
        self:ClientLeaving(Client)
    end)
end

return ODMService