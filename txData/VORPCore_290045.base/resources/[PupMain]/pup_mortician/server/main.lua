-- pup_mortician | the single request channel, lifecycle and the role sweep

Actions = Actions or {}

-- requests a client may make, and the rate-limit bucket each uses
local ALLOWED <const> = {
    status = 'status', ledger = 'ledger',
    lay = 'default', layin = 'default', close = 'default', bury = 'default', grave = 'default',
    take = 'default', giveup = 'default', arrive = 'default', respot = 'default', tagBody = 'tag',
    setCut = 'default', setWebhook = 'default',
    digStart = 'default', digFinish = 'default',
}
Config.RateLimit.tag = Config.RateLimit.tag or 150

-- one action at a time per player: a second request while the first is still
-- waiting (database, exports) is turned away instead of interleaving
local inFlight = {}

Core.Callback.Register('pup_mortician:act', function(source, cb, action, payload)
    local src = tonumber(source)
    local reply = { ok = false, quiet = true }
    local okRun, err = pcall(function()
        if type(action) ~= 'string' or not ALLOWED[action] or not Actions[action] then return end
        if not RateOk(src, ALLOWED[action]) then return end
        local ctx = GetCtx(src)
        if not ctx then return end
        local exclusive = action ~= 'status' and action ~= 'ledger' and action ~= 'tagBody'
        if exclusive then
            if inFlight[src] then
                reply = { ok = false, msg = L('busy') }
                return
            end
            inFlight[src] = true
        end
        local okA, res = pcall(Actions[action], ctx, type(payload) == 'table' and payload or {})
        if exclusive then inFlight[src] = nil end
        if okA and type(res) == 'table' then
            reply = res
        elseif not okA then
            Warn(('action %s failed: %s'):format(action, tostring(res)))
        end
    end)
    if not okRun then Warn('request failed: ' .. tostring(err)) end
    cb(reply)
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
exports('BuriesLeft', function(src)
    local ctx = GetCtx(src)
    if not ctx then return 0 end
    return BurialsLeft(ctx.charId) or 0
end)

---------------------------------------------------------------------------
-- Releasing what a character held
---------------------------------------------------------------------------
OnCharacterLeft = function(src, charId)
    if not charId then return end
    FreeCasketsOf(charId)
    ReleasePostingOf(charId)
    ForgetRespot(charId)
    LimitForget(charId)
    if src then
        ClearDig(src)
        ForgetShovel(src)
        inFlight[src] = nil
    end
end

-- uses our own record of the character, never VORP's
AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    local s = Sessions[src]
    Sessions[src] = nil
    if s then OnCharacterLeft(src, s.charId) end
    ClearDig(src)
    ForgetShovel(src)
    ForgetRate(src)
    inFlight[src] = nil
end)

-- a character switch releases the previous character's work
AddEventHandler('vorp:SelectedCharacter', function(src, character)
    src = tonumber(src)
    if not src then return end
    local prev = Sessions[src]
    local newId = type(character) == 'table' and tonumber(character.charIdentifier) or nil
    if prev and prev.charId ~= newId then
        OnCharacterLeft(src, prev.charId)
        Sessions[src] = nil
    end
    ClearDig(src)
    ForgetShovel(src)
end)

---------------------------------------------------------------------------
-- Sweep: abandoned caskets, expired postings, and work held by
-- characters who lost the job or the table it depends on.
---------------------------------------------------------------------------
local function roleSweep()
    for src, s in pairs(Sessions) do
        local key, casket = CasketOwnedBy(s.charId)
        local posting = Holders[s.charId]
        local dig = Digs[src]
        if key or posting or dig then
            local ctx = GetCtx(src)
            if not ctx then
                OnCharacterLeft(src, s.charId)
                Sessions[src] = nil
            else
                local changed = false
                if key and casket and not Rules.CanWorkTable(ctx.job, key) then
                    FreeTable(key, 'owner lost the table')
                    changed = true
                end
                if posting and not Rules.CanWorkTable(ctx.job, posting.board) then
                    posting.holderSrc = nil
                    RemovePosting(posting)
                    changed = true
                end
                if dig and not Rules.MayDig(ctx.job) then
                    ClearDig(src)
                end
                if changed then PushStatus(src) end
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(20000)
        ExpireAll()
        for key in pairs(Boards) do PruneBoard(key) end
        roleSweep()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    -- server state is memory only; clients clean their own props on stop
    Sessions = {}
end)
