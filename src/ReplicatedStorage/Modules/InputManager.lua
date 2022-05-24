local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

function InputManager:BindAllActions(ActivatedCallback, DeactivatedCallback)
    table.insert(self._globalCallbacks, {
        ActivatedCallback or EMPTY_FUNC,
        DeactivatedCallback or EMPTY_FUNC
    })
end

function InputManager:BindAction(Identifier, ActivatedCallback, DeactivatedCallback)
    table.insert(self._callbacks[Identifier], {
        ActivatedCallback or EMPTY_FUNC,
        DeactivatedCallback or EMPTY_FUNC
    })
end

function InputManager:AddKeybind(Identifier, Combination)
    self._callbacks[Identifier] = {}
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