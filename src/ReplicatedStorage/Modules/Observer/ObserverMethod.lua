--[[
    The ObserverMethod class is not super necessary, but it's good for ease-of-use
    and increases it's versatility when it comes to using observers.
]]--

local HttpService = game:GetService("HttpService")

local ObserverMethod = {}
ObserverMethod.__index = ObserverMethod

function ObserverMethod.new(Callback, DisconnectedSignal)
    local self = {
        UID = HttpService:GenerateGUID(),
        Function = Callback,
        DisconnectedSignal = DisconnectedSignal,
    }

    setmetatable(self, ObserverMethod)

    return self
end

function ObserverMethod:Disconnect()
    self.DisconnectedSignal:Fire(self.UID)
end

return ObserverMethod