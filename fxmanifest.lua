fx_version 'cerulean'
game 'gta5'

author 'Azure'
description 'Schedule 1 style grow/mix/bag system (MySQL, DUI/NUI)'
version '1.1.0'

lua54 'yes'

shared_scripts {
  'config.lua',
  'shared/utils.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

dependency 'oxmysql'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js',
  'html/dui.html',
  'html/dui.js'
}
