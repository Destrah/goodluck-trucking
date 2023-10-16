fx_version 'cerulean'
games { 'gta5' }

author 'Desmond Luck (Destrah)'
description 'This resource is a trucking job. Do NOT redistribute.'
version '1.0.0'

server_scripts {
	"@async/async.lua",
	"@mysql-async/lib/MySQL.lua",
	'config.lua',
	'server/sv_main.lua'
}

client_scripts {
	'config.lua',
	'client/cl_main.lua'
}

dependencies {
	
}
