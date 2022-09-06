local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local function UpdateGas(GUI, ODM)
	local Gas = ODM.Equipment.Gas
	local MaxGas = ODM.Equipment.MaxGas

	local Percentile = Gas / MaxGas
	local Percent = math.floor(Percentile * 100)
	local FillBar: Frame = GUI.Empty.Fill

	FillBar.Transparency = if Percent <= 0 then 1 else 0

	GUI.DisplayText.Text = string.format("Gas: %d", Percent) .. "%"
	FillBar:TweenSize(UDim2.fromScale(Percentile, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5)
end

local function GasGUISystem()
	local ODMController = Knit.GetController("ODMController")
	local GuiController = Knit.GetController("GuiController")

	local GasGUI = GuiController:GetGui("Gas")
	GuiController:Observe("Gas", function(GUI)
		GasGUI = GUI
	end)

	ODMController.ODMChanged:Connect(function(ODM)
		if not (GasGUI and ODM) then
			return
		end

		UpdateGas(GasGUI, ODM)

		ODM.GasChanged:Connect(function()
			UpdateGas(GasGUI, ODM)
		end)
	end)
end

return GasGUISystem
