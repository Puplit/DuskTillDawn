-- pup_shaman | the harmful course (driven by the elapsed seconds the server sends) and death reports

Affliction = {}

local token = 0         -- bumped on every change; running loops stop when it moves on
local active = nil      -- { key, course, base, at, fx, walk }

--- Stops every effect of the current course.
function Affliction.Stop()
    token = token + 1
    if not active then return end
    local course = active.course
    if course then
        Shaman.FxStop(course.effect and course.effect.name)
        if course.walk then
            StopAnimTask(PlayerPedId(), course.walk.dict, course.walk.clip, 1.0)
        end
    end
    active = nil
end

local function inBody()
    return Shaman.form == nil and Shaman.dream == nil
end

local function runCourse(mine, course)
    CreateThread(function()
        local lastStep = -1
        local told = {}
        while token == mine and active do
            local elapsed = active.base + (GetGameTimer() - active.at) / 1000
            local step = math.floor(elapsed / course.stepSeconds)
            local ped = PlayerPedId()
            local alive = not Shaman.IsDead(ped)

            -- full-screen effect
            if course.effect and step > course.effect.after then
                if not active.fx then
                    active.fx = true
                    Shaman.FxPlay(course.effect.name)
                    if not told.effect then told.effect = true; Shaman.Tip(L('course_effect')) end
                end
            elseif active.fx then
                active.fx = false
                Shaman.FxStop(course.effect.name)
            end

            -- sick upper-body idle, re-applied whenever it stops
            local w = course.walk
            if w and step > w.after then
                if not told.walk then told.walk = true; Shaman.Tip(L('course_walk')) end
                if alive and inBody() and not IsEntityPlayingAnim(ped, w.dict, w.clip, 3) then
                    Shaman.PlayAnim(ped, w.dict, w.clip, -1, 1 | 16 | 32)
                end
            end

            -- health drain, once per step
            local d = course.drain
            if d and step ~= lastStep and step > d.after and alive and inBody() then
                if not told.drain then told.drain = true; Shaman.Tip(L('course_drain')) end
                local health = GetEntityHealth(ped)
                local loss = math.floor(GetEntityMaxHealth(ped) * d.share)
                local after = health - loss
                if not course.lethal then
                    -- never below the floor, and never raised to it
                    after = math.max(after, math.min(health, course.floor or 100))
                end
                if after < 0 then after = 0 end
                if after < health then SetEntityHealth(ped, after) end
            end
            lastStep = step
            Wait(1000)
        end
    end)
end

-- a curse that lifts on death: report any death outside a form (deaths in a form are reported by the form)
local function watchDeath(mine)
    CreateThread(function()
        local reported = false
        while token == mine do
            local dead = Shaman.IsDead()
            if dead and inBody() and not reported then
                reported = true
                TriggerServerEvent('pup_shaman:server:died', false)
            elseif not dead then
                reported = false
            end
            Wait(1000)
        end
    end)
end

--- Starts (or restarts) whatever the curse needs on this client.
function Affliction.Set(key, elapsed)
    Affliction.Stop()
    local def = Rules.Curse(key)
    if not def then return end
    local mine = token
    local course = Rules.CourseOf(key)
    active = { key = key, course = course, base = math.max(0, elapsed or 0), at = GetGameTimer(), fx = false }
    if course then runCourse(mine, course) end
    if def.liftOnDeath then watchDeath(mine) end
end
