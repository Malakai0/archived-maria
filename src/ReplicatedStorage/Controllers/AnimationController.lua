local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimationController = Knit.CreateController({
    Name = "AnimationController",
    _cache = {}
})

local Folder = ReplicatedStorage.Animations

function AnimationController:PlayAnimation(Animation: string, Speed: number, Looped: boolean): AnimationTrack?
    Looped = Looped == true
    Speed = Speed or 1

    local AnimationObject = Folder:FindFirstChild(Animation)

    if not AnimationObject then
        warn("AnimationObject not found!")
        return
    end

    local Humanoid = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
    local Animator = Humanoid and Humanoid:FindFirstChild("Animator")

    if not Animator then
        warn("Animator not found!")
        return
    end

    if not self._cache[Animation] then
        self._cache[Animation] = Animator:LoadAnimation(AnimationObject)
    end

    local Track: AnimationTrack = self._cache[Animation]
    Track.Looped = Looped
    Track:AdjustSpeed(Speed)
    Track:Play(0.25)

    return Track
end

function AnimationController:StopAnimation(Animation: string)
    if not self._cache[Animation] then
        return
    end

    local Track: AnimationTrack = self._cache[Animation]
    Track:Stop(0.25)
end

function AnimationController:ClearBadCache()
    for Key, Value in pairs(self._cache) do
        if not Key and Value then
            Value = nil
        end
    end
end

return AnimationController