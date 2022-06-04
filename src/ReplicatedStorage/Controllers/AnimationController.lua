local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimationController = Knit.CreateController({
    Name = "AnimationController",
    _cache = {}
})

local Folder = ReplicatedStorage.Animations

function AnimationController:LoadToCache(Animation: string)
    if not Animation then
        return
    end

    local AnimationObject = Folder:FindFirstChild(Animation)

    if not AnimationObject then
        warn("AnimationObject not found!")
        return
    end

    local Humanoid = Players.LocalPlayer.Character:WaitForChild("Humanoid")
    local Animator = Humanoid and Humanoid:FindFirstChild("Animator")

    if not Animator then
        warn("Animator not found!")
        return
    end

    if not self._cache[Animation] then
        self._cache[Animation] = Animator:LoadAnimation(AnimationObject)
    end

    return true
end

function AnimationController:PlayAnimation(Animation: string, StartAt: number, Speed: number, Looped: boolean): AnimationTrack?
    Looped = Looped == true
    Speed = Speed or 1
    StartAt = StartAt or 0

    if not self:LoadToCache(Animation) then
        return
    end

    local Track: AnimationTrack = self._cache[Animation]
    Track.Looped = Looped
    Track:AdjustSpeed(Speed)
    Track:Play(0.25)
    Track.TimePosition = StartAt

    return Track
end

function AnimationController:StopAnimation(Animation: string)
    if not self._cache[Animation] then
        return
    end

    local Track: AnimationTrack = self._cache[Animation]
    Track:Stop(0.25)
end

function AnimationController:IsPlaying(Animation: string)
    if not self._cache[Animation] then
        return false
    end

    local Track: AnimationTrack = self._cache[Animation]
    return Track.IsPlaying == true
end

function AnimationController:ClearCache()
    for Key, Value in pairs(self._cache) do
        Value:Destroy()
		self._cache[Key] = nil
    end
end

function AnimationController:KnitStart()
	Players.LocalPlayer.CharacterAdded:Connect(function()
		self:ClearCache()
	end)
end

return AnimationController