-- connection of server/client

local connection = {}

connectedClients = {}

local maxPlayers = 0
local numOfPlayers = 0

function connection.initServer(host, port, maxConnections)
	local tcpServer = socket.bind(host, port)
	maxPlayers = maxConnections
	if tcpServer == nil then
		print(err)
	else
		local addr, p = tcpServer:getsockname()
		print("Server initialized @: " .. addr .. ":" .. p)
	end
	
	if tcpServer then
		tcpServer:settimeout(0)
	end
	
	return tcpServer
end

-- Send playernames, stats etc:
local function synchronizeClients( newClient )
	numOfPlayers = 0
	for k, cl in pairs( connectedClients ) do
		cl.client:send("NEWPLAYER:" .. newClient.clientNumber .. newClient.playerName .. "\n")
		if	cl ~= newClient then
			newClient.client:send("NEWPLAYER:" .. cl.clientNumber .. cl.playerName .. "\n")
		end
		numOfPlayers = numOfPlayers + 1
	end
	printTable(connectedClients)
end

function handleNewClient( newClient )
	print("new client connected")
	local clientNumber = 0
	for i=1, maxPlayers, 1 do
		if connectedClients[i] == nil then
			connectedClients[i] = { client = newClient, playerName = "" }
			connectedClients[i].clientNumber = i
			clientNumber = i
			break
		end
	end
	
	if game.active() then
		newClient:send("ERROR:NOTINLOBBY:\n")
		connectedClients[clientNumber] = nil
		newClient:close()
		newClient = nil
	else
		if clientNumber <= maxPlayers and clientNumber ~= 0 then
			newClient:send("CLIENTNUMBER:" .. clientNumber .. "\n")
			if startingWord then 
				newClient:send("CURWORD:" .. startingWord .. "\n")
			end
		else
			newClient:send("ERROR:SERVERFULL\n")
			connectedClients[clientNumber] = nil
			newClient:close()
			newClient = nil
		end
	end
	if newClient then
		statusMsg.new( "New player!" )
	end
end

function connection.serverBroadcast( msg )
	numOfPlayers = 0
	for k, cl in pairs( connectedClients ) do
		cl.client:send(msg .. "\n")
		numOfPlayers = numOfPlayers + 1
	end
end

function connection.getPlayers()
	return numOfPlayers
end

local start, ending

function connection.runServer( tcpServer )		--handle all messages that come from the clients
	local newClient, err = tcpServer:accept()
	
	if newClient ~= nil then
		print("someone's trying to join")
		newClient:settimeout(0)
		handleNewClient( newClient )
	end
	
	for k, cl in pairs(connectedClients) do
		local msg, err = cl.client:receive()
		if msg ~= nil then
			print("received: " .. msg)
			if msg:find( "NAME:" ) == 1 then
				cl.playerName = msg:sub( 6, #msg )
				local nameTaken = false
				for k2, cl2 in pairs( connectedClients) do
					if cl2 ~= cl and cl2.playerName == cl.playerName then
						nameTaken = true
					end
				end
				
				if nameTaken then
					cl.client:send( "ERROR:NAMETAKEN\n" )
					connectedClients[cl.clientNumber] = nil
					cl.client:close()
				else
					synchronizeClients( cl )
				end
				
				print("end received: " .. msg)
			else	
				start, ending = msg:find( "ACTION:do" )
				if start == 1 then
					game.receiveAction( cl.playerName  .. msg:sub(ending+1, #msg), "do", cl.clientNumber)
					connection.serverBroadcast( "ACTION:do" .. cl.playerName .. msg:sub(ending+1, #msg) )
				end
				start, ending = msg:find( "ACTION:say" )
				if start == 1 then
					game.receiveAction( cl.playerName .. ": \"" .. msg:sub(ending+1, #msg) .. "\"", "say", cl.clientNumber )
					connection.serverBroadcast( "ACTION:say" .. cl.playerName .. ": \"" .. msg:sub(ending+1, #msg) .. "\"")
				end
				start, ending = msg:find( "ACTION:use" )
				if start == 1 then
					game.receiveAction( cl.playerName .. ": " .. msg:sub(ending+1, #msg), "use", cl.clientNumber )
					connection.serverBroadcast( "ACTION:use" .. cl.playerName .. ": " .. msg:sub(ending+1, #msg) )
				end
				start, ending = msg:find( "ACTION:skip" )
				if start == 1 then
					game.receiveAction( "", "skip", cl.clientNumber )
					--connection.serverBroadcast( "ACTION:skip" .. cl.playerName .. ": " .. msg:sub(ending+1, #msg) )
				end
				
				start, ending = msg:find( "CHAT:" )
				if start == 1 then
					chat.receive( cl.playerName.. ": " .. msg:sub(ending+1, #msg) )
					connection.serverBroadcast("CHAT:" .. cl.playerName.. ": " .. msg:sub(ending+1, #msg))
				end
			end
		else
			if err ~= "timeout" then
				print("error: " .. err)
				if err == "closed" then
					local clientName = cl.playerName
					connectedClients[k] = nil			-- if connection was closed, remove from table
					connection.serverBroadcast("CLIENTLEFT:".. clientName)
					if game.active() then
						game.receiveServerMessage( clientName .. " has left the game." )
					end
					return
				end
			end
		end
	end
end

function connection.runClient( cl )				--handle all messages that come from the server
	msg = cl:receive()

	if msg then
		print("received: " .. msg)
		
		if msg:find("ERROR:") == 1 then
			if msg:find( "ERROR:SERVERFULL" ) == 1 then
				client = nil
				print( "ERROR: Server is full!" )
				statusMsg.new( "Server is full!" )
				menu.initMainMenu()
				return
			elseif msg:find( "ERROR:NAMETAKEN" ) == 1 then
				client = nil
				print( "Name alread exists!" )
				statusMsg.new( "Name alread exists!" )
				menu.initMainMenu()
				return
			elseif msg:find( "ERROR:NOTINLOBBY" ) == 1 then
				client = nil
				print( "Server's game has already started!" )
				statusMsg.new( "Can't join: Game has already started!" )
				menu.initMainMenu()
				return
			end
		else
		
			start, ending = msg:find( "CLIENTNUMBER:" )
			if start == 1 then
				connection.setClientNumber( msg:sub(ending+1, #msg) )
				return
			end
			
			start, ending = msg:find( "NEWPLAYER:" )
			if start == 1 then
				table.insert( connectedClients, {playerName=msg:sub(ending+2, #msg), clientNumber=tonumber( msg:sub(ending+1, ending+1) ) } )
				return
			end
			
			start, ending = msg:find( "CURWORD:" )
			if start == 1 then
				game.clientReceiveNewWord( msg:sub(ending+1, #msg) )
				return
			end
			
			start, ending = msg:find( "GAMESTART:" )
			if start == 1 then
				lobby.deactivate()
				game.init()
				return
			end
			
			start, ending = msg:find( "NEWPLAYERTURNS:" )
			if start == 1 then
				displayNextPlayerTurns(msg:sub(ending+1, #msg))
				return
			end
			
			start, ending = msg:find( "STORY:" )
			if start == 1 then
				game.receiveStory( msg:sub(ending+1, #msg) )
				return
			end
			
			start, ending = msg:find( "YOURTURN:" )
			if start == 1 then
				game.startMyTurn()
				return
			end
			
			start, ending = msg:find( "ACTION:do" )
			if start == 1 then
				game.receiveAction( msg:sub(ending+1, #msg), "do" )
				return
			end
			start, ending = msg:find( "ACTION:say" )
			if start == 1 then
				game.receiveAction( msg:sub(ending+1, #msg), "say" )
				return
			end
			start, ending = msg:find( "ACTION:use" )
			if start == 1 then
				game.receiveAction( msg:sub(ending+1, #msg), "use" )
				return
			end
			
			start, ending = msg:find( "CHAT:" )
			if start == 1 then
				chat.receive( msg:sub(ending+1, #msg) )
				return
			end
			
			start, ending = msg:find( "SERVERSHUTDOWN:" )
			if start == 1 then
				if game.active() then
					game.receiveServerMessage("Server closed game.")
				else
					cl:close()
					lobby.deactivate()
					menu.initMainMenu()
					statusMsg.new("Server closed game!")
				end
				return
			end
			
			start, ending = msg:find( "CLIENTLEFT:" )
			if start == 1 then
				game.receiveServerMessage( msg:sub(ending+1, #msg) .. " has left the game." )
				for k, v in pairs(connectedClients) do
					if v.playerName == msg:sub(ending+1, #msg) then
						connectedClients[k] = nil
						break
					end
				end
				return
			end
			
		end
	end
end

local clientNumber = nil			--client's clientnumber

function connection.initClient( address, port )

	if #address == 0 then address = "localhost" end
	local tcpClient, err = socket.connect(address, port)

	if tcpClient == nil then
		print(err)
		statusMsg.new( err .. "!")
		menu.initMainMenu()
	else
		tcpClient:settimeout(0)
	end
		
	return tcpClient
end

function connection.getClientNumber()
	return clientNumber
end

function connection.setClientNumber(num)
	if type(num) == "string" then
		num = tonumber(num)
	end
	clientNumber = num
end

return connection
