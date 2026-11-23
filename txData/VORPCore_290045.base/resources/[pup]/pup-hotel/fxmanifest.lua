fx_version 'cerulean'
games { 'rdr3' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'pup'
description 'Hotel rooms: a clerk assigns players to a room for a number of days'
version '1.0.0'

shared_scripts {
  'config/main.lua',
  'config/hotels.lua',
  'config/locale.lua',
  'shared/rooms.lua',          -- lookups; defines HotelAddRoom
  'config/rooms_custom.lua',   -- written by /hotelroom, loaded last
}

client_scripts {
  'client/pupmenu.lua',
  'client/main.lua',
  'client/doors.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
}

dependency {
  'oxmysql',
  'vorp_core',
  'pup-ui',
}
