--[[
    Serves as an interface for accessing GUI objects without worrying about players respawning.
    The biggest limitation is that you can't have 2 things named the exact same thing if you wish to distiguish between them.
]]
--

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Observer = require(ReplicatedStorage.Source.Modules.Observer.Observer)

local GuiController = Knit.CreateController({
	Name = "GuiController",
})

function GuiController:GetGui(Name, Table)
	return self:GetGuis(Name, Table)[1]
end

function GuiController:GetGuis(Name, Table)
	Table = Table or self._guis

	local List = {}

	for Key, Value in pairs(Table) do
		if Key == Name then
			table.insert(List, Value[1])
		elseif type(Value[2]) == "table" then
			local GuiObjects = self:GetGuis(Name, Value[2])
			if GuiObjects then
				for _, GuiObject in pairs(GuiObjects) do
					table.insert(List, GuiObject)
				end
			end
		end
	end

	return List
end

function GuiController:Observe(Name, Function)
	if not self._observers[Name] then
		self._observers[Name] = {}
	end

	local GuiSignal = Signal.new()

	local GuiObserver

	GuiObserver = Observer.new(GuiSignal, function()
		table.remove(self._observers[Name], table.find(self._observers[Name], GuiObserver))

		GuiObserver = nil
		GuiSignal:Destroy()
		GuiSignal = nil
	end)

	GuiObserver:Connect(Function)

	table.insert(self._observers[Name], GuiObserver)

	for _, GuiObject in pairs(self:GetGuis(Name)) do
		GuiObserver.Signal:Fire(GuiObject)
	end
end

function GuiController:TryObserve(GuiObject)
	if table.find(self._observed, GuiObject) then
		return
	end

	table.insert(self._observed, GuiObject)

	local GuiObserverList = self._observers[GuiObject.Name]

	if GuiObserverList then
		for _, GuiObserver in pairs(GuiObserverList) do
			task.spawn(function()
				GuiObserver.Signal:Fire(GuiObject)
			end)
		end
	end
end

function GuiController:Serialize(GuiObject)
	local Serialized = {}

	self:TryObserve(GuiObject)

	for _, Object in next, GuiObject:GetChildren() do
		Serialized[Object.Name] = { Object, self:Serialize(Object) }
	end

	return Serialized
end

function GuiController:ProcessConnection(ID, Key, Event, Function)
	local GuiObject = self:GetGui(Key)

	if not GuiObject or not GuiObject[Event] then
		return
	end

	local Connection = GuiObject[Event]:Connect(Function)
	self._activeConnections[ID] = Connection
	self.Trove:Add(Connection)
end

function GuiController:DisconnectActiveConnections()
	self.Trove:Clean()
end

function GuiController:ProcessGui()
	self:DisconnectActiveConnections()

	local CurrentGui = Player:WaitForChild("PlayerGui")
	CurrentGui:WaitForChild("Main")

	self._guis = self:Serialize(CurrentGui)

	self.Trove:Add(CurrentGui.DescendantAdded:Connect(function()
		self._guis = self:Serialize(CurrentGui)
	end))

	for ID, Connection in ipairs(self._savedConnections) do
		self:ProcessConnection(ID, unpack(Connection))
	end
end

function GuiController:DisconnectEvent(ID)
	if self._savedConnections[ID] then
		self.Trove:Remove(self._activeConnections[ID])
		self._savedConnections[ID] = nil
	end
end

function GuiController:AddConnection(Key, Event, Function)
	local ID = HttpService:GenerateGuiD(false)

	self._savedConnections[ID] = { Key, Event, Function }

	return ID
end

function GuiController:KnitInit()
	self._guis = {}
	self._savedConnections = {}
	self._activeConnections = {}
	self._observers = {}
	self._observed = {}

	self.Trove = Trove.new()

	local _ = Player.Character or Player.CharacterAdded:Wait()

	self:ProcessGui()
	Player.CharacterAdded:Connect(function()
		self:ProcessGui()
	end)
end

return GuiController
