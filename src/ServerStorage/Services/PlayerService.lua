local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
})

local HITBOX_SIZE = Vector3.new(5, 6, 5)

function PlayerService:CreateHitbox(Player: Player, Character: Model)
	local Hitbox = Instance.new("Part")
	Hitbox.Name = Player.Name
	Hitbox.CanCollide = false
	Hitbox.CanQuery = true
	Hitbox.Size = HITBOX_SIZE
	Hitbox.Transparency = 1
	Hitbox.Massless = true
	Hitbox.RootPriority = -1
	Hitbox.Parent = workspace.Entities.Hitboxes

	local Link = Instance.new("ObjectValue")
	Link.Value = Character
	Link.Name = "Link"
	Link.Parent = Hitbox

	local Weld = Instance.new("Weld")
	Weld.Part0 = Character.HumanoidRootPart
	Weld.Part1 = Hitbox
	Weld.Parent = Hitbox

	return Hitbox
end

function PlayerService:ExtendHitbox(Player: Player, Extension: Vector3)
	local Hitbox = workspace.Entities.Hitboxes:FindFirstChild(Player.Name)
	Hitbox.Size = HITBOX_SIZE + Extension
end

function PlayerService:UnextendHitbox(Player: Player)
	local Hitbox = workspace.Entities.Hitboxes:FindFirstChild(Player.Name)
	Hitbox.Size = HITBOX_SIZE
end

function PlayerService:CharacterAdded(Character: Model)
	repeat
		task.wait()
	until Character:IsDescendantOf(workspace)

	local Player = Players:GetPlayerFromCharacter(Character)
	self:CreateHitbox(Player, Character)

	Character.Parent = workspace.Entities
end

function PlayerService:PlayerAdded(Client: Player)
	local Character = Client.Character or Client.CharacterAdded:Wait()

	self:CharacterAdded(Character)
	Client.CharacterAdded:Connect(function(...)
		self:CharacterAdded(...)
	end)
end

function PlayerService:KnitStart()
	for _, Player in pairs(Players:GetPlayers()) do
		self:PlayerAdded(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:PlayerAdded(Player)
	end)
end

return PlayerService
