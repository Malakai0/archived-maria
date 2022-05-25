local RigHelper = {}

function RigHelper.WeldToCharacter(Rig, Character)
    local Weld = Instance.new("Motor6D")

    Weld.Part0 = Character.HumanoidRootPart
    Weld.Part1 = Rig.MainRig.PrimaryPart
    Weld.Parent = Character.HumanoidRootPart

    return Weld
end

return RigHelper