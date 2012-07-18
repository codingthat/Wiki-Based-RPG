-- Exports the story to a file.

local export = {}

function export.init()
	love.filesystem.setIdentity("WikiBasedRPG")
end

function export.toTextFile( text )
	if text and text.content then
		local curTime = os.date("*t")
		local fileName
		if curTime then
			fileName = curTime.year .."-".. curTime.month .."-".. curTime.day .. "_" .. curTime.hour .."-".. curTime.min .."-".. curTime.sec .. ".txt"
		else
			math.randomseed(os.time())
			fileName = math.random(99999)
		end
		file = love.filesystem.newFile( fileName )
		if file:open( 'w' ) then
			file:write(startingWord .. "\n\n")
			local stringToWrite = text.content
			file:write(stringToWrite)
			file:close()
			print(fileName .. " written to: " .. love.filesystem.getSaveDirectory() )
		else
			statusMsg.new( "Error opening file!" );
			print( "Error opening " .. filName .. "!" );
		end
	else
		print( "Text empty" )
	end
end

function export.toHtmlFile( text )
	if text and text.content then
		local curTime = os.date("*t")
		local fileName
		if curTime then
			fileName = curTime.year .."-".. curTime.month .."-".. curTime.day .. "_" .. curTime.hour .."-".. curTime.min .."-".. curTime.sec .. ".html"
		else
			math.randomseed(os.time())
			fileName = math.random(99999)
		end

		file = love.filesystem.newFile( fileName )
		if file:open( 'w' ) then
			file:write("<h2>" .. startingWord .. "</h2>")
			file:write("<font color=\"grey\">(A story influenced by randomness and " .. wikiClient.getWikiURL() .. ")</font><br /><br />")
			local stringToWrite = "\n" .. text.content
			
			local s, e
			for k, v in pairs( text.highlightWords ) do
				s, e = stringToWrite:upper():find( v.w:upper(), 1, true)
				while s do
					print(v.w .. " found at:".. s .. "," .. e)
					stringToWrite = stringToWrite:sub(1, s-1) .. "<b>" .. stringToWrite:sub(s,e) .. "</b>" .. stringToWrite:sub(e+1, #stringToWrite)
print(stringToWrite)
					s, e = stringToWrite:upper():find( v.w:upper(), e+7, true)
				end
			end


			stringToWrite = stringToWrite:gsub( "\nStory:([^\n]*)", "\n<br /><i>%1</i>" )
			stringToWrite = stringToWrite:gsub( "\n([^<br />])", "\n<br />&emsp;%1" )
			file:write(stringToWrite)
			file:close()
			print(fileName .. " written to: " .. love.filesystem.getSaveDirectory() )
		else
			statusMsg.new( "Error opening file!" );
			print( "Error opening " .. filName .. "!" );
		end
	else
		print( "Text empty" )
	end
end


return export
