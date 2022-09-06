local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(ReplicatedStorage.Source.Controllers)

Knit.Start()
	:andThen(function()
		print(string.format("Client [%s] started", Players.LocalPlayer.UserId))
	end)
	:catch(warn)
