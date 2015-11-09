module(..., package.seeall)
local SceneManager = require("SceneManager")
local utils = require("utils")
local GGData = require("ggdata")
local json = require("json")
local GC = require("AppConstants")

local currPoint = {}
local lastPoint = {}

LocationOffCallback = nil

local TIME_
_G.bgServicesRunning = false

local lastTime, newTime = nil, nil

local BASE_URL = GC.BASE_URL

local NUMBER_OF_SECONDS_BEFORE_FIRING_NOTIFICATION = 0
local TIME_BEFORE_SENDING_LOCATION_SECS = 60

local forwardingUrl = nil


local function getTime()
	return os.time(os.date('*t'))
end

-- TODO: Handle response in the future (if needed)
local function driverLocationCallback(event)
	local messageQ

	local reponse = nil

	--print ("response: "..tostring(event.response))
	
	if (event) then
		response = json.decode(event.response)
	end

   	if (response == nil or response.error_msg == nil) then
    	messageQ = "Invalid Server Response"
	elseif (response.error_msg.errorMessage ~= "") then
	  	messageQ = response.error_msg.errorMessage
	elseif (response.status == "true") then
		messageQ = "Driver Location Sent"
	else
	  	messageQ = "Couldn't Send Driver Location"
	end

	--if (response.locating == "disabled") then
	--	stopLocationService()
	--end
   
	--print ("GBT: (locationCallback) - "..messageQ)
end

function setDriverLocation(lat, lon)
	print ("GBT: Sending Driver Location to Server")
	local url = BASE_URL.."setDriverLocation?sid="..SceneManager.getUserSID().."&lat="..lat.."&lon="..lon
	
	url = url.."&api_key="..(GC.API_KEY or "")
	
	network.request(url, "GET", driverLocationCallback)
	--print ("url: "..url)
end

local locationHandler = function( event )
	-- Check for error (user may have turned off Location Services)
	if event.errorCode then
		--native.showAlert( "GPS Location Error", event.errorMessage, {"OK"} )
		--print( "GBT: Location error (" .. tostring( event.errorMessage )..")" )
	else
		
		local date = os.date( "*t" )
		
		currPoint.date = date.month.."/"..date.day.."/"..date.year
		currPoint.time = date.hour..":"..date.min..":"..date.sec
		
		currPoint.lat = string.format( '%.6f', event.latitude )
		currPoint.lon = string.format( '%.6f', event.longitude )

		_G.hasMoved = false

		local distanceMoved = 0

		if (lastPoint.lat == nil) then
			lastPoint = utils.shallowcopy(currPoint)
		end
		
		_G.accuracy 	= event.accuracy
		_G.currPoint	= currPoint
	
		--print ("current location: "..currPoint.lat..", "..currPoint.lon)

		-- Do we need to send a location?
		newTime = getTime()
		
		if (lastTime ~= nil) then
			if (newTime - lastTime) > TIME_BEFORE_SENDING_LOCATION_SECS then

				setDriverLocation(currPoint.lat, currPoint.lon)
				
				lastTime = newTime
			end
		else
			lastTime = newTime
			setDriverLocation(currPoint.lat, currPoint.lon)
		end

		lastPoint = utils.shallowcopy(currPoint)
		
		_G.bgServicesLastFired = system.getTimer()
	end
end

function startLocationService()
	if (not _G.bgServicesRunning) then
		print ("GBT: Starting Location Service")

		Runtime:addEventListener( "location", locationHandler )
		_G.bgServicesRunning = true

		if (currPoint.lat ~= nil) then
			setDriverLocation(currPoint.lat, currPoint.lon)
		end
	end
end

function stopLocationService()
	if (_G.bgServicesRunning) then
		print ("GBT: Stopping Location Service")

		--local cbResult = LocationOffCallback()

		Runtime:removeEventListener( "location", locationHandler )
		_G.bgServicesRunning = false
	end
end

local function alertOnComplete( event )
	if "clicked" == event.action then
		local i = event.index
		if 1 == i then
			system.openURL(forwardingUrl)
		elseif 2 == i then
			-- Do nothing; dialog will simply dismiss
		end
	end
end

local function onSystemEvent( event )
	--print ("GBT: onSystemEvent() - "..event.type)
    if (event.type == "applicationExit") then
        stopLocationService() 
    elseif (event.type == "applicationStart") or (event.type == "applicationResume")  then
	    
    elseif event.type == "applicationOpen" then
    	native.setProperty( "applicationIconBadgeNumber", 0)
    	if event.url then
    	end	
    end
end

function init()
	print ("GBT: Initializing bgServices")

	_G.bgServicesRunning = false

	_G.accuracy 	= -1
	_G.currPoint	= {lat=0,lon=0}

	Runtime:addEventListener( "system", onSystemEvent )
end
