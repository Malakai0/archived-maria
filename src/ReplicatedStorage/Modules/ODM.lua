local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local FOV_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local CAMERA_SHAKE_OFFSET = 0.0125
local CAMERA_OFFSET = Vector3.yAxis * 2

local HOOK_SPREAD = 3
local HOOK_HALT = 1 / 300
local HOOK_STEPS = 1 / 30
local HOOK_LENGTH = HOOK_HALT * (1 / HOOK_STEPS)

local BLADES_PER_ARM = 4

local RUN_SPEED = 28
local WALK_SPEED = 11

local GAS_PER_FRAME = 1
local BOOST_GAS_MULTIPLIER = 3

local MAX_GAS = 10000
local MAX_BV_FORCE = Vector3.new(30000, 25000, 30000)
local MAX_BG_TORQUE = Vector3.one * 100000000

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.IgnoreWater = true
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist
RAY_PARAMS.FilterDescendantsInstances = {workspace.Map}

local Knit = require(ReplicatedStorage.Packages.Knit)

local PrioritizedIf = require(ReplicatedStorage.Source.Modules.Helper.PrioritizedIf)
local EmbeddedIf = require(ReplicatedStorage.Source.Modules.Helper.EmbeddedIf)
local RigHelper = require(ReplicatedStorage.Source.Modules.Helper.RigHelper)
local InputManager = require(ReplicatedStorage.Source.Modules.InputManager)
local Switch = require(ReplicatedStorage.Source.Modules.Helper.Switch)

local Player = Players.LocalPlayer

local function Lerp(a, b, t)
    return (1 - t) * a + t * b
end

local function SetupBodyMovers()
    local RootPart = Player.Character.HumanoidRootPart

    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.MaxForce = Vector3.zero
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.P = 500

    local BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.zero
    BodyGyro.P = 500
    BodyGyro.D = 50

    BodyVelocity.Parent = RootPart
    BodyGyro.Parent = RootPart

    return BodyVelocity, BodyGyro
end

local ODM = {}
ODM.__index = ODM

function ODM.new(ODMRig, BladePrefab, Mass)
    local RootPart = Player.Character:WaitForChild("HumanoidRootPart")

    local BodyVelocity, BodyGyro = SetupBodyMovers()

    local self = {
        Character = Player.Character,
        Humanoid = Player.Character:WaitForChild("Humanoid"),
        Root = RootPart,

        Rig = ODMRig,
        Main = ODMRig.Main,
        Mass = Mass,
        BladePrefab = BladePrefab,

        BodyVelocity = BodyVelocity,
        BodyGyro = BodyGyro,

        Holding = false,
        Equipped = false,
        Sprinting = false,
        Boosting = false,
        DriftDirection = 0,

        Blades = {},

        Hooks = {},

        Hooking = {
            Left = false,
            Right = false
        },

        Equipment = {
            Blades = BLADES_PER_ARM,
            Durability = 0,

            Gas = MAX_GAS,
            MaxGas = MAX_GAS,
        },

        Properties = {
            Speed = 0,
            MaxSpeed = 60,
            HookRange = 300 --// Change to a constant??
        },

        _targetFOV = workspace.CurrentCamera.FieldOfView,
        _hookTargets = {},
        _fx = {},
        _rng = Random.new(),
        _inputManager = InputManager.new(),
        _cameraController = Knit.GetController("CameraController"),
    }

    setmetatable(self, ODM)

    self._inputManager:AddKeybind("Equip", Enum.KeyCode.One)
    self._inputManager:AddKeybind("Hold", Enum.KeyCode.R)

    self._inputManager:AddKeybind("HookLeft", Enum.KeyCode.Q)
    self._inputManager:AddKeybind("HookRight", Enum.KeyCode.E)
    self._inputManager:AddKeybind("Boost", Enum.KeyCode.Space)

    self._inputManager:AddKeybind("DriftLeft", Enum.KeyCode.A)
    self._inputManager:AddKeybind("DriftRight", Enum.KeyCode.D)

    self._inputManager:AddKeybind("Sprint", Enum.KeyCode.LeftShift)

    self._inputManager:SetObject(self)

    self:Initialize()

    return self
end

function ODM:Initialize()
    self:InitializeControls()
    self.Humanoid.CameraOffset = CAMERA_OFFSET
    self.Humanoid.WalkSpeed = WALK_SPEED

    RunService:BindToRenderStep("ODMUpdate", Enum.RenderPriority.Camera.Value, function(dt)
        self:_update(dt)
    end)
end

function ODM:InitializeControls()
    local ToggleID = self._inputManager.ToggleID

    self._inputManager:BindActionToMethod("Sprint", "Sprint", {ToggleID})
    self._inputManager:BindActionToMethod("Boost", "Boost", {ToggleID})
    self._inputManager:BindActionToMethod("HookLeft", "Hook", {"Left", ToggleID})
    self._inputManager:BindActionToMethod("HookRight", "Hook", {"Right", ToggleID})
    self._inputManager:BindActionToMethod("DriftLeft", "Drift", {EmbeddedIf(-1, 1)})
    self._inputManager:BindActionToMethod("DriftRight", "Drift", {EmbeddedIf(1, -1)})
    self._inputManager:BindActionToMethod("Equip", "Equip", {ToggleID})
    self._inputManager:BindActionToMethod("Hold", "Hold", {ToggleID})
end

function ODM:Hold(Toggle)
    if not Toggle then
        return
    end

    if not self.Equipped then
        return
    end

    local Target = not self.Holding

    local Handles = self.Rig.Handles
    local Blades = self.Rig.Blades
    local BladeAmount = self.Equipment.Blades

    local Divisible = BladeAmount % BLADES_PER_ARM == 0
    local BladeIndex = Switch(Target, {
        Default = "",
        [true] = if Divisible then BLADES_PER_ARM else BladeAmount % BLADES_PER_ARM,
    })

    if Target and BladeAmount > 0 then
        --// TODO: Hold animation

        local LeftBladeVisual = Blades.Left:FindFirstChild(BladeIndex)
        local RightBladeVisual = Blades.Right:FindFirstChild(BladeIndex)

        LeftBladeVisual.Transparency, RightBladeVisual.Transparency = 1, 1

        local LeftBlade, RightBlade = self.BladePrefab:Clone(), self.BladePrefab:Clone()
        LeftBlade.Name, RightBlade.Name = "Left", "Right"

        RigHelper.WeldBladeToHandle(Handles.Left, LeftBlade)
        RigHelper.WeldBladeToHandle(Handles.Right, RightBlade)

        LeftBlade.Parent, RightBlade.Parent = self.Root, self.Root

        self.Equipment.Blades -= 1
        self.Holding = true
    elseif not Target then
        RigHelper.UnweldBladeToHandle(Handles.Left)
        RigHelper.UnweldBladeToHandle(Handles.Right)

        self.Holding = false
    end
end

function ODM:Equip(Target)
    if not Target then
        return
    end

    self.Equipped = not self.Equipped

    if self.Equipped then
        RigHelper.WeldHandleToArm("Left", self.Rig, self.Character:FindFirstChild("Left Arm"))
        RigHelper.WeldHandleToArm("Right", self.Rig, self.Character:FindFirstChild("Right Arm"))
    else
        RigHelper.WeldHandleToRig("Left", self.Rig, self.Character:FindFirstChild("Left Arm"))
        RigHelper.WeldHandleToRig("Right", self.Rig, self.Character:FindFirstChild("Right Arm"))
    end

    --// TODO: Add equipment animations
end

function ODM:Sprint(Target)
    self.Sprinting = Target
end

function ODM:Drift(DirectionOffset)
    self.DriftDirection += DirectionOffset

    local Direction = self.DriftDirection

    if Direction ~= 0 then
        task.spawn(function()
            repeat
                task.wait(0.1)
            until self._hookTargets.Left or self._hookTargets.Right

            local _id = HttpService:GenerateGUID()
            self._directionChange = _id
            task.delay(.2, function()
                if self._directionChange == _id then
                    self._directionChange = nil
                end
            end)
        end)
    end
end

function ODM:CanHook()
    return self.Equipment.Gas > 0
end

function ODM:Hook(Hook, Target)
    self._hookTargets[Hook] = Target

    if not Target then
        self.Hooking[Hook] = true

        self:_retractHookFX(Hook)
        self.Hooks[Hook] = nil
        self.Humanoid.PlatformStand = false

        local AnyHooks = self._hookTargets.Left or self._hookTargets.Right

        if self._connection and not AnyHooks then
            self._connection:Disconnect()
            self._connection = nil

            self:Boost(false)
            self:_boostEffect(false)
            self:_gasEffect(false)
        end

        task.delay(HOOK_LENGTH * 2, function()
            if self._hookTargets[Hook] then
                return
            end

            self.Hooking[Hook] = false
            self:_cleanupHookFX(Hook)

            if not (self._hookTargets.Left or self._hookTargets.Right) then
                for _, Part in pairs(Player.Character:GetDescendants()) do
                    if Part:IsA("BasePart") then
                        Part.Massless = false
                    end
                end

                self.Mass.Massless = true

                self.BodyVelocity.MaxForce = Vector3.zero
                self.BodyVelocity.Velocity = Vector3.zero

                self.BodyGyro.MaxTorque = Vector3.zero
                self.BodyGyro.CFrame = CFrame.new()
            end
        end)

        return
    end

    if not self:CanHook() then
        return
    end

    local HookPosition = self:_getHookTarget()
    if not HookPosition then
        return
    end

    self.Hooking[Hook] = true
    self.Equipment.Gas -= 1 --// Initial cost of hooking

    self:Boost(false)
    self:_boostEffect(false)

    if not (self._hookTargets.Left or self._hookTargets.Right) then
        --self.BodyVelocity.MaxForce = Vector3.zero
    end

    local ActualHook = self:_createHookFX(Hook, HookPosition)
    task.delay(HOOK_LENGTH, function()
        self.Hooking[Hook] = false
        self.Hooks[Hook] = ActualHook.Attachment1

        if self._connection then
            return
        end

        if not self._hookTargets[Hook] then
            return
        end

        for _, Part in pairs(Player.Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.Massless = true
            end
        end
        self.Mass.Massless = false

        self:_gasEffect(true)
        self._connection = RunService.Heartbeat:Connect(function(dt)
            self:_applyPhysics(dt)
        end)
    end)
end

function ODM:Boost(Target)
    if self.Equipment.Gas <= 0 then
        return
    end

    self.Boosting = Target
end

function ODM:_applyPhysics(dt)
    if self.Equipment.Gas <= 0 then
        self:_boostEffect(false)
        self:Hook("Left", false)
        self:Hook("Right", false)

        return
    end

    local BodyVelocity = self.BodyVelocity
    local BodyGyro = self.BodyGyro

    self.Humanoid.PlatformStand = true

    local Physics = self:_calculatePhysics()

    self._cameraController:UpdateDirection(self.DriftDirection)

    self:_boostEffect(self.Boosting)

    local GasDecrement = (GAS_PER_FRAME * 60 * dt)

    if self.Boosting then
        GasDecrement *= BOOST_GAS_MULTIPLIER
    end

    self.Equipment.Gas = math.max(self.Equipment.Gas - GasDecrement, 0)

    BodyVelocity.MaxForce = Physics.BV.MaxForce
    BodyVelocity.Velocity = Physics.BV.Velocity

    BodyGyro.MaxTorque = Physics.BG.MaxTorque
    BodyGyro.CFrame = Physics.BG.CFrame

    self.Speed = BodyVelocity.Velocity.Magnitude
end

function ODM:_calculatePhysics()
    local TargetPosition = Vector3.zero
    local Speed = self.Properties.MaxSpeed * 4

    local RootP = self.Root.Position

    local LeftPosition = if self.Hooks.Left then self.Hooks.Left.WorldPosition else nil
    local RightPosition = if self.Hooks.Right then self.Hooks.Right.WorldPosition else nil

    if self.Hooks.Left and self.Hooks.Right then
        TargetPosition = (LeftPosition + RightPosition) / 2
    else
        TargetPosition = LeftPosition or RightPosition
    end

    if not TargetPosition then
        return
    end

    local Difference = TargetPosition - RootP

    local Distance = Difference.Magnitude
    local Direction = Difference.Unit

    if Distance < 10 then
        Speed = Distance * 4
    end

    local Multiplier = PrioritizedIf({ 0.02,
        self._directionChange ~= nil, .01,
        self.Boosting == true, .1
    })

    local Cross = Direction:Cross(Vector3.yAxis)
    local Matrix = CFrame.fromMatrix(RootP, Cross, Cross:Cross(Direction))

    local BodyVelocity = self.BodyVelocity

    local MaxForce = BodyVelocity.MaxForce:Lerp(MAX_BV_FORCE, .1)
    local Velocity

    if self.DriftDirection == 0 then
        Velocity = BodyVelocity.Velocity:Lerp(Direction * Speed, Multiplier)
    else
        Velocity = self:_calculateDriftingVelocity(
            BodyVelocity.Velocity, Matrix, TargetPosition, Distance, Speed, Multiplier
        )
    end

    return {
        BV = {
            MaxForce = MaxForce,
            Velocity = Velocity
        },

        BG = {
            MaxTorque = MAX_BG_TORQUE,
            CFrame = Matrix
        }
    }
end

function ODM:_gasEffect(Active)
    for _, Particle in pairs(self.Main.GasEjection:GetChildren()) do
        Particle.Enabled = Active
    end
end

function ODM:_boostEffect(Active)
    self.Main.Trail.Enabled = Active
end

function ODM:_update(dt)
    local Camera = workspace.CurrentCamera

    local Velocity = self.Root.Velocity.Magnitude / (self.Properties.MaxSpeed * 3)
    local TargetFOV = math.min(math.floor(70 + 30 * Velocity), 110)

    if not (self._hookTargets.Left or self._hookTargets.Right) then
        self._cameraController:UpdateDirection(0)
    end

    if self._targetFOV ~= TargetFOV then
        self._targetFOV = TargetFOV
        TweenService:Create(Camera, FOV_TWEEN, {
            FieldOfView = TargetFOV
        }):Play()
    end

    local WalkSpeedTarget = if self.Sprinting then RUN_SPEED else WALK_SPEED
    self.Humanoid.WalkSpeed = Lerp(self.Humanoid.WalkSpeed, WalkSpeedTarget, 6 * dt)

    if self.Boosting then
        local RX = self._rng:NextNumber(-CAMERA_SHAKE_OFFSET, CAMERA_SHAKE_OFFSET)
        local RY = self._rng:NextNumber(-CAMERA_SHAKE_OFFSET, CAMERA_SHAKE_OFFSET)
        local RZ = self._rng:NextNumber(-CAMERA_SHAKE_OFFSET, CAMERA_SHAKE_OFFSET)

        Camera.CFrame = Camera.CFrame:Lerp(Camera.CFrame * CFrame.new(RX,RY,RZ), 48 * dt)
    end
end

function ODM:_calculateDriftingVelocity(BaseVelocity, Matrix, Target, Distance, Speed, Multiplier)
    local RootP = self.Root.Position
    local Drift = self.DriftDirection

    local DriftCFrame = CFrame.new(Drift, 0, 0)
    local DirectionCFrame = CFrame.new(0, 0, -Distance + 1)

    local Facing = CFrame.new(Target, (Matrix * DriftCFrame).Position) * DirectionCFrame

    return BaseVelocity:Lerp(
        CFrame.new(RootP, Facing.Position).LookVector * Speed,
        Multiplier
    )
end

function ODM:_createHookFX(Identifier, Destination)
    self:_cleanupHookFX(Identifier)

    local OriginA = self.Main:FindFirstChild(Identifier .. "Hook")
    local Wire = self.Main:FindFirstChild(Identifier .. "Wire")

    local DestinationA = self:_createAttachment(Identifier)

    self:_configureAttachment(DestinationA, workspace.Terrain, Destination)
    --// TODO: Replicate

    Wire.Attachment0 = OriginA
    Wire.Attachment1 = DestinationA

    task.spawn(function()
        Wire.Enabled = true

        for i = 0, 1, HOOK_STEPS do
            if not (OriginA and DestinationA and self._hookTargets[Identifier]) then
                break
            end

            local Inversed = 1 - i

            Wire.CurveSize0 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed

            DestinationA.WorldPosition = OriginA.WorldPosition:Lerp(Destination, i)

            task.wait(HOOK_HALT)
        end
    end)

    self._fx[Identifier] = Wire
    return Wire
end

function ODM:_retractHookFX(Identifier)
    local Wire = self._fx[Identifier]

    if not Wire then
        return
    end

    local OriginA, DestinationA = Wire.Attachment0, Wire.Attachment1
    if not (OriginA and DestinationA) then
        return
    end

    local OriginalPosition = DestinationA.WorldPosition

    --// TODO: Replicate this too
    task.spawn(function()
        for i = 0, 1, HOOK_STEPS do
            if not (OriginA and DestinationA) or self._hookTargets[Identifier] then
                break
            end

            local Inversed = 1 - i
            Wire.CurveSize0 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed

            DestinationA.WorldPosition = OriginalPosition:Lerp(OriginA.WorldPosition, i)

            task.wait(HOOK_HALT)
        end
    end)
end

function ODM:_cleanupHookFX(Identifier)
    local Wire = self._fx[Identifier]

    if not Wire then
        return
    end

    if Wire.Attachment1 then
        Wire.Attachment1:Destroy()
    end

    Wire.Enabled = false
end

function ODM:_createAttachment(Name)
    local Attachment = Instance.new("Attachment")
    Attachment.Name = Name
    return Attachment
end

function ODM:_configureAttachment(Attachment, Parent, WorldPosition)
    Attachment.Parent = Parent
    Attachment.WorldPosition = WorldPosition
end

function ODM:_getHookTarget()
    local Origin = Player.Character.PrimaryPart.Position
    local Target = Player:GetMouse().Hit.Position

    local Direction = (Target - Origin).Unit * self.Properties.HookRange
    local Result = workspace:Raycast(Origin, Direction, RAY_PARAMS)

    return if Result then Result.Position else nil
end

function ODM:Destroy()
    self._inputManager:Destroy()
    self.Rig:Destroy()

    RunService:UnbindFromRenderStep("ODMUpdate")

    self:_cleanupHookFX("Left")
    self:_cleanupHookFX("Right")

    self.BodyVelocity:Destroy()
    self.BodyGyro:Destroy()

    if self.Humanoid then
        self.Humanoid.PlatformStand = false
    end

    setmetatable(self, nil)
    self = nil
end

return ODM