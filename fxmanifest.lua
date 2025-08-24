fx_version 'cerulean'
game 'gta5'

author 'YourName'
description 'Dead Player Robbery System for QBCore'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
}

client_scripts {
    'rob_dead_players_client.lua',
}

server_scripts {
    'rob_dead_players_server.lua',
}

dependencies {
    'qb-core',
    'qb-inventory',
    'qb-target'
}