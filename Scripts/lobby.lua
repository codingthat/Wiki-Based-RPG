local lobby = {}

local active
local choosingFirstWord = false

local avatarPicX = 70
local avatarPicY = 410

function attemptGameStart()

	for k, cl in pairs( connectedClients ) do
		if cl.ready ~= true then
			rand = math.random(7)
			if rand == 1 then statusMsg.new( "Some heroes have not packed their lunchbags yet." )
			elseif rand == 2 then statusMsg.new( "Still waiting for the heroes to dress..." )
			elseif rand == 3 then statusMsg.new( "SOMEONE is still not ready!" )
			elseif rand == 4 then statusMsg.new( "Waiting for the heroes to draw their little avatar-thingies..." )
			elseif rand == 5 then statusMsg.new( "*Sigh*... nope. Someone's not ready yet." )
			elseif rand == 6 then statusMsg.new( "Heroes are taking their time..." )
			elseif rand == 7 then statusMsg.new( "A hero is still busy kissing his mum good-bye..." )
			else statusMsg.new( "If only they were all ready..." )
			end
			
			return
		end
	end

	local numClients = 0
	for k, cl in pairs( connectedClients ) do
		numClients = numClients + 1
		
		cl.client:send( "GAMESTART:\n" )
	end
	if numClients == 0 and not DEBUG then
		statusMsg.new( "Need at least one player!" )
	else
		buttons.clear()		-- remove game start button
		active = false
		game.init()
	end
end

local found, multiple, urlTable

function lobby.inputFirstWord()
	wikiClient.inputWikiWord( love.graphics.getWidth()/2, 400, love.graphics.getWidth()/2-20, love.graphics.getHeight()/2-110, lobby.firstWordSet, "What will the story be about?" )
end

function lobby.inputDescriptionWord()
	wikiClient.inputWikiWord( love.graphics.getWidth()/2, 400, love.graphics.getWidth()/2-20, love.graphics.getHeight()/2-110, lobby.descriptionWordSet, "Enter a word to describe your character:" )
	setAvatarButtons()
end

local chosenURLs = nil
local descriptionHeaderBox = nil
local descriptionInputBox = nil
descriptionWord = nil


function sendReady()
	if clientReady then
		clientReady = false
		client:send("READY:false\n")
	else
		clientReady = true
		client:send("READY:true\n")
	end
	
	buttons.clear()
	setAvatarButtons()
	if clientReady then 
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15, buttonWidth, buttonHeight, "Ready [x]", drawButton, highlightButton , sendReady )
		connection.sendAvatar()
		connection.sendStatistics()		
	else 
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15, buttonWidth, buttonHeight, "Ready [ ]", drawButton, highlightButton , sendReady )
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight-10, buttonWidth, buttonHeight, "Change description", drawButton, highlightButton , lobby.inputDescriptionWord )
		setAbilityStatButtons()
	end
end

function lobby.descriptionAdded()
	if descriptionInputBox then
		if textBox.getContent( descriptionInputBox ):lower():find( descriptionWord:lower(), 1, true ) then
			client:send( "CHARDESCRIPTION:" .. textBox.getContent( descriptionInputBox ) .. "\n")
			descriptionHeaderBox = nil
			descriptionInputBox = nil
			setClientButtons()
		else
			if descriptionWord then statusMsg.new( "You must use " .. descriptionWord .. " in your description!" ) end
			textBox.setAccess( descriptionInputBox, true, true )
			textBox.moveCursorToEnd( descriptionInputBox )
		end
	end
end

function lobby.chooseDescriptionWord( index )
	buttons.clear()
	setAvatarButtons()
	if chosenURLs then
		descriptionWord = chosenURLs[index].title
		if #descriptionWord > 0 then
			if descriptionHeaderBox == nil then
				descriptionHeaderBox = textBox.new( avatarPicX+AVATAR_PIXELS_X*AVATAR_PIXELS_WIDTH+10, 400 + 3, 2, fontInputHeader, love.graphics.getWidth() )
			end
			textBox.setContent( descriptionHeaderBox, "Tell us something about your character. Use " .. descriptionWord .. "." )
			if descriptionInputBox == nil then
				descriptionInputBox = textBox.new( avatarPicX+AVATAR_PIXELS_X*AVATAR_PIXELS_WIDTH+15, 400 + 23, 6, fontInput, love.graphics.getWidth()/2-20 )
				textBox.setColour( descriptionInputBox, colTextInput.r, colTextInput.g, colTextInput.b )
			end
			local rand = math.random(4)
			if rand == 1 then textBox.setContent( descriptionInputBox, plName .. " likes " )
			elseif rand == 2 then textBox.setContent( descriptionInputBox, plName .. " has " )
			else
				textBox.setContent( descriptionInputBox, plName .. " is " )
			end
			textBox.setAccess( descriptionInputBox, true, true )
			table.insert( nextFrameEvent, {func = textBox.moveCursorToEnd, arg = descriptionInputBox, frames = 2 } )
			textBox.setReturnEvent( descriptionInputBox, lobby.descriptionAdded )
		else
			buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight-10, buttonWidth, buttonHeight, "Describe character", drawButton, highlightButton , lobby.inputDescriptionWord )
		end
	end
end

function lobby.descriptionWordSet()		--ask player to write something about himself.
	chosenURLs = wikiClient.nextWord()
	if chosenURLs then
	
		local displayAreaX = love.graphics.getWidth()/2
		local displayAreaY = 400
		local displayAreaWidth = love.graphics.getWidth()/2
		
		setAvatarButtons()
		local i = 0
		local j
		local titleStr = 0
		
		for k, v in pairs( chosenURLs ) do							-- show all possible Words that server can choose as buttons.
			if DEBUG then print(k .. ": " .. v.title .. " @ " .. v.url) end
			if i < 5 then
				titleStr = ""
				for char in v.title:gfind("([%z\1-\127\194-\244][\128-\191]*)") do		-- make sure button title isn't larger than button
					titleStr = titleStr .. char
					if buttonFont:getWidth( titleStr ) >= displayAreaWidth-30 then
						 break
					end
				end
				if titleStr ~= v.title then
					titleStr = titleStr .. "..."
				end
				buttons.add( displayAreaX, displayAreaY+35+i*(buttonHeight-5), displayAreaWidth, buttonHeight/2+10, titleStr, drawButton, highlightButton, lobby.chooseDescriptionWord, k )
			end
			i = i+1
		end
	else
		print("ERROR: Uhm... no urls found...?")
	end
end

function lobby.firstWordSet( word )
	startingWord = word
	local start, ending = startingWord:find( "%(.*%)" )
	if start then
	--print("found: " .. curGameWord:sub(start, ending))
		startingWord = startingWord:sub( 1, start-1 ) .. startingWord:sub( ending+1, #curGameWord )
		while startingWord:sub( #startingWord, #startingWord )  == " " do		--don't allow trailing spaces
			startingWord = startingWord:sub( 1, #startingWord-1 )
		end
		if #startingWord == 0 then
			startingWord = word
		end
	end
	
	connection.serverBroadcast("CURWORD:" .. startingWord .. "\n")
	setServerButtons()

	statusMsg.new( "Start word set." )
end

function setAvatarButtons()
	for i=0,AVATAR_PIXELS_X-1,1 do
		for j=0,AVATAR_PIXELS_Y-1,1 do
			buttons.add( avatarPicX + i*AVATAR_PIXELS_WIDTH, avatarPicY + j*AVATAR_PIXELS_HEIGHT, AVATAR_PIXELS_WIDTH, AVATAR_PIXELS_HEIGHT, i*AVATAR_PIXELS_X+j, drawPixel, highlightPixel , switchPixel, i*AVATAR_PIXELS_X+j )
		end
	end
end


function setAbilityStatButtons()
	local maxWidth = 0
	for k, v in pairs(abilities) do
		if maxWidth < buttonFont:getWidth(v) then maxWidth = buttonFont:getWidth(v) end
	end
	for i=1,MAX_ABILITIES,1 do
		if abilities[i] ~= nil then
			for j=1,5,1 do
				buttons.add( love.graphics.getWidth()/3 + maxWidth + AVATAR_PIXELS_WIDTH*j,  413 + (i-1)*buttonFont:getHeight() , AVATAR_PIXELS_WIDTH, AVATAR_PIXELS_HEIGHT, i*5+j, statPixel, stathighlightPixel , changeStat, i*5+j )
			end
		end
	end
	if server then connection.sendAbilities() end
end

local abilityHeaderBox = nil
local abilityInputBox = nil


function lobby.addAbility( str )
	for i=1,MAX_ABILITIES,1 do
		if abilities[i] == nil then
			abilities[i] = str
			statistics[i*5+1] = 1
			setStatistics[i] = 1
			break
		end
	end
	if server then connection.sendAbilities()
	else setClientButtons() end
end

function removeAbility( ID )
	abilities[ID] = nil
	connection.sendAbilities()
	
	buttons.clear()
	setServerButtons()
end

function addAbilityRemoveButtons()
	local i = 0
	for k, v in pairs(abilities) do
		buttons.add( love.graphics.getWidth()/3-25, 407 + i*buttonFont:getHeight(), 20, 27, "x", drawButton, highlightButton , removeAbility, k )
		i = i+1
	end
end

function setServerButtons()
	addAbilityRemoveButtons()
	
	if startingWord == nil then
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight-10, buttonWidth, buttonHeight, "Choose Path", drawButton, highlightButton, lobby.inputFirstWord )
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight*2-10, buttonWidth, buttonHeight, "Add Ability", drawButton, highlightButton, lobby.inputAbility )
	else
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight*2-10, buttonWidth, buttonHeight, "Add Ability", drawButton, highlightButton, lobby.inputAbility )
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight-10, buttonWidth, buttonHeight, "Change first Word", drawButton, highlightButton, lobby.inputFirstWord )
		buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15, buttonWidth, buttonHeight, "Begin journey", drawButton, highlightButton, attemptGameStart )
	end
end

function setClientButtons()
	buttons.clear()
	setAbilityStatButtons()
	
	
	buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15-buttonHeight-10, buttonWidth, buttonHeight, "Describe character", drawButton, highlightButton , lobby.inputDescriptionWord )
		
	setAvatarButtons()
	if DEBUG then buttons.add( love.graphics.getWidth()-buttonWidth-10, love.graphics.getHeight()-buttonHeight-15, buttonWidth, buttonHeight, "Ready [ ]", drawButton, highlightButton , sendReady )
	end
end

function lobby.abilityEntered()
	local str = textBox.getContent( abilityInputBox )
	
	abilityHeaderBox = nil
	abilityInputBox = nil
	
	if str:find(",") then
		statusMsg.new( "No Commas allowed!" )
		setServerButtons()
		return
	end
	
	if #str > 0 then
		lobby.addAbility( str )
	end
	
	setServerButtons()
end

function lobby.inputAbility()
	buttons.clear()
	local x, y, w, h = love.graphics.getWidth()/2, 400, love.graphics.getWidth()/2-20, love.graphics.getHeight()/2-110
	
	if abilityHeaderBox == nil then
		abilityHeaderBox = textBox.new( x+10, y + 3, 2, fontInputHeader, w )
	end
	textBox.setContent( abilityHeaderBox, "Enter a new Ability:" )
	if abilityInputBox == nil then
		abilityInputBox = textBox.new( x+15, y + 23, 1, fontInput, 200 )
		textBox.setColour( abilityInputBox, colTextInput.r, colTextInput.g, colTextInput.b )
	end
	
	textBox.setAccess( abilityInputBox, true, true )
	textBox.setReturnEvent( abilityInputBox, lobby.abilityEntered )
end

function lobby.init()
	active = true
	
	if server then
		setServerButtons()
	else
		setClientButtons()
	end

	-- load the help file for the lobby:
	local helpFile = love.filesystem.newFile("Help/lobby.txt")
	helpFile:open('r')
	local data = helpFile:read(all)
	if data then helpString = data
	else helpString = "Help file not found." end

end

function lobby.deactivate()
	active = false
end

function lobby.active()
	return active
end

local curY = 0
local i

function lobby.showPlayers()

	-- print headers:
	love.graphics.setColor( colBorder.r, colBorder.g, colBorder.g, 255)
	love.graphics.rectangle("fill", 0, 51, love.graphics.getWidth(), 48)
	
	love.graphics.setColor( colLobby.r, colLobby.g, colLobby.b )
	love.graphics.setFont( fontHeader )
	love.graphics.print( "Heroes:", 70, 65 )
	
	love.graphics.setColor( colBorder.r, colBorder.g, colBorder.g, 255)
	love.graphics.rectangle("fill", 0, 360, love.graphics.getWidth(), 38)
	
	love.graphics.setColor( colLobby.r, colLobby.g, colLobby.b )
	love.graphics.setFont( fontInputHeader )
	love.graphics.print( "Options:", 70, 370 )
	
	
	if descriptionHeaderBox then
		textBox.display( descriptionHeaderBox )
	end
	if descriptionInputBox then
		textBox.display( descriptionInputBox )
	end
	if abilityHeaderBox then
		textBox.display( abilityHeaderBox )
	end
	if abilityInputBox then
		textBox.display( abilityInputBox )
	end
	
	if startingWord then
		love.graphics.setFont( buttonFont )
		love.graphics.setColor( 0,0,0 )
		love.graphics.print( "A story of ", (love.graphics.getWidth() - fontHeader:getWidth(startingWord))/2-buttonFont:getWidth("A story of ") , 24 )
		love.graphics.setFont( fontHeader )
		love.graphics.setColor( colWikiWord.r,colWikiWord.g,colWikiWord.b )
		love.graphics.print( startingWord, (love.graphics.getWidth() - fontHeader:getWidth(startingWord))/2, 20 )
	end
	
	if not descriptionHeaderBox then
		love.graphics.setColor( 0,0,0 )
		i = 0
		for k, v in pairs(abilities) do
			love.graphics.setFont( buttonFont )
			love.graphics.print( v, love.graphics.getWidth()/3, 410 + i*buttonFont:getHeight() )
			i = i + 1
		end
	end
	
	for k, cl in pairs( connectedClients ) do
		curY = 120 + 50*(cl.clientNumber-1)
		
		love.graphics.setColor( colLobby.r, colLobby.g, colLobby.g, 255)
		love.graphics.rectangle("fill", 0, curY-9 , love.graphics.getWidth(), 33)
		love.graphics.setColor( 0, 0, 0 , 255)
		love.graphics.setFont( mainFont )
		love.graphics.print(cl.playerName, 200, curY )
		if cl.ready then
			love.graphics.print("[x]", 170, curY )
		else
			love.graphics.print("[ ]", 170, curY )
		end
		love.graphics.setColor( 60, 60, 60 , 255)
		if cl.description then
			love.graphics.print( cl.description, 220+mainFont:getWidth(cl.playerName), curY + 7 )
		end
		if cl.statistics then
			local x = 0
			for i = 1,#abilities,1 do
				if cl.statistics[i] then
					love.graphics.print( abilities[i] .. ":  " .. cl.statistics[i], 220+mainFont:getWidth(cl.playerName) + x, curY - 7 )
					x = x + mainFont:getWidth( abilities[i] .. ":  " .. cl.statistics[i] ) + 10
				end
			end
		end
		if cl.avatar then
			--love.graphics.setColor( colCharB.r,colCharB.g,colCharB.b )
			--love.graphics.rectangle("fill", 30, curY -7, 3*AVATAR_PIXELS_X, 3*AVATAR_PIXELS_Y)
			for i=0,AVATAR_PIXELS_X-1,1 do
				for j=0,AVATAR_PIXELS_Y-1,1 do
					if cl.avatar[i*AVATAR_PIXELS_Y+j] == 1 then
						love.graphics.setColor( colCharM.r,colCharM.g,colCharM.b )
						love.graphics.rectangle("fill", 20+i*3, curY -7 + j*3, 3, 3)
					elseif cl.avatar[i*AVATAR_PIXELS_Y+j] == 2 then
						love.graphics.setColor( colCharD.r,colCharD.g,colCharD.b )
						love.graphics.rectangle("fill", 20+i*3, curY -7 + j*3, 3, 3)
					end
				end			
			end
		end
	end
end


return lobby
