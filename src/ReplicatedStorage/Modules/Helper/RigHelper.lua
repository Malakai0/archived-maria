local RigHelper = {}

function RigHelper.WeldToCharacter(Rig, Character)
	local Weld = Instance.new("Motor6D")

	Weld.Part0 = Character.Torso
	Weld.Part1 = Rig.PrimaryPart
	Weld.Parent = Character.Torso

	return Weld
end

function RigHelper.WeldHandleToArm(Side, MainRig, Arm)
	local RigWeld = MainRig:FindFirstChild(string.format("%sHandleWeld", Side))

	RigWeld.Enabled = false

	if Arm:FindFirstChild("HandleWeld") then
		Arm.HandleWeld.Enabled = true
		return
	end

	local Weld = Instance.new("Motor6D")

	Weld.Name = "HandleWeld"
	Weld.Part0 = Arm
	Weld.Part1 = MainRig.Handles:FindFirstChild(Side).PrimaryPart
	Weld.C0 = CFrame.new(0, -1, 0)
	Weld.Parent = Arm

	return Weld
end

function RigHelper.WeldHandleToRig(Side, MainRig, Arm)
	local ArmWeld = Arm:FindFirstChild("HandleWeld")
	local RigWeld = MainRig:FindFirstChild(string.format("%sHandleWeld", Side))

	ArmWeld.Enabled = false
	RigWeld.Enabled = true
end

function RigHelper.WeldBladeToHandle(Handle, Blade)
	if Handle:FindFirstChild("BladeWeld") then
		Handle.BladeWeld.Part1 = Blade
		return
	end

	local Weld = Instance.new("Motor6D")

	Weld.Enabled = true
	Weld.Name = "BladeWeld"
	Weld.Part0 = Handle.PrimaryPart
	Weld.Part1 = Blade
	Weld.C0 = CFrame.new(0, 0, -2.2)
	Weld.Parent = Handle

	return Weld
end

function RigHelper.UnweldBladeToHandle(Handle)
	local Blade = Handle.BladeWeld.Part1

	Blade.CanCollide = true

	Handle.BladeWeld.Part1 = nil
end

return RigHelper
