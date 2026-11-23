-- pup-stable | thin wrappers over the game natives this resource uses (by hash where RedM has no name)

N = {}
local Inv = Citizen.InvokeNative

local function pick(newName, oldName, hash)
    local fn = _G[newName] or _G[oldName]
    if type(fn) == 'function' then return fn end
    return function(...) return Inv(hash, ...) end
end

-- prompts ------------------------------------------------------------------
local P = {
    begin = pick('UiPromptRegisterBegin', 'PromptRegisterBegin', 0x04F97DE45A519419),
    control = pick('UiPromptSetControlAction', 'PromptSetControlAction', 0xB5352B7494A08258),
    text = pick('UiPromptSetText', 'PromptSetText', 0x5DD02A8318420DD7),
    enabled = pick('UiPromptSetEnabled', 'PromptSetEnabled', 0x8A0FB4D03A630D21),
    visible = pick('UiPromptSetVisible', 'PromptSetVisible', 0x71215ACCFDE075EE),
    standard = pick('UiPromptSetStandardMode', 'PromptSetStandardMode', 0xCC6656799977741B),
    hold = pick('UiPromptSetHoldMode', 'PromptSetHoldMode', 0x94073D5CA3F16B7B),
    group = pick('UiPromptSetGroup', 'PromptSetGroup', 0x2F11D3A254169EA4),
    finish = pick('UiPromptRegisterEnd', 'PromptRegisterEnd', 0xF7AA2696A22AD8B9),
    stdDone = pick('UiPromptHasStandardModeCompleted', 'PromptHasStandardModeCompleted', 0xC92AC953F0A982AE),
    holdDone = pick('UiPromptHasHoldModeCompleted', 'PromptHasHoldModeCompleted', 0xE0F65F0640EF0617),
    active = pick('UiPromptSetActiveGroupThisFrame', 'PromptSetActiveGroupThisFrame', 0xC65A45D4453C2627),
    delete = pick('UiPromptDelete', 'PromptDelete', 0x00EDE88D4D13CF59),
    varString = pick('VarString', 'CreateVarString', 0xFA925AC00EB830B9),
}

function N.literal(text) return P.varString(10, 'LITERAL_STRING', tostring(text)) end

local allPrompts = {}

-- holdMs = nil -> press; group = a prompt group id (or entity target group)
function N.prompt(control, text, holdMs, group)
    local p = P.begin()
    P.control(p, control)
    P.text(p, N.literal(text))
    P.enabled(p, false)
    P.visible(p, false)
    if holdMs then P.hold(p, holdMs) else P.standard(p, true) end
    if group then P.group(p, group, 0) end
    P.finish(p)
    local o = { h = p, text = text, hold = holdMs ~= nil, shown = false }
    allPrompts[#allPrompts + 1] = o
    return o
end

function N.promptText(o, text)
    if o.text ~= text then o.text = text; P.text(o.h, N.literal(text)) end
end

function N.promptShow(o, shown, enabled)
    shown = shown and true or false
    if enabled == nil then enabled = shown end
    if o.shown ~= shown then o.shown = shown; P.visible(o.h, shown) end
    if o.enabled ~= enabled then o.enabled = enabled; P.enabled(o.h, enabled) end
end

function N.promptDone(o)
    if not o.shown or not o.enabled then return false end
    if o.hold then return P.holdDone(o.h) and true or false end
    return P.stdDone(o.h) and true or false
end

function N.groupActive(group, title) P.active(group, N.literal(title)) end
function N.newGroup() return GetRandomIntInRange(0, 0xFFFFFF) end
function N.entityGroup(ent) return Inv(0xB796970BD125FCE8, ent, Citizen.ResultAsInteger()) end

function N.promptDelete(o)
    if not o then return end
    P.delete(o.h)
    for i, x in ipairs(allPrompts) do if x == o then table.remove(allPrompts, i) break end end
end

function N.deleteAllPrompts()
    for _, o in ipairs(allPrompts) do P.delete(o.h) end
    allPrompts = {}
end

-- blips --------------------------------------------------------------------
function N.blipEntity(style, ent) return Inv(0x23F74C2FDA6E7C61, style, ent, Citizen.ResultAsInteger()) end
function N.blipCoords(style, x, y, z) return Inv(0x554D9D53F696D002, style, x + 0.0, y + 0.0, z + 0.0, Citizen.ResultAsInteger()) end
function N.blipSprite(b, sprite) Inv(0x74F74D3207ED525C, b, sprite, true) end
function N.blipName(b, name) Inv(0x9CB1A1623062F402, b, N.literal(name)) end
function N.blipModifier(b, mod) Inv(0x662D364ABF16DE2F, b, mod) end
function N.blipRemove(b) if b and b ~= 0 and DoesBlipExist(b) then RemoveBlip(b) end end

-- meta ped (components and colours) -------------------------------------
function N.applyComp(ped, hash) Inv(0xD3A7B003ED343FD9, ped, hash, true, false, false) end
function N.update(ped) Inv(0xCC8CA3E88256E58F, ped, false, true, true, true, false) end
function N.removeTag(ped, cat) Inv(0xD710A5007C2AC539, ped, cat, 0) end
function N.usingComp(ped, hash) return Inv(0xFB4891BD7578CDC1, ped, hash, Citizen.ResultAsInteger()) == 1 end
function N.metaType(ped) return Inv(0xEC9A1261BF0CE510, ped, Citizen.ResultAsInteger()) end
function N.compCategory(hash, metaType) return Inv(0x5FF9A878C3D115B8, hash, metaType or 0, true, Citizen.ResultAsInteger()) end
function N.numComps(ped) return Inv(0x90403E8107B60E81, ped, Citizen.ResultAsInteger()) end
function N.compAt(ped, i) return Inv(0x77BA37622E22023B, ped, i, true, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.ResultAsInteger()) end
function N.categoryAt(ped, i) return Inv(0xCCB97B51893C662F, ped, i, true, Citizen.ResultAsInteger()) end
function N.outfit(ped, hash) Inv(0x1902C4CFCC5BE57C, ped, hash) end

function N.guids(ped, i)
    local _, d, a, n, m = Inv(0xA9C28516A6DC9D56, ped, i, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
    return d, a, n, m
end

function N.tint(ped, i)
    local _, pal, t0, t1, t2 = Inv(0xE7998FEC53A33BBE, ped, i, Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
    return pal, t0, t1, t2
end

function N.setTag(ped, d, a, n, m, pal, t0, t1, t2)
    Inv(0xBC6DF00D7A4A6819, ped, d, a, n, m, pal, t0, t1, t2)
end

-- horse attributes ----------------------------------------------------------
-- attribute index: 0 health, 1 stamina, 3 courage, 4 agility (handling), 5 speed, 6 acceleration, 7 bonding
N.ATTR = { health = 0, stamina = 1, courage = 3, handling = 4, speed = 5, acceleration = 6, bonding = 7 }
function N.setBaseRank(ped, a, r) Inv(0x5DA12E025D47D4E5, ped, a, r) end
function N.baseRank(ped, a) return Inv(0x147149F2E909323C, ped, a, Citizen.ResultAsInteger()) end
function N.rank(ped, a) return Inv(0xA4C8E23E29040DE0, ped, a, Citizen.ResultAsInteger()) end
function N.setPoints(ped, a, p) Inv(0x09A59688C26D88DF, ped, a, p) end
function N.points(ped, a) return Inv(0x219DA04BAA9CB065, ped, a, Citizen.ResultAsInteger()) end
function N.maxPoints(ped, a) return Inv(0x223BF310F854871C, ped, a, Citizen.ResultAsInteger()) end
function N.addPoints(ped, a, p) Inv(0x75415EE0CB583760, ped, a, p) end
function N.core(ped, c) return Inv(0x36731AC041289BB1, ped, c, Citizen.ResultAsInteger()) end
function N.setCore(ped, c, v) Inv(0xC6258F41D86676E0, ped, c, v) end
function N.overpower(ped, c, v) Inv(0xF6A7C08DF2E28B28, ped, c, v + 0.0, true) end
function N.pedStamina(ped) return Inv(0x775A1CA7893AA8B5, ped, Citizen.ResultAsFloat()) end
function N.changeStamina(ped, d) Inv(0xC3D4B754C0E86B9E, ped, d + 0.0) end

-- horses and riders ---------------------------------------------------------
function N.leading(ped) return Inv(0xEFC4303DDC6E60D3, ped, Citizen.ResultAsInteger()) == 1 end
function N.ledHorse(ped) return Inv(0xED1F514AF4732258, ped, Citizen.ResultAsInteger()) end
function N.lastMount(ped) return Inv(0x4C8B59171957BCF7, ped, Citizen.ResultAsInteger()) end
function N.putOnMount(ped, mount, seat) Inv(0x028F76B6E78246EB, ped, mount, seat or -1, true) end
function N.promptName(ped, name) Inv(0x19B14E04B009E28B, ped, name) end
function N.ownsAnimal(ped, animal, on) Inv(0x931B241409216C1F, ped, animal, on and true or false) end
function N.faceFeature(ped, idx, v) Inv(0x5653AB26C82938CF, ped, idx, v + 0.0) end
function N.scale(ped, s) Inv(0x25ACFC650B65C538, ped, s + 0.0) end
function N.cleanDirt(ped)
    Inv(0x6585D955A68452A5, ped)   -- clear damage decals
    Inv(0x9C720776DAA43E7E, ped)   -- clear wetness
    Inv(0x8FE22675A5A45817, ped)   -- clear blood
end
function N.carrying(ped) return Inv(0xD806CD2A4F2C2996, ped, Citizen.ResultAsInteger()) end
function N.placeOnMount(ped, ent, mount) Inv(0x6D3D87C57B3D52C7, ped, ent, mount, 1) end
function N.pickUp(ped, ent) Inv(0x502EC17B1BED4BFA, ped, ent) end
function N.targetEntity()
    local ok, ent = Inv(0x3EE1F7A8C32F24E1, PlayerId(), Citizen.PointerValueIntInitialized(0), Citizen.ReturnResultAnyway())
    if ok and ent and ent ~= 0 then return ent end
    return nil
end
function N.townAt(c) return Inv(0x43AD8FC02B429D33, c.x, c.y, c.z, 1, Citizen.ResultAsInteger()) end

-- light at the preview camera
function N.light(x, y, z, range, intensity) Inv(0xD2D9E04C0DF927F4, x + 0.0, y + 0.0, z + 0.0, 255, 255, 255, range + 0.0, intensity + 0.0) end

-- wagon look --------------------------------------------------------------
function N.vehTint(v, t) Inv(0x8268B098F6FCA4E2, v, t) end
function N.vehLivery(v, l) Inv(0xF89D82A0582E46ED, v, l) end
function N.vehPropset(v, hash) Inv(0x75F90E4051CC084C, v, hash) end
function N.vehLanternPropset(v, hash) Inv(0xC0F0417A90402742, v, hash) end
function N.vehExtra(v, e, on) SetVehicleExtra(v, e, not on) end
function N.vehSeats(model) return GetVehicleModelNumberOfSeats and GetVehicleModelNumberOfSeats(model) or 0 end
function N.vehTintNow(v) return Inv(0xA44D65A8AEC2D3B5, v, Citizen.ResultAsInteger()) end
function N.vehLiveryNow(v) return Inv(0xBB765B8FD49A796C, v, Citizen.ResultAsInteger()) end
