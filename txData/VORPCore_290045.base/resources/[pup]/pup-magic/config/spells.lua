-- pup-magic | spells, cast with Alt + key. Fields and effects are listed in README.md.
-- blast tag: 24 lantern, 25 dynamite, 27 volatile | damage 0 = knockback only

Config.Blasts = {
    engineDamage = 0.0, -- 0 = only scripted damage (horses/NPCs safe)
    shake        = 0.6,
}

Config.Spells = {
    smoke = {
        key = 'NUMPAD1', casters = { 'puppet' }, effect = 'smoke',
        emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx    = { asset = 'scr_odd_fellows', name = 'scr_river5_magician_smoke_loop', radius = 20.0, duration = 10, scale = 0.7 },
        notif = Locale.smokeCast,
    },

    lightning = {
        key = 'NUMPAD2', casters = { 'puppet' }, effect = 'lightning',
        emote  = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        damage = 110,
        notif  = Locale.lightningCast,
    },

    shock = {
        key = 'NUMPAD3', casters = { 'puppet' }, effect = 'shock',
        emote    = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        duration = 5,
        sparks   = 'ent_sht_electrical_box',
        noTarget = Locale.shockNoTarget,
    },

    aimdot = {
        key = 'NUMPAD4', casters = { 'puppet', 'reze' }, effect = 'aimdot',
    },

    flex = {
        key = 'NUMPAD5', casters = { 'puppet', 'reze', 'flex' }, effect = 'anim',
        anim = { dict = 'script_shows@flexfight@act2', name = 'female_flexfight_p1', dur = 2000 },
    },

    frog = {
        key = 'NUMPAD6', casters = { 'puppet' }, effect = 'transform',
        emote    = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        model    = 'A_C_FrogBull_01',
        duration = 10,
        noTarget = Locale.frogNoTarget,
        notif    = { on = Locale.frogOn, off = Locale.frogOff },
    },

    butter = {
        key = '1', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'core', name = 'ent_amb_insect_butterfly_swarm3', bone = 464, off = { x = 0.0, y = 0.0, z = -5.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 3.0 },
    },
    flies = {
        key = '2', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'core', name = 'ent_amb_insect_fly_swarm', bone = 464, off = { x = 0.0, y = 0.0, z = -5.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 2.0 },
    },
    bees = {
        key = '3', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'core', name = 'ent_amb_insect_bee_swarm', bone = 464, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },
    blur = {
        key = '4', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'scr_net_camp', name = 'scr_net_animal_ghost', bone = 464, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },
    embers = {
        key = '5', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'scr_net_race_checkpoints', name = 'scr_mp_item_pickup_highlight', bone = 464, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },
    snow = {
        key = '6', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'core', name = 'ent_amb_wind_snowfall', bone = 464, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },
    aura = {
        key = '7', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'scr_net_camp', name = 'scr_net_spirit_animal_fade', bone = 464, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },
    redtail = {
        key = '8', casters = { 'puppet' }, effect = 'aura', emote = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
        fx = { dict = 'scr_deadeye', name = 'scr_de_watch_wisps', bone = 97, off = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.5 },
    },

    -- bomb kit: pinpull switches it on
    pinpull = {
        key = 'NUMPAD7', casters = { 'reze' }, effect = 'aura', self = true,
        emote = 'KIT_EMOTE_TAUNT_THROAT_SLIT_1',
        fx = {
            { dict = 'core', name = 'fire_ped_limb',          boneName = 'SKEL_Head',   off = { x = 0.0, y = 0.0, z = 0.05 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 0.9 },
            { dict = 'core', name = 'proj_dynamite_fuse',     boneName = 'SKEL_Neck0',  off = { x = 0.0, y = 0.0, z = 0.10 }, rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 1.2 },
            { dict = 'core', name = 'ent_amb_falling_embers', boneName = 'SKEL_Spine4', off = { x = 0.0, y = 0.0, z = 0.6 },  rot = { x = 0.0, y = 0.0, z = 0.0 }, scale = 0.6 },
        },
        pop   = { tag = 27, size = 1.2, damage = 0, radius = 5.0, force = 16.0 },
        notif = { on = Locale.pinOn, off = Locale.pinOff },
    },
    bombpunch = {
        key = 'NUMPAD8', casters = { 'reze' }, effect = 'bombpunch', requires = 'pinpull',
        emote    = 'KIT_EMOTE_ACTION_FIST_PUMP_1',
        range    = 25.0,
        tag      = 25, size = 0.8,
        damage   = 0, radius = 4.0, force = 14.0,
        cooldown = 6,
        notif    = Locale.bombPunch,
    },
    bombtoss = {
        key = 'NUMPAD9', casters = { 'reze' }, effect = 'bombtoss', requires = 'pinpull',
        emote    = 'KIT_EMOTE_ACTION_SKYWARD_SHOOTING_1',
        range    = 60.0,
        delay    = 900, -- ms
        tag      = 27, size = 1.2,
        damage   = 0, radius = 6.0, force = 18.0,
        cooldown = 10,
        notif    = Locale.bombToss,
    },
    rocketleap = {
        key = '9', casters = { 'reze' }, effect = 'rocketleap', requires = 'pinpull',
        tag      = 24, size = 0.6,
        launch   = { forward = 22.0, up = 12.0 },
        cooldown = 5,
    },
    detonate = {
        keys = { '0', 'NUMPAD0' }, casters = { 'reze' }, effect = 'detonate', requires = 'pinpull',
        emote      = 'KIT_EMOTE_TAUNT_WAR_CRY_1',
        tag        = 27, size = 1.5, ring = 5, ringRadius = 3.0,
        damage     = 0, radius = 9.0, force = 24.0,
        selfDamage = 0,
        cooldown   = 45,
        notif      = Locale.detonate,
    },
}
