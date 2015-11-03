module(..., package.seeall)
local GC = require("AppConstants")
local url = require("socket.url")
local mime = require("mime")
local testbase = require("testbase")

function printTable(table, stringPrefix)
  if not stringPrefix then
    stringPrefix = "### "
  end
  if type(table) == "table" then
    for key, value in pairs(table) do
      if type(value) == "table" then
        print(stringPrefix .. tostring(key))
        print(stringPrefix .. "{")
        printTable(value, stringPrefix .. "   ")
        print(stringPrefix .. "}")
      else
        print(stringPrefix .. tostring(key) .. ": " .. tostring(value))
      end
    end
  end
end

function formatDate(date)
    local pattern = "(%d+)%-(%d+)%-(%d+)"
    local year, month, day = date:match(pattern)
  
    return month.."/"..day.."/"..year
end

function splitTime(timeStr)
    local pattern = "(%d+)%:(%d+)% (%w+)% (%w+)"
    local time = {}

    time.hour, time.minute,time.amPm,time.tz = timeStr:match(pattern)

    return time
end

function luaTimeToTable(timeStr)
    local pattern = "(%d+)%:(%d+)%:(%d+)"
    local time = {}

    time.hour, time.minute, time.second = timeStr:match(pattern)

    return time
end

function formatTimeDigit(number)
    number = tonumber(number)
    if (number < 10) then
        number = "0"..number
    end

    return number
end

function formatTime(time)
    time.hour = formatTimeDigit(time.hour)
    time.minute = formatTimeDigit(time.minute)

    return time.hour..":"..time.minute.." "..time.amPm.." "..time.tz
end

function boolToString(state)
  local str = "No"

  if (state ~= false) then
    str = "Yes"
  end

  return str
end

function stringToBool(str)
  if (string.lower(str or "") == "true") then
    return true
  end

  return false
end

function isValidParameter(parameter,default)
    if (parameter ~= nil and parameter ~= "" and parameter ~= default) then
      return true
    end

    return false
  end

-- TODO: Add more types as they come in
function statusCodeToStatusName(code,isCompany)
  code = tonumber(code)
  if (code == 1) then
    return "active"
  elseif (code == 2) then
    return "inactive"
  elseif (code == 18) then
    return "approved"
  elseif (code == 23) then
    if (isCompany == true) then
      return "pre_registration"
    else
      return "incomplete"
    end
  end
end

function getTrailerTypeLabel(type)
   local label
   type = tonumber(type)

   if (type == 94) then
      label = "over_dimensional"
   elseif (type == 8) then
      label = "truckload"
   elseif (type == 9) then
      label = "less_than_truckload"
   end

   return label
end

function fixSpaces(str)
   if str then
      str = string.gsub(str, ' ', '+')
   end
   return str
end

function unFixSpaces(str)
   if str then
      str = string.gsub(str, '+', ' ')
   end
   return str
end

function spacesToNewLines(str)
	return string.gsub(str, " ", "\n")
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end

    return copy
end

function tableToQueryString(table)
    local queryString

    if type(table) == "table" then
        queryString = ""
        for key, value in pairs(table) do
          if (type(key) ~= "table" or type(key) ~= "function") then
            queryString = queryString.."&"..key.."="..url.escape(value)
          end
        end
        queryString = string.sub(queryString, 2)
    end

    return queryString
end

function urlencode(str)
  if ( str ) then
      str = string.gsub( str, "\n", "\r\n" )
      str = string.gsub( str, "([^%w ])",
         function (c) return string.format( "%%%02X", string.byte(c) ) end )
      str = string.gsub( str, " ", "+" )
   end
   return str
end

function urldecode(str)
    str = string.gsub(str,'+', ' ')
    str = string.gsub(str,'%%(%x%x)', function(h)
    return string.char(tonumber(h, 16))
  end)
  str = string.gsub(str,'\r\n', '\n')
  return str
end

-- Hacked from CSV to allow '::' as delimeters
function parse (s)
    -- Don't add '::' if the string already ends in it
    if (string.sub(s, #s - 1)) ~= "::" then  s = s .. '::' end

    local t = {}        -- table to collect fields
    local fieldstart = 1
    repeat
    -- next field is quoted? (start with `"'?)
    if string.find(s, '^"', fieldstart) then
        local a, c
        local i  = fieldstart
        repeat
        -- find closing quote
        a, i, c = string.find(s, '"("?)', i+1)
        until c ~= '"'    -- quote not followed by quote?
        if not i then error('unmatched "') end
        local f = string.sub(s, fieldstart+2, i-1)
        table.insert(t, (string.gsub(f, '""', '"')))
        fieldstart = string.find(s, '::', i) + 2
    else                -- unquoted; find next comma
        local nexti = string.find(s, '::', fieldstart)
        table.insert(t, string.sub(s, fieldstart, nexti-1))
        fieldstart = nexti + 2
    end
    until fieldstart > string.len(s)
    return t
end

function formatNumber(num,places)
  num = tonumber(num)
  if (not places) then
    places = 2
  end
  --print (num,string.format("%0."..places.."f",tostring(num)))
  return string.format("%0."..places.."f",tostring(num))
end

function addNumberSeparator(amount,sep)
    -- comma is widely used, but allows for periods (europe)
    if (not sep) then
        sep = ","
    end

  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1'..sep..'%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

 -- TODO: Expand later if client wants other currency support
function getCurrencySymbol()
  return "$"
end

function formatMoney(num)
    return addNumberSeparator(formatNumber(num))
end

function formatCurrency(num)
  if (num == nil or num == '' or not isNumber(num)) then
    num = 0.00
  end

  return tonumber(formatNumber(num,2))
end

function isNumber(num)
   return (tonumber(num) ~= nil)
end

function getFeedbackScoreColor(score)
   score = tonumber(score)

   if (score < 80.0 and score >= 65.0) then
      return GC.ORANGE
   elseif (score < 65.0) then
      return GC.RED
   else
      return GC.LIGHT_GREEN
   end
end

function dateToTimeStamp(date)
  local timeStamp

  local pattern = "(%d+)%/(%d+)%/(%d+)"
  local month, day, year = date:match(pattern)
  
  timeStamp = os.time({year = year, month = month, day = day})
  return timeStamp
end

function isDateEarlier(date1, date2)
  local t1, t2 = dateToTimeStamp(date1), dateToTimeStamp(date2)

  return t1 < t2
end

function makeTimeStamp(dateString)
    if (dateString == nil) then return nil; end
    local pattern = "(%w+)% (%d+)%, (%d+)% (%d+)%:(%d+)%:(%d+) (%w+)"
    local monthName, year, month, day, hour, minute, seconds, hourBlock
    local monthLookup = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}
    local convertedTimestamp

    monthName, day, year, hour, minute, seconds, hourBlock = dateString:match(pattern)
    month = monthLookup[monthName]

    if (hourBlock and string.upper(hourBlock) == "PM") then
        hour = hour + 12
    end

    convertedTimestamp = os.time({year = year, month = month,
    day = day, hour = hour, min = minute, sec = seconds})

    return convertedTimestamp
end

function split(self, inSplitPattern, outResults )
   if not outResults then
    outResults = { }
   end

   if (self and self ~= "") then
      local theStart = 1
      local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
      
      while theSplitStart do
         table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
         theStart = theSplitEnd + 1
         theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
      end
      table.insert( outResults, string.sub( self, theStart ) )
   end

   return outResults
end

function calculateType(weight, length, lengthInches, width, height)
  local loadType = GC.LESS_THAN_TRUCKLOAD
  
  weight = tonumber(weight)
  length = tonumber(length)
  width = tonumber(width)
  height = tonumber(height)

  if(length=='' or width=='' or height=='' or weight=='' or
      length==0 or width==0 or height==0 or weight==0 or
      not isNumber(length) or not isNumber(width) or not isNumber(height) or not isNumber(weight)) then
    return 0
  end
  
  if(lengthInches == nil or lengthInches == '') then
    lengthInches = 0
  end

  local totalLengthInInches = ((length * 12) + lengthInches)
  
  --Log("Weight="..weight..", Length="..length..", TotalLengthIn="..totalLengthInInches..", Width="..width)
  
  if(weight >= 20000 or totalLengthInInches > 240) then
    loadType = GC.TRUCKLOAD
  end

  if(weight > 48000 or totalLengthInInches > 636 or width > 102) then
    loadType = GC.OVER_DIMENSIONAL
  end

  return loadType
end

function calculate (weight, length, lengthInches, width, height)
  local cla = 0

  -- Validate raw data
  if(length=='' or width=='' or height=='' or weight=='' or 
      length==0 or width==0 or height==0 or weight==0 or
      not isNumber(length) or not isNumber(width) or 
      not isNumber(height) or not isNumber(weight)) then
      return 0
  end

  local feetInInches = (length * 12)
  if (lengthInches == '') then
    lengthInches = 0
  end

  totalLengthInInches = (feetInInches + lengthInches)
  local total = (totalLengthInInches * width * height)
  local cubicFeet = formatCurrency(total/1728)
  local density = formatCurrency(weight / cubicFeet)
  --Log ("density: "..density)

  if (density >= 50) then
    cla = 50
  elseif (density < 50 and density >= 35) then
    cla = 55
  elseif (density < 35 and density >= 30) then
    cla = 60    
  elseif (density < 30 and density >= 22.5) then
    cla = 65
  elseif (density < 22.5 and density >= 15) then
    cla = 70
  elseif (density < 15 and density >= 13.5) then
    cla = 77.5
  elseif (density < 13.5 and density >= 12) then
    cla = 85
  elseif (density < 12 and density >= 10.5) then
      cla = 92.5
  elseif (density < 10.5 and density >= 9) then
      cla = 100
  elseif (density < 9 and density >= 8) then
      cla = 110
  elseif (density < 8 and density >= 7) then
      cla = 125
  elseif (density < 7 and density >= 6) then
      cla = 150
  elseif (density < 6 and density >= 5) then
      cla = 175
  elseif (density < 5 and density >= 4) then
      cla = 200
  elseif (density < 4 and density >= 3) then 
      cla = 250
  elseif (density < 3 and density >= 2) then
      cla = 300
  elseif (density < 2 and density >= 1) then
      cla = 400
  elseif (density < 1) then
      cla = 500
  end

  return cla
end

function encode(data)
	local len = data:len()
	local t = {}
	for i=1,len,384 do
		local n = math.min(384, len+1-i)
		if n > 0 then
			local s = data:sub(i, i+n-1)
			local enc, _ = mime.b64(s)
			t[#t+1] = enc
		end
	end

	return table.concat(t)
end

function readImage(filename, baseDirectory)
  local baseDir = baseDirectory or system.DocumentsDirectory
  local path = system.pathForFile( filename, baseDir )
  local fileHandle = nil
  local image = nil

  Log("readImage (path): "..path)
  
  fileHandle = io.open(path, "rb")

  if fileHandle then
    image = mime.b64(fileHandle:read("*a"))
    --image = encode(fileHandle:read("*a"))
    --image = mime.b64( fileHandle:read( "*a" ))
    --image = testbase.testBase64a
	--print(" UTILS ***** image = "..tostring(image))
    io.close(fileHandle)
  end
  
  return image
end

function getDeviceMetrics( )
 
    -- See: http://en.wikipedia.org/wiki/List_of_displays_by_pixel_density
 
    local corona_width  = math.ceil(-display.screenOriginX * 2 + display.contentWidth)
    local corona_height = math.ceil(-display.screenOriginY * 2 + display.contentHeight)
    --print("Corona unit width: " .. corona_width .. ", height: " .. corona_height)
        
    -- I was rounding these, on the theory that they would always round to the correct integer pixel
    -- size, but I noticed that in practice it rounded to an incorrect size sometimes, so I think it's
    -- better to use the computed fractional values instead of possibly introducing more error.
    --
    local pixel_width  = math.ceil(corona_width / display.contentScaleX)
    local pixel_height = math.ceil(corona_height / display.contentScaleY)
    --print("Pixel width: " .. pixel_width .. ", height: " .. pixel_height)
        
    local model = system.getInfo("model")
    local default_device =
        { model = model,          inchesDiagonal =  4.0, } -- Default (assumes average sized phone)
    local devices = {   
        { model = "iPhone",       inchesDiagonal =  3.5, },
        { model = "iPad",         inchesDiagonal =  9.7, },
        { model = "iPod touch",   inchesDiagonal =  3.5, },
        { model = "Nexus One",    inchesDiagonal =  3.7, },
        { model = "Nexus S",      inchesDiagonal =  4.0, }, -- Unverified model value
        { model = "Droid",        inchesDiagonal =  3.7, },
        { model = "Droid X",      inchesDiagonal =  4.3, }, -- Unverified model value
        { model = "Galaxy Tab",   inchesDiagonal =  7.0, },
        { model = "Galaxy Tab X", inchesDiagonal = 10.1, }, -- Unverified model value
        { model = "Kindle Fire",  inchesDiagonal =  7.0, }, 
        { model = "Nook Color",   inchesDiagonal =  7.0, },
    }
 
    local device = default_device
    for _, deviceEntry in pairs(devices) do
        if deviceEntry.model == model then
            device = deviceEntry
        end
    end
        
    -- Pixel width, height, and pixels per inch
    device.pixelWidth = pixel_width
    device.pixelHeight = pixel_height
    device.ppi = math.sqrt(pixel_width^2 + pixel_height^2) / device.inchesDiagonal
        
    -- Corona unit width, height, and "Corona units per inch"
    device.coronaWidth = corona_width
    device.coronaHeight = corona_height
    device.cpi = math.sqrt(corona_width^2 + corona_height^2) / device.inchesDiagonal
        
    return device
end