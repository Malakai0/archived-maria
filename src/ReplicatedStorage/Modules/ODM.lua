local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MAX_GAS = 10000

local InputManager = require(ReplicatedStorage.Source.Modules.InputManager)

local Player = Players.LocalPlayer

local function SetupBodyMovers()
    local RootPart = Player.Character.PrimaryPart

    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.MaxForce = Vector3.zero
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.P = 500

    local BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.zero
    BodyGyro.P = 500
    BodyGyro.D = 50

    local BoostVelocity = BodyVelocity:Clone()

    BodyVelocity.Parent = RootPart
    BoostVelocity.Parent = RootPart
    BodyGyro.Parent = RootPart

    return BodyVelocity, BoostVelocity, BodyGyro
end

local ODM = {}
ODM.__index = ODM

function ODM.new()
    local RootPart = Player.Character.PrimaryPart

    local BodyVelocity, BoostVelocity, BodyGyro = SetupBodyMovers()

    local self = {
        Root = RootPart,
        BodyVelocity = BodyVelocity,
        BoostVelocity = BoostVelocity,
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
            MaxSpeed = 0,
            HookRange = 500 --// Change to a constant??
        },

        _fx = {},
        _rng = Random.new(),
        _inputManager = InputManager.new(),
    }

    setmetatable(self, ODM)

    self._inputManager:AddKeybind("HookLeft", Enum.KeyCode.Q)
    self._inputManager:AddKeybind("HookRight", Enum.KeyCode.E)
    self._inputManager:AddKeybind("Boost", Enum.KeyCode.LeftShift)

    self._inputManager:AddKeybind("DriftLeft", Enum.KeyCode.A)
    self._inputManager:AddKeybind("DriftRight", Enum.KeyCode.D)

    self:Initialize()

    return self
end

function ODM:Initialize()
    self:InitializeControls()
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
        self:Drift(1)
    end, function()
        self:Drift(-1)
    end)

    self._inputManager:BindAction("DriftRight", function()
        self:Drift(-1)
    end, function()
        self:Drift(1)
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
    return self.Equipment.Gas > 0 and not self.Hooking[Hook]
end

function ODM:SetHook(Hook, Target)
    if not ODM:CanHook(Hook) then
        return
    end

    if not Target then
        self.Hooking[Hook] = false
        self:_cleanupHookFX(Hook)

        if not self.Hooks.Left and not self.Hooks.Right and self._connection then
            self._connection:Disconnect()
        end

        self:_setVelocity()

        return
    end

    local HookPosition, HookDistance = self:_getHookTarget()
    if not HookPosition then
        return
    end

    self.Hooking[Hook] = true
    self.Equipment.Gas -= 1 --// Initial cost of hooking

    self:Boost(false)

    if not (self.Hooks.Left or self.Hooks.Right) then
        self.BodyVelocity.MaxForce = Vector3.zero
    end

    local ActualHook = self:_createHookFX(Hook, self.Root.Position, HookPosition)
    task.delay(HookDistance / 750, function()
        self.Hooking[Hook] = false
        self.Hooks[Hook] = ActualHook.Attachment0
    end)

    self:_setVelocity()

    if not self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        self:_updateVelocity()
    end)
end

function ODM:Boost(Target)
    if not (self.Hooks.Left or self.Hooks.Right) then
        return
    end

    self.Boosting = Target

    --// TODO: Implement boosting
end

function ODM:_setVelocity()

end

function ODM:_calculateVelocity()
    local TargetPosition = Vector3.zero
    local Speed = self.Properties.MaxSpeed * 4

    local LeftPosition = if self.Hooks.Left then self.Hooks.Left.WorldPosition else nil
    local RightPosition = if self.Hooks.Right then self.Hooks.Right.WorldPosition else nil

    if self.Hooks.Left and self.Hooks.Right then
        TargetPosition = (LeftPosition + RightPosition) / 2
    else
        TargetPosition = LeftPosition or RightPosition
    end

    local Distance = (TargetPosition - self.Root.Position).Magnitude
    if Distance < 10 then
        Speed *= Distance * 4
    end

    local Multiplier = 0.02
    if self.Boosting then
        Multiplier = 0.1
    end


end

function ODM:_updateVelocity()
    --// Only update function.

    self:_setVelocity()
end

function ODM:_createHookFX(Identifier, Origin, Destination)
    self:_cleanupHookFX(Identifier)

    local Wire = Instance.new("Beam")

    local OriginA, DestinationA = self:_createAttachment(Identifier),
                                                    self:_createAttachment(Identifier)

    self:_configureAttachment(OriginA, self.Root, Origin)
    self:_configureAttachment(DestinationA, workspace.Terrain, Destination)
    --// TODO: Replicate

    Wire.Attachment0 = OriginA
    Wire.Attachment1 = DestinationA

    Wire.Parent = self.Root

    task.spawn(function()
        for i = 0, 1, 0.1 do
            local Inversed = 1 - i

            Wire.CurveSize0 = self._rng:NextNumber(-10, 10) * Inversed
            Wire.CurveSize1 = self._rng:NextNumber(-10, 10) * Inversed

            DestinationA.WorldPosition = DestinationA.WorldPosition:Lerp(OriginA, i)

            task.wait()
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


end

function ODM:_cleanupHookFX(Identifier)
    local Wire = self._fx[Identifier]

    if not Wire then
        return
    end

    Wire.Attachment0:Destroy()
    Wire.Attachment1:Destroy()
    Wire:Destroy()
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
    local Target = Player:GetMouse().Hit

    local Parameters = RaycastParams.new()
    Parameters.IgnoreWater = true
    Parameters.FilterType = Enum.RaycastFilterType.Blacklist
    Parameters.FilterDescendantsInstances = {Player.Character}

    local Direction = (Target - Origin).Unit * self.Properties.HookRange
    local Result = workspace:Raycast(Origin, Direction, Parameters)

    local Position = if Result then Result.Position else nil
    local Distance = if Result then (Result.Position - Origin).Magnitude else nil

    return Position, Distance
end

function ODM:Destroy()
    self._inputManager:Destroy()
end

return ODM