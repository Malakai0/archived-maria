--[[
    The Observer class is used to look at a signal, and call a function whenever it changes.
    You can treat this as an interface for the Signal class.
]]
--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local ObserverMethod = require(ReplicatedStorage.Source.Modules.Observer.ObserverMethod)

local Observer = {}
Observer.__index = Observer

function Observer.new(ObserverSignal, DisconnectFunction)
	local self = {
		Connections = {},
		Signal = ObserverSignal,
		DisconnectFunction = DisconnectFunction,
		DisconnectedMethodSignal = Signal.new(),
	}

	setmetatable(self, Observer)

	ObserverSignal:Connect(function(...)
		for _, Method in pairs(self.Connections) do
			task.spawn(Method.Function, ...)
		end
	end)

	self.DisconnectedMethodSignal:Connect(function(UID)
		if self.Connections[UID] then
			self.Connections[UID] = nil
		end
	end)

	return self
end

function Observer:Connect(Function)
	local Method = ObserverMethod.new(Function, self.DisconnectedMethodSignal)
	self.Connections[Method.UID] = Method
end

function Observer:Disconnect()
	return self:Destroy()
end

function Observer:Destroy()
	self.Signal:Destroy()
	self.DisconnectedMethodSignal:Destroy()
	self.DisconnectFunction()
end

return Observer
