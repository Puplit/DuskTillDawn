fx_version 'adamant'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'qadr-safe'
author 'abdulkadiraktas'
description 'Native RDR2 safe-cracking dial. Driven through pup-minigames safe_crack.'

client_script {
	"shared/*.lua",
	"cl_safe.lua",
}

lua54 'yes'

-- this_is_a_map is what gets stream/qadr_safe_cracking.ytd into the game
this_is_a_map 'yes'
