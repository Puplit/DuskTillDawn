fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'pup-bank: branch accounts, statements and a teller job'

shared_scripts {
    'config/main.lua',     -- creates Config, so first
    'config/banks.lua',
    'config/locale.lua',
}

-- store.lua publishes Store; main.lua and teller.lua both use it
server_scripts {
    'server/config.lua',   -- webhook, server only
    'server/store.lua',
    'server/main.lua',
    'server/teller.lua',
}

-- teller.lua fills in the Teller tab that main.lua draws
client_scripts {
    'client/main.lua',
    'client/teller.lua',
}

dependency 'pup-ui'
