-- pup-mdt | permissions, overrides and rank names

Perms = { overrides = {} }

-- lawyer grades join the permission table for every lawyer job
for perm, grade in pairs(Config.Legal.permissions) do
    Config.Permissions[perm] = Config.Permissions[perm] or {}
    for _, job in ipairs(Config.Legal.jobs) do
        Config.Permissions[perm][job] = grade
    end
end

function Perms.base(job, grade, perm)
    local req = Config.Permissions[perm]
    if req == nil then return MDT.isLawJob(job) end
    local r = req[job]
    if r == nil then return false end
    if type(r) == 'number' then return (tonumber(grade) or 0) >= r end
    if type(r) == 'table' then
        for _, g in ipairs(r) do if g == tonumber(grade) then return true end end
    end
    return false
end

-- overrides first (lawmen only), then the table
function MDT.can(actor, perm)
    if not actor or not actor.job then return false end
    if actor.isLaw then
        local o = Perms.overrides[actor.cid]
        if o and o[perm] ~= nil then return o[perm] == true end
    end
    return Perms.base(actor.job, actor.grade, perm)
end

local toolPerms = {
    bail = { 'viewbail', 'requestbail', 'approvebail' },
    appeals = { 'viewappeals', 'requestappeal', 'approveappeal' },
    defense = { 'viewdefense', 'assigndefense', 'filedefense' },
    expungements = { 'viewexpungements', 'requestexpungement', 'approveexpungement' },
}

-- every permission as true/false for the screen
function Perms.flags(actor)
    local out = {}
    for perm in pairs(Config.Permissions) do out[perm] = MDT.can(actor, perm) end
    for tool, list in pairs(toolPerms) do
        if not Config.Legal.tools[tool] then
            for _, p in ipairs(list) do out[p] = false end
        end
    end
    if actor.isLawyer and not Config.Legal.firmLedger.enabled then
        out.firmledger, out.ledger, out.ledgerdeposit, out.ledgerwithdraw = false, false, false, false
    end
    if not Config.Legal.enabled then
        out.viewbarroster, out.firelawyers, out.viewlawyerprofile, out.firmsettings, out.firmhome = false, false, false, false, false
    end
    -- deposit is only usable where the ledger can be seen
    if not out.ledger then out.ledgerdeposit, out.ledgerwithdraw = false, false end
    return out
end

-- what the job and grade grant before overrides
function Perms.defaults(job, grade)
    local out = {}
    for perm in pairs(Config.Permissions) do out[perm] = Perms.base(job, grade, perm) end
    return out
end

function Perms.load()
    local rows = DB.q('SELECT citizenid, permissions FROM mdt_permissions_overrides')
    local map = {}
    for _, r in ipairs(rows) do
        local t = MDT.jdec(r.permissions, {})
        if type(t) == 'table' then map[tostring(r.citizenid)] = t end
    end
    Perms.overrides = map
end

---------------------------------------------------------------------------
-- Rank names
---------------------------------------------------------------------------
function Perms.policeRank(grade)
    grade = tonumber(grade) or 0
    local key = 'grade_' .. grade
    local s = L(key)
    if s ~= key then return s end
    local ladder = Config.FallbackRanks.police
    local idx = math.min(#ladder, math.max(1, grade + 1))
    return L(ladder[idx])
end

function Perms.rankName(job, grade)
    if MDT.isLawyerJob(job) then
        return Config.Legal.ranks[tonumber(grade) or 0] or Config.Legal.footerLabel
    end
    if MDT.isLawJob(job) then return Perms.policeRank(grade) end
    local ladder = Config.FallbackRanks[job]
    if ladder then
        local idx = math.min(#ladder, math.max(1, (tonumber(grade) or 0) + 1))
        return L(ladder[idx])
    end
    return tostring(job or '')
end

exports('GetRankNameByGrade', function(grade) return Perms.policeRank(grade) end)

---------------------------------------------------------------------------
-- Overrides panel
---------------------------------------------------------------------------
MDT.rpc('getPermissionsLawmen', { perm = 'managepermissions', law = true, deny = {} }, function()
    local rows = DB.q([[
        SELECT p.citizen_id, p.region, p.department, c.firstname, c.lastname, c.job, c.jobgrade
        FROM mdt_lawman_profiles p
        LEFT JOIN characters c ON c.charidentifier = p.citizen_id
        WHERE p.is_active = 1
          AND p.id = (SELECT MAX(p2.id) FROM mdt_lawman_profiles p2 WHERE p2.citizen_id = p.citizen_id AND p2.is_active = 1)
        ORDER BY c.jobgrade DESC, c.lastname ASC
        LIMIT 500]])
    local out = {}
    for _, r in ipairs(rows) do
        local cid = tostring(r.citizen_id)
        local grade = tonumber(r.jobgrade) or 0
        local job = r.job or Config.LawJobs[1]
        out[#out + 1] = {
            name = MDT.str((r.firstname or 'Lawman') .. ' ' .. (r.lastname or cid:sub(-4)), 100),
            citizenid = cid,
            rank = Perms.rankName(job, grade),
            region = r.region or '',
            department = r.department or '',
            grade = grade,
            overrides = Perms.overrides[cid] or {},
            defaults = Perms.defaults(job, grade),
        }
    end
    return out
end)

local function refreshTarget(cid)
    local t = MDT.findByCid(cid)
    if t then MDT.pushPlayerData(t) end
end

-- the target's grade: live if they are online, else their saved character
local function targetGrade(cid)
    local src = MDT.findByCid(cid)
    local a = src and MDT.player(src)
    if a then return a.grade end
    return tonumber(DB.val('SELECT jobgrade FROM characters WHERE charidentifier = ?', { cid })) or 0
end

-- only lawmen of a LOWER grade can be changed (so never yourself or a superior)
local function mayManage(actor, cid)
    return cid ~= actor.cid and targetGrade(cid) < (tonumber(actor.grade) or 0)
end

MDT.rpc('saveLawmanPermissions', { perm = 'managepermissions', law = true, duty = true }, function(actor, p)
    local cid = MDT.str(p.citizenid, 50)
    if cid == '' then return { success = false, message = L('perm_invalid_profile_data') } end
    if p.permissions ~= nil and type(p.permissions) ~= 'table' then
        return { success = false, message = L('perm_invalid_profile_data') }
    end
    if not mayManage(actor, cid) then return { success = false, message = L('perm_rank_too_low') } end
    local clean, message = {}, nil
    for perm, v in pairs(p.permissions or {}) do
        -- a permission can only be granted by someone who holds it
        if Config.Permissions[perm] ~= nil and type(v) == 'boolean' and (v == false or MDT.can(actor, perm)) then clean[perm] = v end
    end
    if cid == actor.cid and clean.managepermissions == false then
        clean.managepermissions = nil
        message = L('perm_no_self_remove')
    end
    local name = MDT.str(p.lawman_name, 100)
    DB.q('INSERT INTO mdt_permissions_overrides (citizenid, lawman_name, permissions, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE lawman_name = VALUES(lawman_name), permissions = VALUES(permissions), updated_by = VALUES(updated_by)',
        { cid, name, MDT.jenc(clean), actor.name })
    Perms.overrides[cid] = clean
    MDT.audit(actor, 'permission_changed', cid, name, 'Permission overrides saved', { permissions = clean })
    refreshTarget(cid)
    return { success = true, message = message }
end)

MDT.rpc('resetLawmanPermissions', { perm = 'managepermissions', law = true, duty = true }, function(actor, p)
    local cid = MDT.str(p.citizenid, 50)
    if cid == '' then return { success = false, message = L('perm_invalid_profile_data') } end
    if not mayManage(actor, cid) then return { success = false, message = L('perm_rank_too_low') } end
    DB.q('DELETE FROM mdt_permissions_overrides WHERE citizenid = ?', { cid })
    Perms.overrides[cid] = nil
    MDT.audit(actor, 'permission_changed', cid, MDT.str(p.lawman_name, 100), 'Permission overrides reset')
    refreshTarget(cid)
    return { success = true, reset = true }
end)
