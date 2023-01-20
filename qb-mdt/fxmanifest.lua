fx_version 'cerulean'
game 'gta5'

author 'Mart Wasowski'

lua54 'yes'

client_script 'client/client.lua'
server_scripts {'@oxmysql/lib/MySQL.lua', 'server/*.lua'}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/imgs/*.png',
    'html/sounds/*.mp3',
}