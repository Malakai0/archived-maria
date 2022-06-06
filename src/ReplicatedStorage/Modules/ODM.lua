local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local FOV_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local CAMERA_SHAKE_OFFSET = 0.0125
local CAMERA_OFFSET = Vector3.yAxis * 2

local TILT_MULT = .1
local HOOK_SPREAD = 10
local HOOK_HALT = 1 / 150
local HOOK_STEPS = 1 / 15
local HOOK_LENGTH = HOOK_HALT * (1 / HOOK_STEPS)

local BLADES_PER_ARM = 4

local RUN_SPEED = 28
local WALK_SPEED = 11

local STRAIGHT_LINE_SPEED_MULT = 1.15

local DIRECTION_CHANGE_MULTIPLIER = 0.01
local DEFAULT_MULTIPLIER = 0.02
local BOOST_MULTIPLIER = 0.1

local GAS_PER_FRAME = 1
local BOOST_GAS_MULTIPLIER = 3

local MAX_GAS = math.huge
local MAX_BV_FORCE = 30000

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.IgnoreWater = true
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local PrioritizedIf = require(ReplicatedStorage.Source.Modules.Helper.PrioritizedIf)
local EmbeddedIf = require(ReplicatedStorage.Source.Modules.Helper.EmbeddedIf)
local InputManager = require(ReplicatedStorage.Source.Modules.InputManager)

local Player = Players.LocalPlayer

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function SetupBodyMovers()
    local RootPart = Player.Character.HumanoidRootPart

	local A0 = Instance.new("Attachment")
	A0.Parent = RootPart

	local AlignA0 = Instance.new("Attachment")
	AlignA0.Parent = RootPart

    local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Attachment0 = A0
	LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    LinearVelocity.VectorVelocity = Vector3.zero
	LinearVelocity.MaxForce = 0

    local AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientation.Responsiveness = 100
	AlignOrientation.MaxTorque = 1000000000
	AlignOrientation.AlignType = Enum.AlignType.Parallel
	AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientation.Attachment0 = AlignA0

    LinearVelocity.Parent = RootPart
    AlignOrientation.Parent = RootPart

    return LinearVelocity, AlignOrientation
end

local ODM = {}
ODM.__index = ODM

function ODM.new(ODMRig)
    local RootPart = Player.Character:WaitForChild("HumanoidRootPart")

    local LinearVelocity, AlignOrientation = SetupBodyMovers()

    local self = {
        Character = Player.Character,
        Humanoid = Player.Character:WaitForChild("Humanoid"),
        Root = RootPart,

        GasChanged = Signal.new(),

        Rig = ODMRig,
        Main = ODMRig.Main,
        LinearVelocity = LinearVelocity,
        AlignOrientation = AlignOrientation,

        DepthOfField = Lighting:FindFirstChild("DepthOfField"),

        DriftDirection = 0,
        Holding = false,
        Equipped = false,
        Sprinting = false,
        Boosting = false,

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
            MaxSpeed = 55,
            HookRange = 500
        },

        _targetTilt = 0,
        _lastHooked = 0,
        _targetFOV = workspace.CurrentCamera.FieldOfView,

        _hookTargets = {},
        _hookPositions = {},
        _fx = {},

        _rng = Random.new(),
        _inputManager = InputManager.new(),

        _odmService = Knit.GetService("ODMService"),
        _animations = Knit.GetController("AnimationController"),
        _cameraController = Knit.GetController("CameraController"),
    }

    setmetatable(self, ODM)

    local IDs = {}
    for _, Animation in pairs(ReplicatedStorage.Animations:GetChildren()) do
        table.insert(IDs, Animation.AnimationId)
        self._animations:LoadToCache(Animation.Name)
    end

    ContentProvider:PreloadAsync(IDs)

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

	--// Wanted to avoid using an update loop, but it's not really possible
    RunService:BindToRenderStep("ODMUpdate", Enum.RenderPriority.Camera.Value - 1, function(dt)
        self:_update(dt)
    end)
end

function ODM:InitializeControls()
    local ToggleID = self._inputManager.ToggleID

    self._inputManager:BindActionToMethod("Sprint")
    self._inputManager:BindActionToMethod("Boost")
    self._inputManager:BindActionToMethod("Equip")
    self._inputManager:BindActionToMethod("Hold")
    self._inputManager:BindActionToMethod("DriftLeft", "Drift", EmbeddedIf(-1, 1))
    self._inputManager:BindActionToMethod("DriftRight", "Drift", EmbeddedIf(1, -1))
    self._inputManager:BindActionToMethod("HookLeft", "Hook", {"Left", ToggleID})
    self._inputManager:BindActionToMethod("HookRight", "Hook", {"Right", ToggleID})
end

function ODM:Hold(Toggle)
    if not Toggle then
        return
    end

    if not self.Equipped then
        return
    end

    local Target = not self.Holding

    local Blades = self.Rig.Blades
    local BladeAmount = self.Equipment.Blades

    if Target and BladeAmount > 0 then
        local Divisible = BladeAmount % BLADES_PER_ARM == 0
        local BladeIndex = if Divisible then BLADES_PER_ARM else BladeAmount % BLADES_PER_ARM

        local LeftBladeVisual = Blades.Left:FindFirstChild(BladeIndex)
        local RightBladeVisual = Blades.Right:FindFirstChild(BladeIndex)

        self._animations:PlayAnimation("BladeChange")

        task.delay(0.4, function()
            self._odmService:RequestBlades():andThen(function()
                LeftBladeVisual.Transparency, RightBladeVisual.Transparency = 1, 1
            end)
        end)

        self.Equipment.Blades -= 1
        self.Holding = true
    elseif not Target then
        self._odmService:DestroyBlades()

        self.Holding = false
    end
end

function ODM:Equip(Target)
    if not Target then
        return
    end

    self.Equipped = not self.Equipped

    if self.Equipped then
        self._odmService:RequestHoldHandles()
    else
        self._odmService:RequestStopHoldingHandles()
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
    return self.Equipment.Gas > 0 and self.Equipped
end

function ODM:Hook(Hook, Target)
    self._hookTargets[Hook] = Target

    if not Target then
        self.Hooking[Hook] = true

        self._animations:StopAnimation("InitialDoubleGrapple")
        self._animations:StopAnimation("DoubleHook")
        self._animations:StopAnimation("DoubleGrappleIdle")
        self._animations:StopAnimation(Hook .. "GrappleIdle")

        local AnyHooks = self._hookTargets.Left or self._hookTargets.Right
        local SuccessfulHook = self._hookPositions[Hook] ~= nil

        self._hookPositions[Hook] = nil

        if not AnyHooks and tick() - self._lastHooked > 1 and SuccessfulHook then
            self._animations:PlayAnimation(Hook .. "Hook")
        end

        self:_retractHookFX(Hook)
        self.Hooks[Hook] = nil

        self.Humanoid.PlatformStand = false

        if self._connection and not AnyHooks then
            self._connection:Disconnect()
            self._connection = nil

            self:Boost(false)
            self:_boostEffect(false)
            self:_gasEffect(false)
        end

        task.delay(HOOK_LENGTH, function()
            if self._hookTargets[Hook] and self._hookPositions[Hook] then
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
            end
        end)

        return
    end

    self._lastHooked = tick()

    if not self:CanHook() then
        return
    end

    local HookPosition, HookParent = self:_getHookTarget()

    self._hookPositions[Hook] = HookPosition

    if not HookPosition then
        return
    end

    self.Hooking[Hook] = true
    self.Equipment.Gas -= GAS_PER_FRAME * 2 --// Initial cost of hooking

    self.GasChanged:Fire()

    self:Boost(false)
    self:_boostEffect(false)

    local ActualHook = self:_createHookFX(Hook, HookParent, HookPosition)
    local Interuptted = false

    task.spawn(function()
        local Start = tick()
        repeat
            if not self._hookTargets[Hook] then
                Interuptted = true
                break
            end
            task.wait()
        until tick() - Start >= HOOK_LENGTH
    end)

    task.delay(HOOK_LENGTH, function()
        if Interuptted then
            return
        end

        self.Hooking[Hook] = false
        self.Hooks[Hook] = ActualHook.Attachment1

        if self._connection then
            return
        end

        if not self._hookTargets[Hook] then
            return
        end

        task.delay(HOOK_LENGTH, function()
            self:_playHookAnimation(Hook)
        end)

        for _, Part in pairs(Player.Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.Massless = true
            end
        end

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

    local NotTooFast = tick() - self._lastHooked > 1 and (not self._animations:IsPlaying("DoubleHook"))
    if Target and self._hookTargets.Left and self._hookTargets.Right and NotTooFast then
        self._animations:PlayAnimation("DoubleHook")
    end
end

function ODM:_applyPhysics(dt)
    if self.Equipment.Gas <= 0 then
        self:_boostEffect(false)
        self:Hook("Left", false)
        self:Hook("Right", false)

        return
    end

    local LinearVelocity = self.LinearVelocity
    local AlignOrientation = self.AlignOrientation

    self.Humanoid.PlatformStand = true

    local Physics = self:_calculatePhysics()

    if not Physics then
        return
    end

    self:_boostEffect(self.Boosting)

    local GasDecrement = GAS_PER_FRAME * 60 * dt

    if self.Boosting then
        GasDecrement *= BOOST_GAS_MULTIPLIER
    end

    self.Equipment.Gas = math.max(self.Equipment.Gas - GasDecrement, 0)
    self.GasChanged:Fire()

    LinearVelocity.MaxForce = Physics.LV.MaxForce
    LinearVelocity.VectorVelocity = Physics.LV.Velocity

	AlignOrientation.MaxTorque = 10000000000
    AlignOrientation.CFrame = Physics.AO.CFrame

    self.Properties.Speed = LinearVelocity.VectorVelocity.Magnitude
end

function ODM:_calculatePhysics()
    local TargetPosition = Vector3.zero
    local Speed = self.Properties.MaxSpeed * 4

    local Root = self.Root
    local RootP = Root.Position

    local LeftPosition = if self.Hooks.Left then self.Hooks.Left.WorldPosition else nil
    local RightPosition = if self.Hooks.Right then self.Hooks.Right.WorldPosition else nil

    if LeftPosition and RightPosition then
        TargetPosition = LeftPosition:Lerp(RightPosition, 0.5)
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

    local Multiplier = PrioritizedIf({ DEFAULT_MULTIPLIER,
        self._directionChange ~= nil, DIRECTION_CHANGE_MULTIPLIER,
        self.Boosting == true, BOOST_MULTIPLIER,
    })

    local Cross = Direction:Cross(Vector3.yAxis)
    local Matrix = CFrame.fromMatrix(RootP, Cross, Cross:Cross(Direction))

    local LinearVelocity = self.LinearVelocity

    local MaxForce = Lerp(LinearVelocity.MaxForce, MAX_BV_FORCE, .1)
    local Velocity

    if LinearVelocity.VectorVelocity.Unit:Dot(Direction) >= .85 then
        Speed *= STRAIGHT_LINE_SPEED_MULT
    end

    if self.DriftDirection == 0 then
        Velocity = LinearVelocity.VectorVelocity:Lerp(Direction * Speed, Multiplier)
    else
        Velocity = self:_calculateDriftingVelocity(
            LinearVelocity.VectorVelocity, Matrix, TargetPosition, Distance, Speed, Multiplier
        )
    end

    return {
        LV = {
            MaxForce = MaxForce,
            Velocity = Velocity
        },

        AO = {
            CFrame = Matrix
        },
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

    local ProjectedDT = dt * 60
    local NoHooks = not (self._hookPositions.Left or self._hookPositions.Right)

    local NormalizedRelative = self.Root.AssemblyLinearVelocity.Magnitude / (self.Properties.MaxSpeed * 3)
    local TiltSpeed = if NoHooks then 0 else self.LinearVelocity.VectorVelocity.Magnitude / (self.Properties.MaxSpeed * 2)

    local TargetFOV = math.min(math.floor(70 + 30 * NormalizedRelative), 110)
    local TiltTarget = self.DriftDirection * TILT_MULT
    local Tilt = TiltTarget * TiltSpeed * ProjectedDT

    if self.DepthOfField then
        self.DepthOfField.FarIntensity = Lerp(0, 0.2, NormalizedRelative)
    end

    self._cameraController:UpdateTilt(Tilt)

    if NoHooks then
		local LerpDelta = 0.025 * ProjectedDT
        self.LinearVelocity.MaxForce = Lerp(self.LinearVelocity.MaxForce, 0, LerpDelta)
        self.LinearVelocity.VectorVelocity = self.LinearVelocity.VectorVelocity:Lerp(Vector3.zero, LerpDelta)
        self.AlignOrientation.MaxTorque = 0
        self.Humanoid.PlatformStand = false
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

function ODM:_createHookFX(Identifier, HitPart, Destination)
    self:_cleanupHookFX(Identifier)

    local OriginA = self.Main:FindFirstChild(Identifier .. "Hook")
    local Wire = self.Main:FindFirstChild(Identifier .. "Wire")

    local DestinationA = self:_createAttachment(Identifier)

    self:_configureAttachment(DestinationA, HitPart, Destination)
    self._odmService:RequestODMEffect(true, Identifier, HitPart, Destination)

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

            DestinationA.WorldPosition = OriginA.WorldPosition:Lerp(Destination, math.clamp(i, 0, 1))

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

    self._odmService:RequestODMEffect(false, Identifier)

    task.spawn(function()
        for i = 0, 1, HOOK_STEPS do
            if not (OriginA and DestinationA) or self._hookTargets[Identifier] then
                break
            end

            local Inversed = 1 - i

            Wire.CurveSize0 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-HOOK_SPREAD, HOOK_SPREAD) * Inversed

            DestinationA.WorldPosition = OriginalPosition:Lerp(OriginA.WorldPosition, math.clamp(i, 0, 1))

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

function ODM:_playHookAnimation(Hook)
    local AnimationName, IdleAnimation, StartAt = nil, nil, 0

    if self._hookTargets.Left and self._hookTargets.Right then
        StartAt = 0.2

        AnimationName = "DoubleHook"
        IdleAnimation = "DoubleGrappleIdle"

        self._animations:PlayAnimation("InitialDoubleGrapple", 0.2)
        task.wait(.2)
        self._animations:StopAnimation("InitialDoubleGrapple")
    else
        --AnimationName = Hook .. "Hook"
        IdleAnimation = Hook .. "GrappleIdle"
    end

    local Object = self._animations:PlayAnimation(AnimationName, StartAt)

    task.delay(if Object then Object.Length else 0, function()
        if self._hookPositions[Hook] then
            self._animations:PlayAnimation(IdleAnimation, 0, 1, true)
        end

        self._animations:StopAnimation(AnimationName)
    end)
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

function ODM:_getMouseTarget()
    local Mouse = Player:GetMouse()
    Mouse.TargetFilter = Player.Character

	local Filter = {workspace.Map}

    for _, Entity in ipairs(workspace.Entities.Hitboxes:GetChildren()) do
        if Entity.Link.Value ~= Player.Character then
            table.insert(Filter, Entity)
        end
    end

	RAY_PARAMS.FilterDescendantsInstances = Filter

    local ScreenRay = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
    return workspace:Raycast(ScreenRay.Origin, ScreenRay.Direction.Unit * 1000, RAY_PARAMS)
end

function ODM:_getHookTarget()
    local Origin = Player.Character.PrimaryPart.Position

    local TargetResult = self:_getMouseTarget()

    if not TargetResult then
        return
    end

    local Direction = (TargetResult.Position - Origin).Unit * self.Properties.HookRange
    local Result = workspace:Raycast(Origin, Direction, RAY_PARAMS)

    if Result then
        return Result.Position, Result.Instance
    end
end

function ODM:Destroy()
    self._inputManager:Destroy()
	self._odmService:RequestDestroyODM()

    self.GasChanged:Destroy()

    RunService:UnbindFromRenderStep("ODMUpdate")

    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end

    self:_cleanupHookFX("Left")
    self:_cleanupHookFX("Right")

    self.LinearVelocity:Destroy()
    self.AlignOrientation:Destroy()

    if self.Humanoid then
        self.Humanoid.PlatformStand = false
    end

    setmetatable(self, nil)
    self = nil
end

return ODM