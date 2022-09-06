local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local EMPTY_FUNC = function() end

local Signal = require(ReplicatedStorage.Packages.Signal)

local InputManager = {}
InputManager.__index = InputManager

function InputManager.new()
	local self = {
		_keybinds = {},

		_activeKeybinds = {},
		_heldKeys = {},

		_globalCallbacks = {},
		_callbacks = {},
		_objectCallbacks = {},

		_object = nil,

		ToggleID = HttpService:GenerateGUID(),
		KeybindActivated = Signal.new(),
		KeybindDeactivated = Signal.new(),
	}

	setmetatable(self, InputManager)

	self:InitializeConnection()

	return self
end

function InputManager:InitializeConnection()
	self._beganConnection = UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		self._heldKeys[Input.KeyCode] = true

		for Identifier, Keybind in pairs(self._keybinds) do
			local AlreadyActive = self._activeKeybinds[Identifier]
			if self:IsKeybindActive(Keybind) and not AlreadyActive then
				self._activeKeybinds[Identifier] = true
				self.KeybindActivated:Fire(Identifier)

				if self._object then
					for _, Callback in pairs(self._objectCallbacks[Identifier]) do
						local Args = self:EvaluateArgs(Callback[2], true)
						task.spawn(self._object[Callback[1]], self._object, unpack(Args))
					end
				end

				for _, Callback in pairs(self._callbacks[Identifier]) do
					task.spawn(Callback[1])
				end

				for _, Callback in pairs(self._globalCallbacks) do
					task.spawn(Callback[1])
				end
			end
		end
	end)

	self._endedConnection = UserInputService.InputEnded:Connect(function(Input, Processed)
		if Processed then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		self._heldKeys[Input.KeyCode] = nil

		for Identifier, Keybind in pairs(self._keybinds) do
			local IsActive = self:IsKeybindActive(Keybind)
			if not IsActive and self._activeKeybinds[Identifier] then
				self._activeKeybinds[Identifier] = nil
				self.KeybindDeactivated:Fire(Identifier)

				if self._object then
					for _, Callback in pairs(self._objectCallbacks[Identifier]) do
						local Args = self:EvaluateArgs(Callback[2], false)
						task.spawn(self._object[Callback[1]], self._object, unpack(Args))
					end
				end

				for _, Callback in pairs(self._callbacks[Identifier]) do
					task.spawn(Callback[2])
				end

				for _, Callback in pairs(self._globalCallbacks) do
					task.spawn(Callback[2])
				end
			end
		end
	end)
end

function InputManager:EvaluateArgs(Args, ToggleValue)
	local Result = {}

	for _, Arg in pairs(Args) do
		if type(Arg) == "function" then
			table.insert(Result, Arg(ToggleValue))
			continue
		end

		if Arg == self.ToggleID then
			table.insert(Result, ToggleValue)
			continue
		end

		table.insert(Result, Arg)
	end

	return Result
end

function InputManager:SetObject(Object)
	self._object = Object
end

function InputManager:BindActionToMethod(Identifier, Method, Args)
	if not (Method and Args) then
		Method = Identifier
	end

	table.insert(self._objectCallbacks[Identifier], {
		Method,
		if not Args then { self.ToggleID } elseif type(Args) ~= "table" then { Args } else Args,
	})
end

function InputManager:BindAllActions(ActivatedCallback, DeactivatedCallback)
	table.insert(self._globalCallbacks, {
		ActivatedCallback or EMPTY_FUNC,
		DeactivatedCallback or EMPTY_FUNC,
	})
end

function InputManager:BindAction(Identifier, ActivatedCallback, DeactivatedCallback)
	table.insert(self._callbacks[Identifier], {
		ActivatedCallback or EMPTY_FUNC,
		DeactivatedCallback or EMPTY_FUNC,
	})
end

function InputManager:AddKeybind(Identifier, Combination)
	self._callbacks[Identifier] = {}
	self._objectCallbacks[Identifier] = {}
	self._keybinds[Identifier] = Combination
end

function InputManager:RemoveKeybind(Identifier)
	self._callbacks[Identifier] = nil
	self._keybinds[Identifier] = nil
end

function InputManager:IsKeybindActive(Combination)
	if type(Combination) ~= "table" then
		return self._heldKeys[Combination] == true
	end

	local SuccessfulKeys = 0

	for _, Key in ipairs(Combination) do
		if self._heldKeys[Key] == true then
			SuccessfulKeys += 1
		end
	end

	return SuccessfulKeys >= #Combination
end

function InputManager:Destroy()
	self._beganConnection:Disconnect()
	self._endedConnection:Disconnect()

	self._keybinds = nil
	self._callbacks = nil

	setmetatable(self, nil)
	self = nil
end

return InputManager
