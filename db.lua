module(..., package.seeall)
require "sqlite3"
local url = require("socket.url")

local DATABASE_NAME = "data.db"

local hasInitialized = false

function getHasInitialized()
	return hasInitialized
end

local function formatDateString(dateString)
	if (dateString == nil) then return nil; end

	local pattern = "(%d+)%/(%d+)%/(%d+)% (%d+)%:(%d+)%:(%d+)"
	local year, month, day, hour, minute, seconds
	
	year, month, day, hour, minute, seconds = dateString:match(pattern)

	local timeStamp = os.time({year = year, month = month,
    day = day, hour = hour, min = minute, sec = seconds})

	return os.date("%c",timeStamp)
end

local function getProperDateString()
	return os.date("%Y/%m/%d %H:%M:%S")
end

--Handle the applicationExit event to close the db
local function onSystemEvent( event )
    if( event.type == "applicationExit" ) then              
        db:close()
    end
end

local function executeQuery(query)

	print(query)
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open( path )
	
	db:exec( query )
	
	local rowid = db:last_insert_rowid()
	
	db:close()
	return rowid
end

function removeMessage(mid)
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open(path)

	local sql = "delete from messages where mid='"..mid.."'"
	--Log ("removeMessage: "..sql)
	executeQuery(sql)
end

function setMessageRead(mid)
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open(path)

	local sql = "update messages set read = '1' where mid='"..mid.."'"
	--Log ("setMessageRead: "..sql)
	executeQuery(sql)
end

--[[
item: numerical id. Ex: loadIdGuid, 
item2: numerical id. Ex: quoteId for above scenario
type (category): Accessorial (view_accessorials webview), Banking, Feedback,Shipment,Quote
type2 (sub type): Future. Ex: accept would allow the app to go straight to accept quote
text: actual message

NOTE: In the future the text could be created programmatically once the message is received using
the type and type2 for reference.

Returns: Row id (mid) of newly inserted message
]]--
MESSAGE_TYPE_ACCESSORIAL = "accessorial"
MESSAGE_TYPE_BANKING = "banking"
MESSAGE_TYPE_FEEDBACK = "feedback"
MESSAGE_TYPE_SHIPMENT = "shipment"
MESSAGE_TYPE_QUOTE = "quote"

local MESSAGE_TYPES = 
{
	MESSAGE_TYPE_ACCESSORIAL,
	MESSAGE_TYPE_BANKING,
	MESSAGE_TYPE_FEEDBACK,
	MESSAGE_TYPE_SHIPMENT,
	MESSAGE_TYPE_QUOTE
}

function isValidMessageType(type)
	for i = 1, #MESSAGE_TYPES do
		if (MESSAGE_TYPES[i] == type) then
			return true
		end
	end

	return false
end

function insertMessage(sid, item, item2, type, type2, text)
	local query = "insert into messages VALUES (NULL, '"..(sid or '').."','"..item.."','"..(item2 or '').."',"
		query = query.."'"..url.escape(type).."','"..(type2 or '').."','"..url.escape(text or '').."','"..getProperDateString().."',0);"
	Log ("insertMessage: "..query)
	return executeQuery(query)
end

function getMessageCount(sid,type)
	-- TODO: Maybe add a filter later, for now all unread
	-- TODO: maybe use a count(*) query when I have more time
	-- Accessorial (view_accessorials webview), Banking, Feedback,Shipment,Quote

	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open( path )

	sql = "select read from messages where sid = "..sid.." and read == 0"

	local filter = nil

	if (isValidMessageType(type)) then
		filter = type
	end

	if (filter) then
		sql = sql.." and type = '"..filter.."'"
	end

	local count = 0
	
	for row in db:nrows(sql) do
		count = count + 1
	end
	
	return count
end



function getMessage(mid)
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open( path )

	local sql = "select * from messages where mid="..mid

	local result = nil

	for row in db:nrows(sql) do
		result = {}
		result.id = tonumber(row.mid)
		result.sid = tonumber(row.sid)
		result.item = tonumber(row.item)
		result.item2 = tonumber(row.item2)
		result.type = url.unescape(row.type)
		result.type2 = url.unescape(row.type2)
		result.text = url.unescape(row.text)
		result.date = formatDateString(row.date)
		result.read = tonumber(row.read)
	end
	db:close()

	return result
end





function TableExists(tablename)
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open( path )

	
	local sql = "select * from sqlite_master where name='FirstLoad' and type='table'"
	--Log (sql)

	local i = 0

	for row in db:nrows(sql) do
		i = i + 1
	end
	db:close()

	if(i==0) then
		return false
	else
		return true
	end

end


function getMessages(sid, filter)
	-- filter (nil = all, read, types)

	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open( path )

	local results = {}
	
	local strFilter = ""
	
	local strSort = "order by read asc, date desc"
	-- Client doesn't seem to care about read state when ordering, so we don't bother for now
	--local strSort = "order by date desc"

	-- TODO: If needed
	if (sort) then
	end

	if (filter) then
		if (filter == "unread") then
			strFilter = "and read == 0"
		else
			strFilter = "and type == '"..filter.."'"
		end
	end

	local sql = "select * from messages where sid="..sid..strFilter.." "..strSort
	--Log (sql)

	local i = 1

	for row in db:nrows(sql) do
		results[i] = {}
		results[i].id = tonumber(row.mid)
		results[i].sid = tonumber(row.sid)
		results[i].item = tonumber(row.item)
		results[i].item2 = tonumber(row.item2)
		results[i].type = url.unescape(row.type)
		results[i].type2 = url.unescape(row.type2)
		results[i].text = url.unescape(row.text)
		results[i].date = formatDateString(row.date)
		results[i].read = tonumber(row.read)

		i = i + 1
	end
	db:close()
	
	return results
end

--[[
Types: quote, payment, load, message (future)
-- sid is here to filter in case multiple users log in on the same device
-- item is identifier of addressed item in message (load = loadId, shipment #)
]]--
local function createMessageTable()
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open(path)
	
	if (db) then
		--Setup the table if it doesn't exist
		local tablesetup =[[CREATE TABLE IF NOT EXISTS 'messages'(mid INTEGER PRIMARY KEY, sid INTEGER, item INTEGER, item2 INTEGER, type, type2, text, date, read);]]
		db:exec(tablesetup)
		
		db:close()
	end
end

local function createFirstLoadTable()
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
	local db = sqlite3.open(path)
	
	if (db) then
		--Setup the table if it doesn't exist
		local tablesetup =[[CREATE TABLE IF NOT EXISTS 'FirstLoad'(mid INTEGER PRIMARY KEY,type);]]
		db:exec(tablesetup)
		
		db:close()
	end
end

function checkFirstLoad(loadtype)
	-- filter (nil = all, read, types)
	if(TableExists("FirstLoad")) then
		local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory)
		local db = sqlite3.open( path )

		
		local sql = "select * from FirstLoad where type='".. loadtype .."'"
		--Log (sql)

		local i = 0

		for row in db:nrows(sql) do
			i = i + 1
		end
		db:close()

		if(i==0) then
			local query = "insert into FirstLoad(type) VALUES ('".. loadtype .. "')"
			local temp = executeQuery(query)
			return true
		else
			return false
		end
	else
		createFirstLoadTable()
		local query = "insert into FirstLoad(type) VALUES ('".. loadtype .. "')"
		executeQuery(query)
		return true
	end
end


local function create()
	createMessageTable()
	createFirstLoadTable()
end

function init()
	local path = system.pathForFile(DATABASE_NAME, system.DocumentsDirectory )
 	
	local fh, reason = io.open( path, "r" )
 
	if fh == nil then
		create()
	else
		io.close(fh)
	end

	hasInitialized = true
end