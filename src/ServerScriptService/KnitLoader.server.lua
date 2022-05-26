local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(ServerStorage.Source.Services)

Knit.Start():andThen(function()
    print("Server started")
end):catch(warn)