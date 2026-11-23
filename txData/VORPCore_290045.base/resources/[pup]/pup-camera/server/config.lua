-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.
-- Loads after config/access.lua, which creates Config.Access.

Config = Config or {}
Config.Access = Config.Access or {}

-- staff Steam ids that may use the camera, e.g. { "steam:1100001xxxxxxxx" }
Config.Access.allowed = {}
-- staff Steam ids with no range limit
Config.Access.unlimited = {}
