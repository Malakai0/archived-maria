local UserInputService = game:GetService("UserInputService")

local PI = math.pi
local OFFSET = Vector3.new(0, 2, 0)
local TILT_FPS = 1 / 30

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
		Current = 5,
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
			return (1 - x) * a + x * b
		end
	},
	Check = function(value, err)
		if not value then
			warn(err)
		end
	end
}

local function Zoom(Direction)
    local NewValue = Camera.Z.Current + (if Direction == "In" then -1 else 1)
    Camera.Z.Current = math.clamp(NewValue, Camera.Z.Min, Camera.Z.Max)

    Camera.Offset = CFrame.new(Camera.Offset.Position.X, Camera.Offset.Position.Y, Camera.Z.Current)
end

function Camera.Setup(Mouse)
    local X, Y, Z = Camera.X, Camera.Y, Camera.Z

    Mouse.WheelForward:Connect(function()
        Zoom("In")
    end)

    Mouse.WheelBackward:Connect(function()
        Zoom("Out")
    end)

    Zoom("Out")

    UserInputService.InputChanged:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local DeltaX = Input.Delta.X

        X.Delta = DeltaX
        Y.Delta = Input.Delta.Y
        Z.Angle = Camera.Maths.Lerp(Z.Angle, Z.Angle + DeltaX / 5000 * 0.4, 0.1)

        Camera.Offset = CFrame.new(Camera.Offset.Position.X, Camera.Offset.Position.Y, Z.Current)
    end)

    local State = 1
    UserInputService.InputBegan:Connect(function(Input, IsChat)
        if Input.UserInputType == Enum.UserInputType.MouseButton2 and not IsChat then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            return
        end

        if Input.KeyCode == Enum.KeyCode.LeftControl and not IsChat then
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

function Camera.Update(Cam, Character, Delta)
    local X, Y, Z = Camera.X, Camera.Y, Camera.Z
    local RootPart = Character:FindFirstChild("HumanoidRootPart")

    if RootPart then
        local Position = RootPart.Position + OFFSET

        Cam.CameraSubject = nil
        Cam.CameraType = Enum.CameraType.Scriptable

        X.Angle = math.clamp(X.Angle - Y.Delta / 180, Camera.Min, Camera.Max)
        Y.Angle = Y.Angle - X.Delta / 180
        Z.Angle = Camera.Maths.Lerp(Z.Angle, 0, (Delta * 60) * .4)

        Cam.CFrame = Cam.CFrame:Lerp(
            CFrame.new(Position) * CFrame.Angles(0, Y.Angle, 0) * CFrame.Angles(X.Angle, 0, 0) * CFrame.Angles(0, 0, Z.Angle + Camera.Tilt) * Camera.Offset,
            0.25 * (Delta * 60)
        )

        X.Delta = 0
        Y.Delta = 0
    end
end

function Camera.UpdateTilt(Delta, Tilt)
	Camera.Tilt = Camera.Maths.Lerp(Camera.Tilt, Tilt, TILT_FPS * Delta * 60)
end

return Camera
