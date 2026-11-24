fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'alvis_dcchat'
author 'Alvis'
version '1.3.0'
description 'Discord <-> in-game chat bridge with Discord avatars and forced Discord linking'

dependency 'oxmysql'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua',
    'server/gateway.js',
}
