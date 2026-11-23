-- pup-stable | the one-time free starter horse per character

local S = Config.Starter

function StarterCheck(src)
    if not S.enabled then return end
    local ctx = Ctx(src)
    if not ctx then return end
    -- the claim row goes in first, so two selections at once cannot both grant
    -- affected rows: 1 = this call made the claim, 0 = the character was handled before
    local ok, affected = pcall(MySQL.update.await,
        'INSERT IGNORE INTO stable_starter (charid, identifier, horseid, grantedat) VALUES (?, ?, 0, ?)',
        { ctx.charid, ctx.identifier, os.time() })
    if not ok or U.int(affected, 0) <= 0 then return end
    if #HorsesOf(ctx.charid) > 0 then return end   -- already owns a horse: recorded, nothing given

    local br = Config.BreedById[S.breed]
    local coat = br and br.coats[S.coat]
    if not coat or not StableById(S.stable) then
        print('[pup-stable] starter horse: the configured breed/coat/stable does not exist')
        return
    end
    local good, h = pcall(CreateHorse, {
        identifier = ctx.identifier, charid = ctx.charid, stable = S.stable, model = coat.model, isFemale = S.female, name = S.name,
        speed = S.speed, acceleration = S.acceleration, handling = S.handling, favourite = S.favourite,
    })
    if not good or not h then
        -- failed: drop the claim so the next selection tries again
        MySQL.update('DELETE FROM stable_starter WHERE charid = ? AND horseid = 0', { ctx.charid })
        return
    end
    if S.favourite then SetFavourite(ctx, h.id) end
    MySQL.update('UPDATE stable_starter SET horseid = ? WHERE charid = ?', { h.id, ctx.charid })
    Notify(src, S.message, 8000)
    TriggerClientEvent('pup-stable:listChanged', src)
end
