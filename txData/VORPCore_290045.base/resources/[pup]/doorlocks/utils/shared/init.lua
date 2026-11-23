U = {} -- This is a global variable that is used for all Utils
U.Cache = {}
U.Cache.Resource = GetCurrentResourceName()


---Prints info to console when Config.General.debug is true
---@param ... any
function DevPrint(...)
	if not Config.General.debug then return end
	print('^1[DEV] ^4', ...)
end

-- Notification, switchable in Config.Notifications
---@param kind string
---@param ... any
function DoorNotify(kind, ...)
	local cfg = Config.Notifications
	if cfg == false then return end
	if type(cfg) == 'table' and cfg[kind] == false then return end
	if Core and Core.NotifyAvanced then Core.NotifyAvanced(...) end
end