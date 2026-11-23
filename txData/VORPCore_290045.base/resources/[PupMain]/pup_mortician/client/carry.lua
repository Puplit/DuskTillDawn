-- pup_mortician | carrying a closed casket to the burial site (client only)

Carry = { key = nil, obj = nil, blip = nil, session = 0 }

local A = Config.Anim

function Carry.Stop()
    if not Carry.key and not Carry.obj then return end
    local key = Carry.key
    Carry.key = nil
    Carry.session = Carry.session + 1
    DeleteObj(Carry.obj)
    Carry.obj = nil
    DropBlip(Carry.blip)
    Carry.blip = nil
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, A.carryDict, A.carryClip, 3) then
        StopAnimTask(ped, A.carryDict, A.carryClip, 1.0)
    end
    -- the coffin goes back on the table (unless it was buried)
    if key then CreateThread(function() Props.Refresh(key) end) end
end

-- the casket on that table is still closed and ours
local function stillOurs(key)
    local s = TableStates[key]
    return s ~= nil and s.state == 'closed' and s.owner ~= nil and s.owner == Status.charId
end

function Carry.Start(key)
    if Carry.key or not stillOurs(key) then return end
    local hash = LoadModel(Config.Models.coffinClosed)
    if not hash or not LoadDict(A.carryDict) then return end
    if not stillOurs(key) then return end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    local bone = GetEntityBoneIndexByName(ped, A.carryBone)
    local o, r = A.carryOffset, A.carryRot
    AttachEntityToEntity(obj, ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true, false, false)

    Carry.key = key
    Carry.obj = obj
    Carry.session = Carry.session + 1
    local session = Carry.session
    local site = Config.Tables[key].burial
    Carry.blip = AddBlip(site, L('burialSite'))
    Props.Refresh(key)
    Tip(L('carryToSite'))

    CreateThread(function()
        while Carry.session == session do
            local p = PlayerPedId()
            if IsEntityDead(p) or not stillOurs(key) or not Status.undertaker then
                Carry.Stop()
                break
            end
            if not IsEntityPlayingAnim(p, A.carryDict, A.carryClip, 3) then
                -- 49 = loop + upper body + keep moving
                TaskPlayAnim(p, A.carryDict, A.carryClip, 2.0, -2.0, -1, 49, 0.0, false, false, false, '', false)
            end
            Wait(500)
        end
    end)
end
