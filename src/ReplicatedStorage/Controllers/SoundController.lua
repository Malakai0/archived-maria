local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SoundController = Knit.CreateController({
	Name = "SoundController",
	_cache = {},
})

function SoundController:PlaySound(soundName)
	local sound = self._cache[soundName]

	if not sound then
		return warn("SoundController:PlaySound - Sound not found in cache: " .. soundName)
	end

	if not sound.IsPlaying then
		sound:Play()
	end
end

function SoundController:StopSound(soundName)
	local sound = self._cache[soundName]

	if not sound then
		return warn("SoundController:StopSound - Sound not found in cache: " .. soundName)
	end

	sound:Stop()
end

function SoundController:AddSound(soundName, parent, prefab)
	prefab = prefab or ReplicatedStorage.Sounds:FindFirstChild(soundName)

	local sound = prefab:Clone()

	sound.Name = soundName
	sound.Parent = parent or Players.LocalPlayer.Character.HumanoidRootPart

	self._cache[soundName] = sound
end

return SoundController
