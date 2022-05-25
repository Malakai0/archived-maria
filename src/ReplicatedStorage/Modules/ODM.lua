local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local FOV_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local RETRACT_STEP = 1 / 300
local MAX_GAS = 10000

local MAX_BV_FORCE = Vector3.new(30000, 20000, 30000)
local MAX_BG_TORQUE = Vector3.one * 100000000

local Knit = require(ReplicatedStorage.Packages.Knit)

local InputManager = require(ReplicatedStorage.Source.Modules.InputManager)
local PrioritizedIf = require(ReplicatedStorage.Source.Modules.PrioritizedIf)

local Player = Players.LocalPlayer

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

function ODM.new(ODMRig, Mass)
    local RootPart = Player.Character:WaitForChild("HumanoidRootPart")

    local BodyVelocity, BodyGyro = SetupBodyMovers()

    local self = {
        Humanoid = Player.Character:WaitForChild("Humanoid"),
        Root = RootPart,

        Rig = ODMRig,
        Main = ODMRig.MainRig.Main,
        Mass = Mass,

        BodyVelocity = BodyVelocity,
        BodyGyro = BodyGyro,

        Boosting = false,
        DriftDirection = 0,

        Hooks = {},

        Hooking = {
            Left = false,
            Right = false
        },

        Equipment = {
            Blades = 0,
            Durability = 0,
            Gas = MAX_GAS
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

    self._inputManager:AddKeybind("HookLeft", Enum.KeyCode.Q)
    self._inputManager:AddKeybind("HookRight", Enum.KeyCode.E)
    self._inputManager:AddKeybind("Boost", Enum.KeyCode.Space)

    self._inputManager:AddKeybind("DriftLeft", Enum.KeyCode.A)
    self._inputManager:AddKeybind("DriftRight", Enum.KeyCode.D)

    self:Initialize()

    return self
end

function ODM:Initialize()
    self:InitializeControls()
    self.Humanoid.CameraOffset = Vector3.yAxis * 2

    RunService:BindToRenderStep("ODMCamera", Enum.RenderPriority.Camera.Value, function()
        self:_cameraEffect()
    end)
end

function ODM:InitializeControls()
    self._inputManager:BindAction("HookLeft", function()
        self:SetHook("Left", true)
    end, function()
        self:SetHook("Left", false)
    end)

    self._inputManager:BindAction("HookRight", function()
        self:SetHook("Right", true)
    end, function()
        self:SetHook("Right", false)
    end)

    self._inputManager:BindAction("Boost", function()
        self:Boost(true)
    end, function()
        self:Boost(false)
    end)

    self._inputManager:BindAction("DriftLeft", function()
        self:Drift(-1)
    end, function()
        self:Drift(1)
    end)

    self._inputManager:BindAction("DriftRight", function()
        self:Drift(1)
    end, function()
        self:Drift(-1)
    end)
end

function ODM:Drift(DirectionOffset)
    self.DriftDirection += DirectionOffset

    local Hooks = self.Hooks
    local Direction = self.DriftDirection

    if Direction ~= 0 and (Hooks.Left or Hooks.Right) then
        if self.Equipment.Gas <= 0 then
            return
        end

        local _id = HttpService:GenerateGUID()
        self._directionChange = _id
        task.delay(.2, function()
            if self._directionChange == _id then
                self._directionChange = false
            end
        end)
    end
end

function ODM:CanHook(Hook)
    return self.Equipment.Gas > 0
end

function ODM:SetHook(Hook, Target)
    self._hookTargets[Hook] = Target

    if not Target then
        self.Hooking[Hook] = true

        self:_retractHookFX(Hook)
        self.Hooks[Hook] = nil

        local AnyHooks = self.Hooks.Left or self.Hooks.Right

        if self._connection and not AnyHooks then
            self._connection:Disconnect()
            self._connection = nil

            self:Boost(false)
            self:_boostEffect(false)
        end

        task.delay(.2, function()
            if self._hookTargets[Hook] then
                return
            end

            self.Hooking[Hook] = false
            self:_cleanupHookFX(Hook)

            if not (self.Hooks.Left or self.Hooks.Right) then
                self.Humanoid.PlatformStand = false

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
                self._cameraController:UpdateDirection(0)
            end
        end)

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

    if not (self.Hooks.Left or self.Hooks.Right) then
        self.BodyVelocity.MaxForce = Vector3.zero
    end

    local ActualHook = self:_createHookFX(Hook, HookPosition)
    task.delay(.1, function()
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

        self._connection = RunService.Heartbeat:Connect(function()
            self:_applyPhysics()
        end)
    end)
end

function ODM:Boost(Target)
    if not (self.Hooks.Left or self.Hooks.Right) then
        return
    end

    self.Boosting = Target
end

function ODM:_applyPhysics()
    local BodyVelocity = self.BodyVelocity
    local BodyGyro = self.BodyGyro

    self.Humanoid.PlatformStand = true

    local Physics = self:_calculatePhysics()

    self._cameraController:UpdateDirection(self.DriftDirection)

    self:_cameraEffect()
    self:_boostEffect(self.Boosting)

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

    local Difference = TargetPosition - RootP

    local Distance = Difference.Magnitude
    local Direction = Difference.Unit

    if Distance < 10 then
        Speed = Distance * 4
    end

    local Multiplier = PrioritizedIf({ 0.02,
        self._directionChange ~= nil, .02,
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

function ODM:_boostEffect(Active)
    self.Main.Trail.Enabled = Active

    for _, Particle in pairs(self.Main.GasEjection:GetChildren()) do
        Particle.Enabled = Active
    end
end

function ODM:_cameraEffect()
    local Camera = workspace.CurrentCamera

    local Velocity = self.Root.Velocity.Magnitude / (self.Properties.MaxSpeed * 3)
    local TargetFOV = math.min(math.floor(70 + 30 * Velocity), 110)

    if self._targetFOV ~= TargetFOV then
        self._targetFOV = TargetFOV
        TweenService:Create(Camera, FOV_TWEEN, {
            FieldOfView = TargetFOV
        }):Play()
    end

    if self.Boosting then
        local CAMERA_OFFSET = 0.075
        local RX = self._rng:NextNumber(-CAMERA_OFFSET, CAMERA_OFFSET)
        local RY = self._rng:NextNumber(-CAMERA_OFFSET, CAMERA_OFFSET)
        local RZ = self._rng:NextNumber(-CAMERA_OFFSET, CAMERA_OFFSET)

        local Target = Camera.CFrame:Lerp(Camera.CFrame * CFrame.new(RX,RY,RZ), 0.8)
        local Offset = Camera.CFrame:ToObjectSpace(Target)

        self.Humanoid.CameraOffset = Offset.Position + (Vector3.yAxis * 2)
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

        for i = 0, 1, 0.1 do
            if not (OriginA and DestinationA and self._hookTargets[Identifier]) then
                break
            end

            local Inversed = 1 - i

            Wire.CurveSize0 = self._rng:NextNumber(-3, 3) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-3, 3) * Inversed

            DestinationA.WorldPosition = OriginA.WorldPosition:Lerp(Destination, i)

            task.wait(RETRACT_STEP)
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

    task.spawn(function()
        for i = 0, 1, 0.03 do
            if not (OriginA and DestinationA) or self._hookTargets[Identifier] then
                break
            end

            local Inversed = 1 - i
            Wire.CurveSize0 = self._rng:NextNumber(-3, 3) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-3, 3) * Inversed

            DestinationA.WorldPosition = DestinationA.WorldPosition:Lerp(OriginA.WorldPosition, i)

            task.wait(RETRACT_STEP)
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

    local Parameters = RaycastParams.new()
    Parameters.IgnoreWater = true
    Parameters.FilterType = Enum.RaycastFilterType.Blacklist
    Parameters.FilterDescendantsInstances = {Player.Character}

    local Direction = (Target - Origin).Unit * self.Properties.HookRange
    local Result = workspace:Raycast(Origin, Direction, Parameters)

    return if Result then Result.Position else nil
end

function ODM:Destroy()
    self._inputManager:Destroy()
    self.Rig:Destroy()

    RunService:UnbindFromRenderStep("ODMCamera")

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