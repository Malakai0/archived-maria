local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RigHelper = require(ReplicatedStorage.Source.Modules.RigHelper)
local ODM = require(ReplicatedStorage.Source.Modules.ODM)

local function CreateMass()
    local Mass = Instance.new("Part")

    Mass.CanCollide = false
    Mass.Transparency = 1
    Mass.Name = "Mass"
    Mass.Size = Vector3.new(3, 0.75, 0.05)

    return Mass
end

local ODMController = Knit.CreateController({
    Name = "ODMController",
    _currentODM = nil
})

local ODMRig = ReplicatedStorage.Objects.ODM.Default

function ODMController:SetupCharacter(Character)
    local Root = Character:WaitForChild("HumanoidRootPart")

    local Rig = ODMRig.MainRig:Clone()
    local Mass = CreateMass()

    RigHelper.WeldToCharacter(Rig, Character)
    local Weld = Instance.new("Weld")
    Weld.Parent = Root
    Weld.Part0 = Root
    Weld.Part1 = Mass

    Mass.Parent = Character
    Rig.Parent = Root

    return Rig, ODMRig.LeftWeapon, ODMRig.RightWeapon, Mass
end

function ODMController:Spawned()
    local Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

    local Rig, LeftWeapon, RightWeapon, Mass = self:SetupCharacter(Character)

    if self._currentODM and self._currentODM.Destroy then
        self._currentODM:Destroy()
    end

    self._currentODM = ODM.new(Rig, LeftWeapon, RightWeapon, Mass)

    Character.Humanoid.Died:Connect(function()
        self._currentODM:Destroy()
    end)
end

function ODMController:KnitStart()
    self:Spawned()

    Players.LocalPlayer.CharacterAdded:Connect(function()
        self:Spawned()
    end)
end

return ODMController