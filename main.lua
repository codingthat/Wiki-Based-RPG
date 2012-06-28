connection = require("Scripts/connection")

lobby = require("Scripts/lobby")

wikiClient = require("Scripts/wikiClient")

--THIS PORT MUST BE FORWARDED ON YOUR ROUTER FOR INTERNET PLAY!
PORT = 3456

server = nil		-- server object. When not nil, then connection is established.
client = nil		-- client object. When not nil, then connection is established.

textBox = require("Scripts/textBox")
plName = ""
ipStr = ""

require("Scripts/misc")
statusMsg = require("Scripts/statusMsg")
chat = require("Scripts/chat")
menu = require("Scripts/menu")

buttons = require("Scripts/buttons")

game = require("Scripts/game")

mainFont = love.graphics.newFont( "Fonts/AveriaSans-Regular.ttf", 18 )
buttonFont = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf", 18 )
fontHeader = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf", 25 )
fontInputHeader = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf", 20 )
fontInput = love.graphics.newFont( "Fonts/AveriaSans-Regular.ttf", 16 )
fontStatus = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf", 16 )
fontMainHeader = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf",40 )
fontChat = love.graphics.newFont( "Fonts/AveriaSans-Bold.ttf",14 )

colMainBg = { r=230, g=195, b=174 }
colBg = { r=139, g=104, b=71 }
colLobby = { r=241, g=229, b=209 }
colTextInput = { r=100, g=100, b=100 }
colWikiWord = { r=20, g=64, b=160 }
colStory = { r=100, g=80, b=60 }
colAction = { r=0, g=0, b=0 }

nextFrameEvent = {}			-- these functions will be called after the next draw call.
testingConnection = 0

function love.load(arg)
	menu.initMainMenu(buttons)
	love.keyboard.setKeyRepeat( 0.3, 0.03 )
	testingConnection = true
	table.insert( nextFrameEvent, {func = wikiClient.testConnection, frames = 2 } )
	
	--wikiClient.newWord()
	--wikiClient.nextWord()
	--tb = textBox.new( 10, 10, 5, fontInput, 75)
	--textBox.setAccess ( tb , true )
end

local lastSent = os.time()
local msg

function love.update()
	if server then
		connection.runServer( server )
	elseif client then
		connection.runClient( client )
	end
	-- go through list of functions in nextFrameEvent and if they have waited the set amount of frames, call them.
	-- This is needed to make sure client connection does not disable status messages, which would otherwise not show (especially the "attempting to connect" message)
	for k, v in pairs( nextFrameEvent ) do	
		v.frames = v.frames - 1
		if v.frames <= 0 then
			if v.arg then
				v.func(v.arg)
			else
				v.func()
			end
			nextFrameEvent[k] = nil
		end
	end
end

function love.draw()
	if testingConnection then
		love.graphics.setFont( mainFont )
		love.graphics.setColor( 0,0,0,255 )
		love.graphics.print( "Loading\nAttempting to connect to wiki...", 10, 20 )
	else
		if not server and not client then
			menu.showMainMenu()
		elseif lobby.active() then
			lobby.showPlayers()
		elseif game.active() then
			game.show()
		end
		--textBox.display()
		buttons.show()
		statusMsg.display()
	end
end

local inputRead
function love.keypressed(key, unicode)
	inputRead = textBox.input( key, unicode )
	print(key .. " " .. unicode)
	if not inputRead then		--input has not been put into a chat box: use input as command
		if ( string.char(unicode) == "c" or string.char(unicode) == "enter" ) and game.active() then
			chatAreaClicked()
		elseif ( string.char(unicode) == "p" or string.char(unicode) == "w" ) and game.active() then
			gameAreaClicked()
		elseif ( string.char(unicode) == "1" or string.char(unicode) == "2"
			or string.char(unicode) == "3" or string.char(unicode) == "4"
			or string.char(unicode) == "5") and game.active() then
			chooseNextWord( tonumber( string.char(unicode) ) )
		end
	end
end

function love.mousepressed()
	menu.handleClick()
end


function startServer()
	server = connection.initServer( "localhost", PORT, 10 )
	if server then
		lobby.init( buttons )
	end
end

function startClient()
	client = connection.initClient( "localhost", PORT)
	if client then
		client:send("NAME:" .. plName .. "\n")
		statusMsg.new("Connected to server.")
		lobby.init( buttons )
	end
end


function love.quit()
	if server then
		print( "closing server" )
		server:close()
	end
end
