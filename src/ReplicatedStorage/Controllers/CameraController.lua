local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Camera = require(ReplicatedStorage.Source.Modules.Camera)

local CameraController = Knit.CreateController({
    Name = "CameraController"
})

local Delta = 0

function CameraController:Update(dt)
    Delta = dt
    Camera.Update(workspace.CurrentCamera, Players.LocalPlayer.Character, dt)
end

function CameraController:UpdateDirection(Direction)
    Camera.UpdateTilt(Delta, Direction * 2)
end

function CameraController:KnitStart()
    Camera.Setup(Players.LocalPlayer:GetMouse())

    RunService:BindToRenderStep("CameraController", Enum.RenderPriority.Camera.Value, function(dt)
        self:Update(Delta)
    end)
end

return CameraController