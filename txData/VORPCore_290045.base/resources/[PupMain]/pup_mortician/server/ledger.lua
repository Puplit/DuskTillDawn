-- pup_mortician | status refresh, the Undertaker's Ledger data and the boss settings

Actions = Actions or {}

-- every time the Ledger shows comes from the server clock
local function clock(t) return os.date('%H:%M', t) end
local function stamp(t) return os.date('%d %b %H:%M', t) end

function BuildStatus(ctx)
    ExpireAll()
    local posting = Holders[ctx.charId]
    if posting then
        PruneBoard(posting.board)
        posting = Holders[ctx.charId]
    end
    if posting then posting.holderSrc = ctx.src end
    return {
        undertaker = Rules.IsUndertaker(ctx.job),
        job = ctx.job,
        tables = AllPublicStates(),
        charId = ctx.charId,
        left = BurialsLeft(ctx.charId),
        limit = Config.Limit.perCharacter,
        posting = HolderView(posting),
    }
end

-- server push of a fresh status (after a posting changes, a role is lost, ...)
function PushStatus(src)
    CreateThread(function()
        local ctx = GetCtx(src)
        if not ctx then return end
        TriggerClientEvent('pup_mortician:status', src, BuildStatus(ctx))
    end)
end

Actions.status = function(ctx, _)
    return { ok = true, quiet = true, status = BuildStatus(ctx) }
end

local function goodsView(ctx, key)
    local c = Tables[key].casket
    if not c then return {} end
    local out = {}
    for _, idx in ipairs(c.wanted) do
        local g = Config.Goods[idx]
        out[#out + 1] = {
            index = idx, item = g.item, label = g.label, amount = g.amount, bonus = g.bonus,
            held = ItemCount(ctx.src, g.item), laid = c.laid[idx] == true,
        }
    end
    return out
end

Actions.ledger = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not key or not Rules.CanWorkTable(ctx.job, key) then return { ok = false, msg = L('notYourTable') } end
    ExpireCheck(key)
    local tab = type(p.tab) == 'string' and p.tab or 'table'

    local left = BurialsLeft(ctx.charId)
    -- re-check after the possible wait
    local now = StillSame(ctx)
    if not now or not Rules.CanWorkTable(now.job, key) then return { ok = false, msg = L('notYourTable') } end

    local c = Tables[key].casket
    local reopen = LimitReopensAt(ctx.charId)
    local isBoss = Started('pup_business') and now.job == key and IsBossOf(ctx.src, key)

    local data = {
        key = key,
        town = Config.Tables[key].town,
        table = PublicState(key),
        goods = goodsView(ctx, key),
        mine = c ~= nil and c.owner == ctx.charId,
        left = left,
        limit = Config.Limit.perCharacter,
        reopen = reopen and clock(reopen) or nil,
        contracts = Config.Contracts.enabled,
        travel = Config.Contracts.travel,
        board = Config.Contracts.enabled and BoardView(key, ctx.charId) or {},
        holdsAny = Holders[ctx.charId] ~= nil,
        business = { boss = isBoss },
    }

    if tab == 'register' then
        local rows = {}
        for _, r in ipairs(ReadRegister(key)) do
            rows[#rows + 1] = {
                when = stamp(tonumber(r.at) or 0), deceased = r.deceased, cause = r.cause,
                undertaker = r.undertaker, paid = tonumber(r.paid) or 0, place = r.place,
            }
        end
        data.register = rows
    end

    if isBoss then
        data.business.cut = CutOf(key)
        data.business.max = MaxCut()
        data.business.webhook = WebhookOf(key) ~= nil -- never the URL itself
        if tab == 'business' then
            local sum = {}
            for _, r in ipairs(ReadWeekSummary(key)) do
                sum[#sum + 1] = {
                    undertaker = r.undertaker, burials = tonumber(r.n) or 0,
                    paid = tonumber(r.paid) or 0, house = tonumber(r.house) or 0,
                }
            end
            data.business.summary = sum
        end
    end
    return { ok = true, quiet = true, data = data }
end

local function bossOfTable(ctx, key)
    return key and Rules.CanWorkTable(ctx.job, key) and ctx.job == key and IsBossOf(ctx.src, key)
end

Actions.setCut = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not bossOfTable(ctx, key) then return { ok = false, msg = L('onlyOwner') } end
    local value = tonumber(p.value)
    if not value or value ~= value then return { ok = false, quiet = true } end
    local set = SetCut(key, value)
    return { ok = true, msg = L('cutSet', set) }
end

local HOOK_PREFIXES <const> = {
    'https://discord.com/api/webhooks/',
    'https://discordapp.com/api/webhooks/',
}

Actions.setWebhook = function(ctx, p)
    local key = ValidTableKey(p.key)
    if not bossOfTable(ctx, key) then return { ok = false, msg = L('onlyOwner') } end
    local url = type(p.url) == 'string' and p.url or ''
    url = url:gsub('%s', '')
    if #url > 250 then return { ok = false, msg = L('notWebhook') } end
    if url ~= '' then
        local good = false
        for _, prefix in ipairs(HOOK_PREFIXES) do
            if url:sub(1, #prefix) == prefix and #url > #prefix then good = true break end
        end
        if not good then return { ok = false, msg = L('notWebhook') } end
    end
    SetWebhook(key, url)
    return { ok = true, msg = url ~= '' and L('reportsOn') or L('reportsOff') }
end
