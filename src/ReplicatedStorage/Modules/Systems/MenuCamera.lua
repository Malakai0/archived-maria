local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

workspace:WaitForChild("CamPart")

local TrySet = true

local function Initialize()
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value - 1, function()
		if TrySet then
			TrySet = not pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
				StarterGui:SetCore("ChatActive", false)
			end)
		end

		Players.LocalPlayer.Character = nil

		local Camera = workspace.CurrentCamera

		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = workspace.CamPart.CFrame
	end)
end

return Initialize