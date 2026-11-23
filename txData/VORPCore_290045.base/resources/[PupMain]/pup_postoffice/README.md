# pup_postoffice

PO boxes, chats, letters and business mail for a RedM server on VORP Core. Players rent a box at a mail office, then chat and write letters in a themed mail window.

## Features

- **PO boxes.** A character rents one box at a mail office. Box numbers count up from 1000 on a fresh database. A box belongs to the character, never to the account.
- **Chats.** `/mail` opens on Chats: direct chats between two boxes, group chats and business chats. There is a conversation list with search, filters, unread counts, pin and mute, and chat bubbles with day separators. Older messages load a page at a time. Messages arrive instantly and show delivery marks (Sealed, Delivered, Opened, or "Opened by 2 of 3" in a group), and a "writing…" line shows while someone types. Nobody's character name is ever shown: everyone appears as their PO box number, or as the name the viewer saved for that box in their own address book.
- **Reply threads.** Any message in any chat (direct, group or business) can get its own thread: hover it and click the reply arrow. The thread opens beside the chat, and the message in the main chat shows "3 replies · last 12:40", with a red dot when there are replies you have not seen. A reply cannot get its own thread.
- **Reactions.** Hover a message and click 🙂+ to react with one of `Config.Chat.reactions`. Click a reaction under a message to add yours or take it back. Hovering a reaction shows who reacted. In a business chat, customers see a staff reaction as the business's, never the employee's.
- **Emoji picker.** The 🙂 button next to every chat box, thread box and the letter toolbar opens a picker with a Frontier set first, plus faces, hands, food and symbols. It remembers your recently used emojis on your own machine.
- **Business chats.** A player can message a business address (for example `val556`). Every employee whose rank has the business "mail" permission sees these chats under Business → Customers, replies as the business and can mark a chat as handled. Customers never see which employee wrote.
- **Blocking.** A player can block a box from a chat or the address book. Messages from a blocked box are hidden from that player everywhere.
- **Business blocking.** Staff with the business "mail" permission can block a customer's PO box: open the customer chat, click **Details**, then **Block customer**.
  - A blocked box can't write, react or start a new chat with that business. It gets the tip "This business is not taking your messages."
  - The chat leaves Customers for all staff.
  - **Blocked** at the top of Customers lists the blocked boxes, each with an **Unblock** button.
  - Each business has its own list (up to 500).
- **Anti-spam** on the server: a short gap between messages, no messages under 2 characters, no repeating the same text, and a short mute for bursts (see `Config.Chat`).
- **Letters.** Kept as before, under Post: write to box numbers or business addresses; reply, reply all, forward, file into folders, trash, restore, delete for good and remove from Sent. A letter from a box or a business has a **Chat** button.
- **Anonymous letters.** The reader sees no sender and cannot reply. Staff can get a Discord copy.
- **Business mail.** A business known to `pup_business` can register an address of three letters and three digits (for example `val556`). Only the boss registers or changes the address, and a change is paid from the business ledger.
  - **Players reach a business by chat only.** Typing a business address in a letter offers to open that business's chat instead, and the draft is kept. On a letter from a business, **Reply** becomes **Reply in chat**. The server refuses business addresses on letters too. Set `Config.Letters.businessByChat = false` to allow letters to businesses again.
  - **Letters a business sends** (ranks with the "mail" permission tick "Sign as …") have one letterhead with a monogram, the name and the mail address, and a company rubber stamp in place of the sign-off.
  - Every employee can still read older letters in the business box.
- **Groups.** Up to `Config.Chat.maxGroupMembers` boxes. The owner adds and removes people, renames and disbands; anyone can leave (the oldest member takes over).
- **System letters.** Other resources post official letters through the `SendSystemMail` export.
- **Admin tools.** `vorp_admin` reads, moves and creates boxes and business addresses through exports.
- **Personal look.** Each player picks a theme, accent, fonts, paper, chat bubble paper, what Enter does, size, position and effects; saved on their own machine.
- **HUD envelope.** A small envelope with unread counters shows while the window is closed: red = chats, blue = the business (chats and letters), gold = letters. `fred_hud` can move it.
- **Writing pose and send-off.** The character holds a letter and pen while the window is open, and kneels while a pigeon carries a **letter** away. Chat messages never play the send-off.

## Requirements

- `vorp_core`, `oxmysql`, `pup-ui`
- Optional: `pup_business` (business addresses), `vorp_admin` (admin box tools), `fred_hud` (moving the HUD envelope)
- OneSync is recommended, so the server can check where players stand (see `Config.PassWhenNoPosition`).

## Installation

1. Put `pup_postoffice` in your resources folder.
2. Run `sql/install.sql` on your database. It is safe to run more than once. On start the resource also adds any missing newer tables and columns to an older database. No inventory items are needed.
3. Optional: set the webhook in `server/config.lua` (see below).
4. Add `ensure pup_postoffice` to `server.cfg` after `vorp_core`, `oxmysql` and `pup-ui` (and `pup_business` if you use it).

### Webhook

Set it in `server/config.lua`, which is loaded only on the server and never sent to players:

```lua
PO.secrets = {
    Webhooks = {
        anonymousLetters = '', -- Discord webhook that receives a copy of every anonymous letter
    },
}
```

`anonymousLetters` gets the sender, recipients, subject and body of every anonymous letter. Empty = no log.

## Commands

| Command | Who | What |
|---|---|---|
| `/mail` | everyone with a PO box | open the mail window (name set by `Config.Command`; no permission needed) |
| `G` at a mail office | everyone | open the office menu: rent a box, or open the mail window |

## Configuration

Everything lives in `shared/config.lua`, which is read by the server, the client and (through the client) the mail page. Game tip wording is in `shared/locale.lua` (`%s` / `%d` are filled in by the code; the admin reasons there are shown to the admin as they are).

### General
- `Config.DevResign`: when `true`, every online player's mailbox is pushed again a moment after this resource restarts. Useful while developing.
- `Config.Command`: chat command that opens the mail window.
- `Config.InteractKey`: game control used at a mail office (default G). Change the hash only.
- `Config.LocationOnly`: when `true`, `/mail` only tells the player to go to an office and the window opens from the office menu. Letters can then only be sent while standing at an office.

### Config.Branding (look of the mail window)
A player can switch a decoration off for themselves, but never back on when it is off here.
- `title`, `motto`: text in the brand block.
- `logo`: image shown in the brand block, the wax seal and the watermark. Empty = a drawn seal and no watermark. Put your crest in `html/img/`, list it under `files` in `fxmanifest.lua` and set e.g. `'img/crest.png'`, or point at an image another resource serves with a `nui://` path.
- `seal`, `ornaments`, `watermark`: decorations on or off.
- `paper`: the default paper: `parchment`, `stationery`, `ruled`, `plain`, `crumpled`, `telegram` or `ledger`.
- `telegramHeader`: header printed on the Telegram paper.

### Distances (metres)
- `Config.ServerReach`: server check when registering a box, and when sending in location-only mode.
- `Config.ClientReach`: how close the player must stand for the office prompt.
- `Config.MenuCloseDistance`: the office menu closes past this horizontal distance.
- `Config.PassWhenNoPosition`: when the server cannot read a player's position (no OneSync, or the ped reports the map origin), `true` lets the office check pass; `false` refuses it.

### Config.MailboxProps
- `enabled`: when `true`, any object of `model` counts as a mail office. The server cannot see props, so with this on the server distance check always passes.
- `model`: the prop model.

### Prices
- `Config.BoxPrice`: cash for a personal PO box.
- `Config.BusinessChangeCost`: taken from the business ledger when a boss changes the business address.

### Config.Letters
- `showSenderName`: recipients see the character (or business) name instead of only the box number.
- `maxRecipients`: most addresses on one letter.
- `maxSubject`: bytes; server hard cap (the page allows 120 characters).
- `maxBody`: bytes.
- `cooldown`: seconds between letters, counted from the last letter actually stored.
- `businessByChat`: `true` (default) = nobody can write a letter to a business; customers use the business chat. Businesses can still send letters to PO boxes.
- `refuseIfAnyInvalid`: `false` = a letter with some unknown addresses still goes to the valid ones, with a tip listing the rest. `true` = the whole letter is refused while any address is unknown.

### Config.Chat
- `maxMessage`: bytes per message (server cap).
- `pageSize`: messages fetched at a time when a chat opens or scrolls back.
- `maxGroupMembers`, `maxOwnedGroups`: group size, and how many groups one box may own.
- `cooldownMs`: shortest gap between two messages from one player.
- `listLimit`: how many of the most recent chats the window lists.
- Anti-spam: `minLength` (characters), `repeatSeconds` (the same text twice in a row inside this window is refused), and `burstCount` / `burstSeconds` / `muteSeconds` (more than `burstCount` messages inside `burstSeconds` mutes that player's chats for `muteSeconds`). Thread replies count the same as chat messages.
- `reactions`: the emojis players can react with (up to 12). The server refuses any other. Emoji 12 or older is safest, because newer emojis show as boxes on Windows 10.

### Config.Mailbox
- `maxContacts`: address book size.
- `maxFolders`: custom folders per box.
- `contactName`: bytes; server hard cap (the page allows 48 characters).
- `contactNotes`: bytes; server hard cap (the page allows 500 characters).

### Config.PageLimits
Limits (in characters) the page applies while typing: `subject`, `contactName`, `contactBox`, `contactNotes`, `folderName`, `groupTitle`, `groupMessage`. They are stricter than the server caps above.

### Config.Blip
Map blip for offices: `style` and `sprite` hashes, `scale`, and the `name` shown.

### Config.Offices
The mail offices. Each entry is `{ name, coords, blip }`; `blip = false` hides it from the map. Adding an office:

```lua
{ name = 'My Town', coords = vector3(0.0, 0.0, 0.0), blip = true }, -- use the counter's coords
```

### Config.Pose (writing pose while the window is open)
- `letterProp`, `penProp`: prop models.
- `letterBone`, `penBone`: the hand bones they attach to.
- `letterOffset`, `penOffset`: `{ x, y, z, rotX, rotY, rotZ }` for each prop.
- `animDict`, `animName`, `animFlag`: the writing animation.

Model and animation names may need tuning in game.

### Config.SendOff (the kneel-and-pigeon send-off)
- `scenario`: the kneel scenario.
- `pigeonModel`: the bird.
- `kneelMs`: how long the player kneels (ms).
- `pigeonAtMs`: when the pigeon appears (ms after the kneel starts).
- `pigeonLifeMs`: how long the pigeon exists before it is removed (ms).

## For developers

### Server exports

| Export | Arguments | Returns |
|---|---|---|
| `SendSystemMail` | charid, subject, body, fromName | `true`, or `false` when the character has no box |
| `AdminGetAddress` | player server id | box number or nil |
| `AdminGetAddressByChar` | charid | box number or nil |
| `AdminSetAddress` | player server id, new number | `true` or `false, reason` |
| `AdminSetAddressByChar` | charid, new number | `true` or `false, reason` |
| `AdminCreateAddress` | player server id, number or nil | `true` or `false, reason` |
| `AdminCreateAddressByChar` | charid, number or nil | `true` or `false, reason` |
| `AdminGetBusinessHandle` | job | handle or nil |
| `AdminSetBusinessHandle` | job, handle text | `true, handle` or `false, reason` |

The admin business-handle exports skip the boss check and the fee.

```lua
exports.pup_postoffice:SendSystemMail(charid, 'Tax notice', 'Your property tax is due.', 'County Clerk')
```

### Events

- `pup_postoffice:rec_addedMailid` (server to client, args `letter, isIncoming`): pushes one letter into an online player's mailbox. Resources that insert their own `mails` row fire this at the owner.
- `pup_postoffice:chat` (client to server, args `op, data`; server to client, arg `data` with a `type`): every chat action and update. Only this resource uses it.
- `mail:business:request`, `mail:business:register` (handle text), `mail:business:setHandle` (handle text): client to server, used by the `pup_business` dashboard. The server answers with `mail:business:state` (the business info, or nil).
- `mail:hudIconPos` (local client event, args `dx, dy, preview`): sent by `fred_hud` to move the HUD envelope. This resource fires `fred_hud:reapplyLayout` after it starts. The envelope is 40x34 px at bottom 10px, left 60px.

### Tables

`mail`, `mails`, `mail_addressbook`, `mail_editableFolders`, `mail_business`, `mail_groups`, `mail_group_members`, `mail_group_messages`, `mail_group_reactions`, `mail_blocks`, `mail_business_blocks`. See `sql/install.sql`. `mail_business_blocks` holds the boxes each business blocked (`job`, `address`, plus `blockedBy`, the employee's box, kept for the record). Every chat lives in the `mail_group*` tables: `mail_groups.kind` is `group`, `direct` or `business` (`ref` = the business job), `mail_group_messages.asJob` marks a message an employee wrote for the business, and `mail_group_messages.parentId` marks a thread reply (it points at a top-level message of the same chat). `mail_group_reactions.who` is `p<box>`, or `b:<job>` for a reaction made for a business. That table uses `utf8mb4_bin`, so two different emojis never count as the same one. On start the resource adds any missing chat columns and the `mail_blocks` and `mail_group_reactions` tables to an older database; existing groups carry on as `group` chats, and existing messages all stay in the main chat. If the reply or reaction columns cannot be added, chats still work, just without threads and reactions. The `mail` and `mails` tables are unchanged, so resources that send letters (housing, camps, shops, ranches, the fence) keep working as before. A business address change reads and updates `society_ledger` and writes `society_activity`, both owned by `pup_business`.

### Fonts and art

The page loads open fonts from Google Fonts (Alegreya, EB Garamond, Libre Baskerville, Cormorant Garamond, Crimson Text, Old Standard TT, Lora, Spectral, Bitter, IM Fell English, Courier Prime, Special Elite, Homemade Apple, Playfair Display), with system fallbacks. No font file is bundled. All art (seal, stamp, envelope, papers, icons) is drawn with inline SVG and CSS.

## License

See LICENSE.
