local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ACTUAL_GAME = 9838913388
local CREDITS_TWEEN = TweenInfo.new(.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Knit = require(ReplicatedStorage.Packages.Knit)

--// We ensure that every controller is loaded - this is safe.
local GuiController = Knit.GetController("GuiController")

local ShowingCredits = false

local function TweenText(Text, Active)
	TweenService:Create(Text, CREDITS_TWEEN, {
		TextTransparency = if Active then 0 else 1,
	}):Play()
end

local function TweenElement(Element, Active)
	if Element:IsA("Frame") then
		task.spawn(TweenText, Element.Title, Active)
		task.spawn(TweenText, Element.CreditName, Active)

		return
	end

	TweenText(Element, Active)
end

local function HideElement(Element)
	if Element:IsA("Frame") then
		Element.Title.TextTransparency = 1
		Element.CreditName.TextTransparency = 1

		return
	end

	Element.TextTransparency = 1
end

local function PressedCredits()
	if ShowingCredits then
		return
	end

	ShowingCredits = true

	local CreditsList = GuiController:GetGui("CreditsList")

	local Order = {CreditsList.Title}

	for _, Element in pairs(CreditsList.List:GetChildren()) do
		Order[Element:GetAttribute("Index") + 2] = Element
	end

	for _, Element in pairs(Order) do
		HideElement(Element)
	end

	CreditsList.Visible = true

	for Index = 1, #Order do
		task.spawn(TweenElement, Order[Index], true)

		task.wait(CREDITS_TWEEN.Time)
	end

	task.wait(1)

	for Index = #Order, 1, -1 do
		task.spawn(TweenElement, Order[Index], false)
	end

	task.wait(CREDITS_TWEEN.Time)

	CreditsList.Visible = false
	ShowingCredits = false
end

local function PressedPlay()
	TweenService:Create(GuiController:GetGui("TeleportScreen"), CREDITS_TWEEN, {
		BackgroundTransparency = 0,
		TextTransparency = 0
	}):Play()

	TeleportService:SetTeleportGui(ReplicatedStorage.TeleportGui)
	TeleportService:Teleport(ACTUAL_GAME, Players.LocalPlayer)
end

local function InitializePlayButton()
	GuiController:Observe("Play"):Connect(function(PlayButton)
		PlayButton.Activated:Connect(PressedPlay)
	end)
end

local function InitializeCreditsButton()
	GuiController:Observe("Credits"):Connect(function(CreditsButton)
		CreditsButton.Activated:Connect(PressedCredits)
	end)
end

local function InitializeMenu()
	InitializePlayButton()
	InitializeCreditsButton()
end

return InitializeMenu