fx_version 'adamant'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

-- objectloader reads objectloader_map when a map starts, so it has to be running first.
-- Each map file needs both lines. example_map.xml shows the format; copy it for your own maps.
dependency 'objectloader'
file 'example_map.xml'
objectloader_map 'example_map.xml'
