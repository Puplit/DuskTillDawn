-- Modified by Puppet (Dusk Till Dawn), 2026
-- Cash watcher

local C = (Config.AntiCheat or {}).cash or {}
local seen = {} -- charid -> { money, at, overLimit }

local function core()
	local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
	return ok and c or nil
end

-- getUsedCharacter returns an empty table before a character is picked, so check for a charid
local function usedChar(src)
	local Core = core()
	if not Core then return nil end
	local ok, ch = pcall(function()
		local u = Core.getUser(src)
		return u and u.getUsedCharacter
	end)
	if not ok or type(ch) ~= 'table' then return nil end
	local charid = tonumber(ch.charIdentifier)
	if not charid then return nil end
	return charid, ch
end

local function money(fmt)
	return ('$%s'):format(tostring(math.floor(fmt or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

CreateThread(function()
	if not C.enabled then return end
	Wait(15000)

	while true do
		Wait((C.pollSeconds or 30) * 1000)
		local Core = core()
		if Core then
			local now = os.time()

			for _, sid in ipairs(GetPlayers()) do
				local src = tonumber(sid)
				local charid, ch = usedChar(src)

				if charid then
					local cash = tonumber(ch.money) or 0
					local prev = seen[charid]

					-- exempt staff: they can hand themselves money legitimately
					local staff = HasPermission and HasPermission(src, 'admin_actions_menu')

					if not staff then
						-- 1. standing total
						if (C.onHandLimit or 0) > 0 and cash >= C.onHandLimit then
							if not (prev and prev.overLimit) then
								RecordFlag(src, 'cash', ('carrying %s'):format(money(cash)))
							end
						end

						-- 2. jump. Compares against the last sample inside the window.
						if prev and (C.jumpAmount or 0) > 0 and (now - prev.at) <= (C.jumpWindowSeconds or 120) then
							local gained = cash - prev.money
							if gained >= C.jumpAmount then
								RecordFlag(src, 'cash', ('gained %s in %ds (now %s)'):format(
									money(gained), now - prev.at, money(cash)))
							end
						end
					end

					seen[charid] = {
						money = cash,
						at = now,
						overLimit = (C.onHandLimit or 0) > 0 and cash >= C.onHandLimit,
					}
				end
			end
		end
	end
end)

-- Bank deposits, fired by pup-bank's deposit handler
AddEventHandler('vorp_admin:ac:bankDeposit', function(src, amount, bankname)
	if not C.enabled or (C.depositFlagAmount or 0) <= 0 then return end

	amount = tonumber(amount) or 0
	if amount < C.depositFlagAmount then return end
	if HasPermission and HasPermission(src, 'admin_actions_menu') then return end

	RecordFlag(src, 'cash', ('deposited %s at %s'):format(money(amount), tostring(bankname or '?')))
end)

AddEventHandler('playerDropped', function()
	local charid = usedChar(source)
	if charid then seen[charid] = nil end
end)

CreateThread(function()
	Wait(3000)
	if not C.enabled then return print('^3[cashwatch]^7 disabled') end
	print(('^3[cashwatch]^7 armed - hold %s, jump %s/%ds, deposit %s')
		:format(money(C.onHandLimit), money(C.jumpAmount), C.jumpWindowSeconds or 120, money(C.depositFlagAmount)))
end)
