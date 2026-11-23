-- murphy_radialmenu -- shared config
-- ----------------------------------------------------------------------------
-- Each slot's `action` is one of:
--
--   { type = 'command',     value = 'cmdName' }          -- or 'cmdName arg1 arg2'
--   { type = 'event',       value = 'resource:client:eventName' }
--   { type = 'serverEvent', value = 'resource:server:eventName' }
--   { type = 'export',      value = { 'resource', 'fnName' } }
--   { type = 'callback',    value = function(slotId, path, target) end }
--
-- Optional `args` array is forwarded to event / serverEvent / export actions.
-- Slots with `children` open a sub-menu in the NUI; their `action` is ignored.
--
-- Optional slot fields:
--   description = '...'    -- helper line under the label on hover
--   disabled = true        -- greyed out, not clickable
--   stayOpen = true        -- run the action but keep the wheel open
--   visibleWhen = fn       -- return false to hide the slot for this open.
--                             Runs on every open: keep it fast, non-blocking.
--   childrenBuilder = fn   -- build `children` at open time from live state
--   delay = <ms>           -- wait before running `action`; use when chaining
--                             into another NUI so the confirming click doesn't
--                             bleed into it
--   target = 'closest' | 'nearby' | 'cursor'
--                          -- the action needs another player: their server
--                             id is injected into the command / args (see
--                             Config.Target below for the three modes)
--   targetRange = <m>      -- per-slot override of Config.Target.Range
--
-- Icons: file name (no extension) of a PNG in ui/build/assets/icons/,
-- rendered in white. Full reference: README.md.
-- ----------------------------------------------------------------------------

Config = {}

-- UI chrome language (must match a file in ui/build/locales/*.js).
-- Bundled: en, fr, ar, cs, de, es, hu, it, ja, ko, nl, pl, pt-BR, ro, ru,
-- sv, tr, uk, zh-CN, zh-TW. Slot labels are plain strings -- translate them
-- directly in this file / the integrations.
Config.Locale = 'en'

-- Control that opens the wheel. Set ONE of:
--   Config.OpenControl = <hash> -- RDR3 control hash, TOGGLE (press to open,
--                                  press to close). Use for mouse buttons.
--   Config.OpenKey     = 'B'    -- keyboard key, HOLD-to-show. Accepts A-Z,
--                                  0-9, F1-F12, TAB, SPACE, LSHIFT, LCTRL...
-- Default: middle mouse click (INPUT_ATTACK2). Its native effect (secondary
-- attack) is suppressed while this resource owns the bind.
-- pup: F1, registered through the GAME'S OWN keybind system, so it appears in
-- Settings > Key Bindings > FiveM and every player can rebind it themselves,
-- exactly like the inventory key. This is a TOGGLE: press to open, press again
-- to close. It is not hold-to-show.
--
-- Set this to false to fall back to the stock binds below (OpenControl for a
-- toggle on a control hash, OpenKey for hold-to-show on a keyboard key). Those
-- two are ignored entirely while this is set, and neither is rebindable.
Config.OpenKeyMapping      = 'F1'
Config.OpenKeyMappingLabel = 'Open Radial Menu'   -- the name shown in the settings list

-- Config.OpenControl = 0xCEE12B50
-- Config.OpenKey = 'B'

-- Optional keys that open a specific wheel directly, skipping the context
-- wheel (hold-to-show, like Config.OpenKey). Menu ids are keys of
-- Config.Menus — integrations register theirs too (e.g. murphy_clothing
-- registers `clothing`). The same menus are also reachable with
-- `/radial <menuId>`.
Config.DirectMenuKeys = {
  -- clothing = 'J',
}

-- Player-targeted slots. A slot with `target = ...` resolves another player
-- before running its action, so commands like `/cuff <id>` work from the
-- wheel without typing an id:
--   'closest' -> nearest player within range, no extra step
--   'nearby'  -> the slot becomes a sub-wheel listing the players in range
--   'cursor'  -> click a player on screen (name tag over each head)
-- The server id replaces `{target}` (and the player name `{targetName}`) in
-- the command line / event args. Without a placeholder the id is appended
-- as the last argument: value = 'cuff' runs `cuff 12`. Callbacks receive
-- it as a third parameter: function(slotId, path, target) with
-- target = { serverId, playerId, name, dist }.
Config.Target = {
  Range          = 5.0,   -- meters; players farther away are never offered
  HideWhenNobody = true,  -- hide targeted slots while no player is in range
  ShowServerId   = true,  -- append " [id]" to player names in the wheel / picker
  PickerTimeout  = 15000, -- ms before the on-screen picker gives up (0 = never)

  -- Hover hint under the label of a targeted slot that has no `description`.
  Labels = {
    closest = 'Closest player',
    nearby  = 'Choose a player',
    cursor  = 'Click a player',
  },

  -- Name shown for a player. Default: the RedM player name. Plug your
  -- framework here to show the character name instead. Keep it fast, it
  -- runs for every player in range on each wheel open.
  GetName = function(playerId, serverId)
    return GetPlayerName(playerId)
  end,
}

-- Built-in integrations (files in integrations/). Slots only show while the
-- target resource is running, so leaving everything `true` is safe on any
-- server. `false` hard-disables the file.
-- pup: all three OFF. These hook Murphy Workshop's own clothing / doctor / craft
-- resources, none of which run here. Our equivalents are wired by hand below.
Config.Integrations = {
  murphy_clothing = false,
  murphy_doctor   = false,
  murphy_craft    = false,
}

-- First matching context wins; a context whose menu has no visible slots
-- falls through to the next one. Runtime override:
--   exports.radialmenu:setContextResolver(function() return 'menuId' end)
Config.Contexts = {
  { menuId = 'horse',   when = function(ped) return IsPedOnMount(ped) end },
  { menuId = 'vehicle', when = function(ped) return IsPedInAnyVehicle(ped, false) end },
  { menuId = 'player',  when = function(_)   return true end },
}

-- Menu catalog: each menu is `{ title?, logo?, slots = { ... } }`. The menus
-- ship almost empty on purpose -- integrations/ append their slots at load
-- time; add yours here or from your own resources via
--   exports.radialmenu:registerSlot('player', { ... })
-- pup: this resource is named `radialmenu` here, NOT murphy_radialmenu as the
-- README says. The README's export examples need that name swapped.
Config.Menus = {

  -- ON FOOT --------------------------------------------------------------
  --
  -- pup: every slot below runs a command that already existed. Nothing here
  -- redefines an emote or a garment - the definitions stay in their own
  -- resources (pup-misc/emotes, pup_clothing) and this only points at them.
  --
  -- The emote wheel is CURATED, not the full list. There are 46 emotes, 68
  -- animations and 12 walks registered; all of them remain available as
  -- commands, and /emotelist prints the lot to F8. A wheel is for the handful
  -- people reach for constantly. Add or swap entries freely.
  player = {
    title = 'Player',
    slots = {

      { id = 'perks', icon = 'document_player_journal', label = 'Perks',
        description = 'Your progression and perk cards',
        action = { type = 'command', value = 'perks' } },

      { id = 'hud', icon = 'challenge_bandit_1', label = 'HUD',
        description = 'Move and resize the HUD',
        action = { type = 'command', value = 'hud' } },

      -- POSSE: pup-ui owns this. /pose both opens the roster and accepts a
      -- pending invite, so one slot covers form / invite / remove / leave.
      { id = 'posse', icon = 'log_gang_bag', label = 'Posse',
        description = 'Form a posse, invite riders, or leave',
        action = { type = 'command', value = 'pose' } },

      -- HUNTING BIRD: /callbird is registered SERVER side, and a 'command' action
      -- is ExecuteCommand on the CLIENT, which would never reach it. The command
      -- only fires this client event anyway, so the slot triggers it directly.
      { id = 'callbird', icon = 'bird', label = 'Hunting Bird',
        description = 'Call, sell, or send your bird home',
        visibleWhen = function() return GetResourceState('huntingbirds') == 'started' end,
        action = { type = 'event', value = 'huntingbirds:callowneds' } },

      -- LAWMAN: only while clocked on. visibleWhen runs every time the wheel
      -- opens, so going off duty removes it with no event wiring on this side.
      -- Falls closed if pup-mdt is down: a missing export must not hand police
      -- tools to everyone. (pup-mdt/client/lawmen.lua provides IsOnDuty.)
      { id = 'lawman', icon = 'provision_deputy_star', label = 'Lawman',
        description = 'On-duty tools',
        visibleWhen = function()
          if GetResourceState('pup-mdt') ~= 'started' then return false end
          local ok, on = pcall(function() return exports['pup-mdt']:IsOnDuty() end)
          return ok and on == true
        end,
        children = {
          { id = 'mdt',      icon = 'document_player_journal',        label = 'MDT',          action = { type = 'command', value = 'mdt' } },
          { id = 'backup',   icon = 'provision_deputy_star',          label = 'Backup',       action = { type = 'command', value = 'backup' } },
          { id = 'lawdown',  icon = 'consumable_medicine',            label = 'Lawman Down',  action = { type = 'command', value = 'down' } },
          { id = 'cancelal', icon = '_back',                          label = 'Cancel Alert', action = { type = 'command', value = 'cancelalert' } },
          { id = 'jailtime', icon = 'provision_cc_vintage_handcuffs', label = 'Jail Time',    action = { type = 'command', value = 'jailtime' } },
          { id = 'offduty',  icon = 'settings',                       label = 'Go Off Duty',  action = { type = 'command', value = 'offduty' } },
        } },

      -- CLOTHING: quick toggles from pup_clothing (Config.ToggleCommands)
      { id = 'clothing', icon = 'clothing_generic_outfit', label = 'Clothing',
        children = {
          { id = 'hat',      icon = 'clothing_generic_hat',          label = 'Hat',        stayOpen = true, action = { type = 'command', value = 'hat' } },
          { id = 'mask',     icon = 'clothing_generic_mask',         label = 'Mask',       stayOpen = true, action = { type = 'command', value = 'mask' } },
          { id = 'neckwear', icon = 'clothing_generic_neckerchief',  label = 'Neckwear',   stayOpen = true, action = { type = 'command', value = 'neckwear' } },
          { id = 'eyewear',  icon = 'clothing_generic_mask',         label = 'Eyewear',    stayOpen = true, action = { type = 'command', value = 'eyewear' } },
          { id = 'coat',     icon = 'clothing_generic_coat',         label = 'Coat',       stayOpen = true, action = { type = 'command', value = 'coat' } },
          { id = 'vest',     icon = 'clothing_generic_vest',         label = 'Vest',       stayOpen = true, action = { type = 'command', value = 'vest' } },
          { id = 'shirt',    icon = 'clothing_generic_shirt',        label = 'Shirt',      stayOpen = true, action = { type = 'command', value = 'shirt' } },
          { id = 'gloves',   icon = 'clothing_generic_glove',        label = 'Gloves',     stayOpen = true, action = { type = 'command', value = 'gloves' } },
          { id = 'chaps',    icon = 'clothing_generic_chaps',        label = 'Chaps',      stayOpen = true, action = { type = 'command', value = 'chaps' } },
          { id = 'boots',    icon = 'clothing_generic_boots',        label = 'Boots',      stayOpen = true, action = { type = 'command', value = 'boots' } },
          { id = 'poncho',   icon = 'clothing_generic_cloak',        label = 'Poncho',     stayOpen = true, action = { type = 'command', value = 'poncho' } },
          { id = 'suspend',  icon = 'clothing_generic_suspenders',   label = 'Suspenders', stayOpen = true, action = { type = 'command', value = 'suspenders' } },
          { id = 'pants',    icon = 'clothing_generic_pants',        label = 'Pants',      stayOpen = true, action = { type = 'command', value = 'pants' } },
          { id = 'skirt',    icon = 'clothing_generic_skirt',        label = 'Skirt',      stayOpen = true, action = { type = 'command', value = 'skirt' } },
        } },

      -- EMOTES: pup-misc/emotes. /sa stops whatever is playing.
      { id = 'emotes', icon = 'emote_dance_wild_a', label = 'Emotes',
        children = {

          { id = 'greet', icon = 'emote_action_stop_here', label = 'Greetings',
            children = {
              { id = 'wave',       icon = 'emote_action_stop_here', label = 'Wave',        action = { type = 'command', value = 'wave' } },
              { id = 'tiphat',     icon = 'clothing_generic_hat',   label = 'Tip Hat',     action = { type = 'command', value = 'tiphat' } },
              { id = 'hatflick',   icon = 'clothing_generic_hat',   label = 'Hat Flick',   action = { type = 'command', value = 'hatflick' } },
              { id = 'bow',        icon = 'emote_reaction_amazed_1', label = 'Bow',        action = { type = 'command', value = 'bow' } },
              { id = 'fancybow',   icon = 'emote_reaction_amazed_1', label = 'Fancy Bow',  action = { type = 'command', value = 'fancybow' } },
              { id = 'thumbsup',   icon = 'emote_action_stop_here', label = 'Thumbs Up',   action = { type = 'command', value = 'thumbsup' } },
              { id = 'nod',        icon = 'emote_action_stop_here', label = 'Nod',         action = { type = 'command', value = 'nod' } },
              { id = 'clap',       icon = 'emote_action_stop_here', label = 'Clap',        action = { type = 'command', value = 'clap' } },
            } },

          { id = 'react', icon = 'emote_reaction_amazed_1', label = 'Reactions',
            children = {
              { id = 'laugh',      icon = 'emote_reaction_amazed_1', label = 'Laugh',      action = { type = 'command', value = 'laugh' } },
              { id = 'pointlaugh', icon = 'emote_reaction_amazed_1', label = 'Point Laugh',action = { type = 'command', value = 'pointlaugh' } },
              { id = 'yeehaw',     icon = 'emote_reaction_amazed_1', label = 'Yeehaw',     action = { type = 'command', value = 'yeehaw' } },
              { id = 'hush',       icon = 'emote_reaction_amazed_1', label = 'Hush',       action = { type = 'command', value = 'hush' } },
              { id = 'thumbsdown', icon = 'emote_reaction_amazed_1', label = 'Thumbs Down',action = { type = 'command', value = 'thumbsdown' } },
              { id = 'flex',       icon = 'emote_reaction_amazed_1', label = 'Flex',       action = { type = 'command', value = 'flex' } },
              { id = 'blowkiss',   icon = 'emote_reaction_amazed_1', label = 'Blow Kiss',  action = { type = 'command', value = 'blowkiss' } },
              { id = 'checkwatch', icon = 'emote_reaction_amazed_1', label = 'Check Watch',action = { type = 'command', value = 'checkwatch' } },
            } },

          { id = 'dance', icon = 'emote_dance_formal_a', label = 'Dance',
            children = {
              { id = 'dsimple',  icon = 'emote_dance_formal_a', label = 'Simple',   action = { type = 'command', value = 'dancesimple' } },
              { id = 'dformal',  icon = 'emote_dance_formal_a', label = 'Formal',   action = { type = 'command', value = 'danceformal' } },
              { id = 'dcarefree',icon = 'emote_dance_wild_a',   label = 'Carefree', action = { type = 'command', value = 'dancecarefree' } },
              { id = 'dconf',    icon = 'emote_dance_wild_a',   label = 'Confident',action = { type = 'command', value = 'danceconfident' } },
              { id = 'dwild',    icon = 'emote_dance_wild_a',   label = 'Wild',     action = { type = 'command', value = 'dancewild' } },
              { id = 'ddrunk',   icon = 'emote_dance_wild_a',   label = 'Drunk',    action = { type = 'command', value = 'dancedrunk' } },
              { id = 'dold',     icon = 'emote_dance_formal_a', label = 'Old Time', action = { type = 'command', value = 'danceold' } },
              { id = 'djig',     icon = 'emote_dance_wild_a',   label = 'Jig',      action = { type = 'command', value = 'jig' } },
            } },

          -- POSES: the standing/idle set, plus RDR2's own photo-studio and
          -- photo-scene poses from pup-misc/emotes/poses.lua (/pose <id>)
          { id = 'poses', icon = 'emote_action_stop_here', label = 'Poses',
            children = {

              { id = 'pstudio', icon = 'emote_reaction_amazed_1', label = 'Studio',
                children = {
                  { id = 'flex',      icon = 'emote_reaction_amazed_1', label = 'Flex',        action = { type = 'command', value = 'photopose flex' } },
                  { id = 'comeatme',  icon = 'emote_reaction_amazed_1', label = 'Come At Me',  action = { type = 'command', value = 'photopose comeatme' } },
                  { id = 'raisehand', icon = 'emote_action_stop_here',  label = 'Raise Hand',  action = { type = 'command', value = 'photopose raisehand' } },
                  { id = 'holdsign',  icon = 'emote_action_stop_here',  label = 'Hold Sign',   action = { type = 'command', value = 'photopose holdsign' } },
                  { id = 'foryou',    icon = 'emote_reaction_amazed_1', label = 'For You',     action = { type = 'command', value = 'photopose foryou' } },
                  { id = 'salute',    icon = 'emote_action_stop_here',  label = 'Salute',      action = { type = 'command', value = 'photopose salute' } },
                } },

              { id = 'pgun', icon = 'emote_action_stop_here', label = 'Gunslinger',
                children = {
                  { id = 'duel1',      icon = 'emote_action_stop_here', label = 'Double Guns',   action = { type = 'command', value = 'photopose duel1' } },
                  { id = 'duel2',      icon = 'emote_action_stop_here', label = 'Double Guns 2', action = { type = 'command', value = 'photopose duel2' } },
                  { id = 'duel3',      icon = 'emote_action_stop_here', label = 'Micah Pose',    action = { type = 'command', value = 'photopose duel3' } },
                  { id = 'bell1',      icon = 'emote_action_stop_here', label = 'Shoulder Rifle',action = { type = 'command', value = 'photopose bell1' } },
                  { id = 'bell2',      icon = 'emote_action_stop_here', label = 'Guns Ready',    action = { type = 'command', value = 'photopose bell2' } },
                  { id = 'johnphoto',  icon = 'emote_reaction_amazed_1', label = 'Couple Photo', action = { type = 'command', value = 'photopose johnphoto' } },
                  { id = 'johnphoto2', icon = 'emote_reaction_amazed_1', label = 'Couple 2',     action = { type = 'command', value = 'photopose johnphoto2' } },
                } },

              { id = 'prifle', icon = 'emote_action_stop_here', label = 'Rifle',
                children = {
                  { id = 'rifleseat',  icon = 'emote_action_stop_here', label = 'Seated Rifle',  action = { type = 'command', value = 'photopose rifleseat' } },
                  { id = 'rifleshldr', icon = 'emote_action_stop_here', label = 'On Shoulder',   action = { type = 'command', value = 'photopose rifleshldr' } },
                  { id = 'riflestand', icon = 'emote_action_stop_here', label = 'Standing',      action = { type = 'command', value = 'photopose riflestand' } },
                  { id = 'riflehold',  icon = 'emote_action_stop_here', label = 'Holding',       action = { type = 'command', value = 'photopose riflehold' } },
                  { id = 'riflerest',  icon = 'emote_action_stop_here', label = 'At Rest',       action = { type = 'command', value = 'photopose riflerest' } },
                  { id = 'gator',      icon = 'emote_action_stop_here', label = 'Trophy',        action = { type = 'command', value = 'photopose gator' } },
                  { id = 'gator2',     icon = 'emote_action_stop_here', label = 'Trophy 2',      action = { type = 'command', value = 'photopose gator2' } },
                  { id = 'gator3',     icon = 'emote_action_stop_here', label = 'Soldier',       action = { type = 'command', value = 'photopose gator3' } },
                } },

              { id = 'pgroup', icon = 'emote_action_stop_here', label = 'Group Photo',
                children = {
                  { id = 'posseroyal', icon = 'emote_action_stop_here', label = 'Royal Seat',   action = { type = 'command', value = 'photopose posseroyal' } },
                  { id = 'possetall',  icon = 'emote_action_stop_here', label = 'Standing Tall',action = { type = 'command', value = 'photopose possetall' } },
                  { id = 'possesit',   icon = 'emote_action_stop_here', label = 'Seated',       action = { type = 'command', value = 'photopose possesit' } },
                  { id = 'possesit2',  icon = 'emote_action_stop_here', label = 'Seated 2',     action = { type = 'command', value = 'photopose possesit2' } },
                  { id = 'rowstag',    icon = 'emote_action_stop_here', label = 'Row Stagger',  action = { type = 'command', value = 'photopose rowstag' } },
                  { id = 'crossarms2', icon = 'emote_action_stop_here', label = 'Arms Crossed', action = { type = 'command', value = 'photopose crossarms2' } },
                  { id = 'pistolrow',  icon = 'emote_action_stop_here', label = 'Pistols Row',  action = { type = 'command', value = 'photopose pistolrow' } },
                  { id = 'pistolv',    icon = 'emote_action_stop_here', label = 'Pistols V',    action = { type = 'command', value = 'photopose pistolv' } },
                } },

              { id = 'pportrait', icon = 'emote_reaction_amazed_1', label = 'Portrait',
                children = {
                  { id = 'rdo1',     icon = 'emote_action_stop_here', label = 'Hands To Sky',  action = { type = 'command', value = 'photopose rdo1' } },
                  { id = 'rdo2',     icon = 'emote_action_stop_here', label = 'Head In Hands', action = { type = 'command', value = 'photopose rdo2' } },
                  { id = 'rdo3',     icon = 'emote_action_stop_here', label = 'Lean Back',     action = { type = 'command', value = 'photopose rdo3' } },
                  { id = 'rdo4',     icon = 'emote_action_stop_here', label = 'Duel Loss',     action = { type = 'command', value = 'photopose rdo4' } },
                  { id = 'rdo5',     icon = 'emote_action_stop_here', label = 'Sneaky',        action = { type = 'command', value = 'photopose rdo5' } },
                  { id = 'rdo6',     icon = 'emote_action_stop_here', label = 'Fancy',         action = { type = 'command', value = 'photopose rdo6' } },
                  { id = 'rdopair1', icon = 'emote_action_stop_here', label = 'Lean On Fence', action = { type = 'command', value = 'photopose rdopair1' } },
                  { id = 'rdopair2', icon = 'emote_action_stop_here', label = 'Photo Bomb',    action = { type = 'command', value = 'photopose rdopair2' } },
                } },

              { id = 'pbounty', icon = 'emote_action_stop_here', label = 'Bounty',
                children = {
                  { id = 'bounty1',    icon = 'emote_action_stop_here', label = 'Bounty Hunter', action = { type = 'command', value = 'photopose bounty1' } },
                  { id = 'bounty2',    icon = 'emote_action_stop_here', label = 'Bounty Guns',   action = { type = 'command', value = 'photopose bounty2' } },
                  { id = 'bounty3',    icon = 'emote_action_stop_here', label = 'Hands Up',      action = { type = 'command', value = 'photopose bounty3' } },
                  { id = 'bounty4',    icon = 'emote_action_stop_here', label = 'Bounty Aim',    action = { type = 'command', value = 'photopose bounty4' } },
                  { id = 'pistolrow2', icon = 'emote_action_stop_here', label = 'Pistols Drawn', action = { type = 'command', value = 'photopose pistolrow2' } },
                  { id = 'pistolrow3', icon = 'emote_action_stop_here', label = 'Pistols Cross', action = { type = 'command', value = 'photopose pistolrow3' } },
                } },

              { id = 'pseated', icon = 'emote_action_stop_here', label = 'Seated',
                children = {
                  { id = 'crate',     icon = 'emote_action_stop_here', label = 'On A Crate', action = { type = 'command', value = 'photopose crate' } },
                  { id = 'dog1',      icon = 'emote_action_stop_here', label = 'With Dog',   action = { type = 'command', value = 'photopose dog1' } },
                  { id = 'dog2',      icon = 'emote_action_stop_here', label = 'With Dog 2', action = { type = 'command', value = 'photopose dog2' } },
                  { id = 'dog3',      icon = 'emote_action_stop_here', label = 'With Dog 3', action = { type = 'command', value = 'photopose dog3' } },
                  { id = 'sitground', icon = 'emote_action_stop_here', label = 'Sit Ground', action = { type = 'command', value = 'sitground' } },
                  { id = 'sleep',     icon = 'emote_action_stop_here', label = 'Sleep',      action = { type = 'command', value = 'sleep' } },
                } },

              -- the original standing set, kept where people expect it
              { id = 'pclassic', icon = 'emote_action_stop_here', label = 'Classic',
                children = {
                  { id = 'crossarms', icon = 'emote_action_stop_here', label = 'Cross Arms', action = { type = 'command', value = 'crossarms' } },
                  { id = 'handsbelt', icon = 'emote_action_stop_here', label = 'Hands Belt', action = { type = 'command', value = 'handsbelt' } },
                  { id = 'leanrail',  icon = 'emote_action_stop_here', label = 'Lean',       action = { type = 'command', value = 'leanrail' } },
                  { id = 'guard',     icon = 'emote_action_stop_here', label = 'Guard',      action = { type = 'command', value = 'guard' } },
                  { id = 'smoke2',    icon = 'emote_action_stop_here', label = 'Wait',       action = { type = 'command', value = 'wait1' } },
                  { id = 'writing',   icon = 'emote_action_stop_here', label = 'Write',      action = { type = 'command', value = 'writing' } },
                } },
            } },

          { id = 'hands', icon = 'emote_action_stop_here', label = 'Surrender',
            children = {
              { id = 'handsup',   icon = 'emote_action_stop_here', label = 'Hands Up',  action = { type = 'command', value = 'handsup' } },
              { id = 'surrender', icon = 'emote_action_stop_here', label = 'Surrender', action = { type = 'command', value = 'surrender' } },
              { id = 'prisoner',  icon = 'emote_action_stop_here', label = 'Prisoner',  action = { type = 'command', value = 'prisoner' } },
              { id = 'cover',     icon = 'emote_action_stop_here', label = 'Cover',     action = { type = 'command', value = 'cover' } },
            } },

          { id = 'walks', icon = 'emote_dance_formal_a', label = 'Walk Style',
            children = {
              { id = 'wcasual',   icon = 'emote_dance_formal_a', label = 'Casual',     action = { type = 'command', value = 'walkcasual' } },
              { id = 'wgunsling', icon = 'emote_dance_formal_a', label = 'Gunslinger', action = { type = 'command', value = 'walkgunslinger' } },
              { id = 'wrefined',  icon = 'emote_dance_formal_a', label = 'Refined',    action = { type = 'command', value = 'walkrefined' } },
              { id = 'wveteran',  icon = 'emote_dance_formal_a', label = 'Veteran',    action = { type = 'command', value = 'walkveteran' } },
              { id = 'wflamboy',  icon = 'emote_dance_wild_a',   label = 'Flamboyant', action = { type = 'command', value = 'walkflamboyant' } },
              { id = 'wdrunk',    icon = 'emote_dance_wild_a',   label = 'Drunk',      action = { type = 'command', value = 'walkdrunk' } },
              { id = 'wcurious',  icon = 'emote_dance_formal_a', label = 'Curious',    action = { type = 'command', value = 'walkcurious' } },
              { id = 'wreset',    icon = '_back',                label = 'Reset',      action = { type = 'command', value = 'walkreset' } },
              -- vorp_walkanim's own menu, for the styles not shortcut above
              { id = 'wmenu',     icon = 'emote_dance_formal_a', label = 'All Styles', description = 'Open the full walk style menu',
                action = { type = 'command', value = 'walkanim' } },
            } },

          -- SCENARIOS: pup-misc/scenario's own list menu. Far too many entries
          -- to mirror as slots, so this opens it rather than duplicating it -
          -- one slot that stays right whenever that list changes.
          -- `delay`: /scenario opens a pup-ui LIST, and that list is clickable
          -- (pup-ui html/app.js binds click -> listSelect). Without the wait the
          -- click that picked this slot lands on the list as it appears and
          -- fires its first row. This is the case the header note is about.
          { id = 'scenarios', icon = 'kit_camp', label = 'Scenarios',
            description = 'Leaning, working, sitting and the rest',
            delay = 250,
            action = { type = 'command', value = 'scenario' } },

          { id = 'stopemote', icon = '_back', label = 'Stop',
            description = 'Stop whatever you are doing',
            action = { type = 'command', value = 'sa' } },
        } },

      -- STOP: /sa drops whatever emote, animation or scenario is playing.
      -- Also sits inside Emotes, but it is needed often enough to earn a top slot.
      { id = 'stopanim', icon = 'emote_action_stop_here', label = 'Stop',
        description = 'Stop the animation you are doing',
        action = { type = 'command', value = 'sa' } },

      -- PROPS: /pa picks a worn prop and moves it (pup-misc/props)
      -- every pouch icon in the set reads as the same satchel at wheel size, so
      -- the top ring deliberately uses eight different silhouettes instead.
      { id = 'props', icon = 'settings', label = 'Adjust Prop',
        description = 'Move a prop you are wearing',
        action = { type = 'command', value = 'pa' } },

      -- WEAPON OFFSETS: /wp edits a spawned custom weapon (pup_armory)
      { id = 'weaponpos', icon = 'clothing_generic_gunbelt', label = 'Adjust Weapon',
        description = 'Move a custom weapon on your body',
        action = { type = 'command', value = 'wp' } },

      -- Example slot -- uncomment and adapt.
      -- { id = 'emotes', icon = 'emote_dance_wild_a', label = 'Emotes',
      --   children = {
      --     { id = 'dance', icon = 'emote_dance_formal_a', label = 'Dance',
      --       description = 'One little jig',
      --       action = { type = 'command', value = 'dance' } },
      --     { id = 'wave',  icon = 'emote_action_stop_here', label = 'Wave',
      --       stayOpen = true,
      --       action = { type = 'event', value = 'myemotes:client:play', args = { 'wave' } } },
      --   } },

      -- Player-targeted slots (see Config.Target). `{target}` becomes the
      -- server id of the picked player. Uncomment and adapt.
      -- { id = 'police', icon = 'provision_deputy_star', label = 'Police',
      --   children = {
      --     { id = 'cuff', icon = 'provision_cc_vintage_handcuffs', label = 'Cuff',
      --       target = 'cursor',                     -- click the player on screen
      --       action = { type = 'command', value = 'cuff {target}' } },
      --     { id = 'search', icon = 'kit_pouch_valuables', label = 'Search',
      --       target = 'closest',                    -- nearest player, no extra step
      --       action = { type = 'command', value = 'search' } },   -- runs "search 12"
      --     { id = 'escort', icon = 'emote_action_stop_here', label = 'Escort',
      --       target = 'nearby',                     -- sub-wheel of nearby players
      --       action = { type = 'serverEvent', value = 'police:server:escort', args = { '{target}' } } },
      --   } },
    },
  },

  -- MOUNTED --------------------------------------------------------------
  -- Empty by default: integrations add their mounted slots here. While it
  -- stays empty, opening from the saddle falls through to `player`.
  horse = {
    title = 'Horse',
    slots = {},
  },

  -- IN A VEHICLE / WAGON --------------------------------------------------
  vehicle = {
    title = 'Wagon',
    slots = {},
  },

}
