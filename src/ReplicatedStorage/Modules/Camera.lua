local UserInputService = game:GetService("UserInputService")

local PI = math.pi

local Camera = {
	X = {
		Delta = 0,
		Angle = 0
	},

	Y = {
		Delta = 0,
		Angle = 0
	},

	Z = {
		Current = 6,
		Min = 2,
		Max = 10,
		Angle = 0
	},

	Tilt = 0,
	Offset = CFrame.new(),
	Min = -10 * PI / 20,
	Max = 5 * PI / 20,
	Maths = {
		Lerp = function(a, b, x)
			return a / 2 + (b - a) * x
		end
	},
	Check = function(value, err)
		if value == false then
			warn(err)
		end
	end
}

local function Zoom(Direction)
    local Z2 = Camera.Z

    if Direction ~= nil and Z2 ~= nil then
        local NewValue = Z2.Current
        local Min, Max = Z2.Min, Z2.Max

        if Direction == "In" then
            NewValue = Z2.Current - 1
        else
            NewValue = Z2.Current + 1
        end
        Z2.Current = NewValue
        Z2.Current = Z2.Current <= Min and Min or (Max <= Z2.Current and Max or Z2.Current)

        Camera.Offset = CFrame.new(Camera.Offset.Position.X, Camera.Offset.Position.Y, Z2.Current)
    end
end

function Camera.Setup(Mouse)
	local Success, Error = pcall(function()
		local X, Y, Z = Camera.X, Camera.Y, Camera.Z
		if Mouse ~= nil and X ~= nil and Y ~= nil and Z ~= nil then
			local Min = Z.Min
			local Max = Z.Max
			if Min ~= nil and Max ~= nil then
				Mouse.WheelForward:Connect(function()
					Zoom("In")
				end)

				Mouse.WheelBackward:Connect(function()
					Zoom("Out")
				end)

				UserInputService.InputChanged:Connect(function(Input)
					if Input ~= nil and Input.UserInputType == Enum.UserInputType.MouseMovement then
						local X2 = Input.Delta.X
						X.Delta = X2
						Y.Delta = Input.Delta.Y
						Z.Angle = Camera.Maths.Lerp(Z.Angle, Z.Angle + X2 / 5000 * 0.4, 0.1)
						if X.Delta ~= X2 then
							Camera.Offset = CFrame.new(Camera.Offset.Position.X, Camera.Offset.Position.Y, Z.Current)
						end
					end
				end)

				local State = 1
				UserInputService.InputBegan:Connect(function(p11,p12)
					if p11.UserInputType == Enum.UserInputType.MouseButton2 and p12 == false then
						UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
						return
					end
					if p11.KeyCode == Enum.KeyCode.LeftControl and p12 == false then
						if State == 1 then
							UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
							State = 2
							return
						end
						if State == 2 then
							UserInputService.MouseBehavior = Enum.MouseBehavior.Default
							State = 1
						end
					end
				end)

				UserInputService.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton2 then
						UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					end
				end)
			end
		end
	end)

	Camera.Check(Success, Error)
end
function Camera.Update(CCam, Character, Delta)
	local Success, Error = pcall(function()
		local X = Camera.X
		local Y = Camera.Y
		local Z = Camera.Z
		local Offset = Camera.Offset
		local Min = Camera.Min
		local Max = Camera.Max
		local Maths = Camera.Maths

		if CCam and Character and Delta and X and Y and Z and Offset and Min and Max and Maths then
			local RootPart = Character:FindFirstChild("HumanoidRootPart")

			if RootPart ~= nil and Offset.Position ~= nil then
				CCam.CameraSubject = nil
				CCam.CameraType = Enum.CameraType.Scriptable
				X.Angle = math.clamp(X.Angle - Y.Delta / 180,Min,Max)
				Y.Angle = Y.Angle - X.Delta / 180
				CCam.CFrame = CCam.CFrame:Lerp(CFrame.new(RootPart.Position + Vector3.new(1.5, 2, 0)) * CFrame.Angles(0, Y.Angle, 0) * CFrame.Angles(X.Angle, 0, 0) * CFrame.Angles(0, 0, Z.Angle + Camera.Tilt) * Offset, 0.25)
				Z.Angle = Maths.Lerp(Z.Angle, 0, math.min(Delta * 10, 0.8))
				X.Delta = 0
				Y.Delta = 0
			end
		end
	end)

	Camera.Check(Success, Error)
end

function Camera.UpdateTilt(Delta, Tilt)
	Camera.Tilt = Camera.Maths.Lerp(Camera.Tilt, Tilt, math.min(Delta * 3, 1))
end

return Camera
