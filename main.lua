display.setStatusBar( display.HiddenStatusBar )
io.output():setvbuf('no')
local GC = require("AppConstants")

local notifications = require( "plugin.notifications" )
local utils = require("utils")

--set to true or false to debug
_G.beta = false

-- This hits the API call sendErrorEmail
local function myUnhandledErrorListener( event )

    local iHandledTheError = true

    local strError = "GBT - Runtime Error"
    if iHandledTheError then
        print( strError..": ", event.errorMessage )
    else
        print( strError..": ", event.errorMessage )
    end
    
    if (not _G.beta) then
      local api = require("api")
        api.sendErrorEmail({recoverable=false,subject="runtime error",body = event.errorMessage})
    end

    local alert = require("alertBox")
    alert:show({
      title = "Fatal Error",
      message = "An error has occurred and administrators have been notified",
        buttons={"OK"},
        callback=native.requestExit
    })

    return iHandledTheError
end

Runtime:addEventListener("unhandledError", myUnhandledErrorListener)

function Log(s)
   if (_G.beta) then
      print (s)
   end
end

--[[
local function myUnhandledErrorListener( event )

    local iHandledTheError = true

    if iHandledTheError then
        print( "Handling the unhandled error", event.errorMessage )
    else
        print( "Not handling the unhandled error", event.errorMessage )
    end
    
    return iHandledTheError
end

Runtime:addEventListener("unhandledError", myUnhandledErrorListener)
]]--

local SceneManager = require("SceneManager")

SceneManager.init()

-- Start of Push Notifications
local GGData = require("ggdata")
local pushbots = require( "mod_pushbots" )
pushbots:init( "54ae9cc71d0ab103278b45fe" )
pushbots.showStatus = true
pushbots.showJSON = true


_G.deviceToken = nil
_G.push = nil

local function addTag(id)
	--id = 9999
   if (tonumber(id) and _G.deviceToken) then
	     --print("id = "..tostring(id))
      local objTableData = {tag=id,token=_G.deviceToken}
      pushbots:addTag(objTableData,nil)
   end
end

local function removeTag(id)
   if (tonumber(id) and _G.deviceToken) then
      local objTableData = {tag=id,token=_G.deviceToken}
      pushbots:removeTag(objTableData,nil)
   end
end

_G.addTag = addTag
_G.removeTag = removeTag

local forwardingUrl = nil

local function parseAlert(event)
   local title = "GBT"
    local alert = nil

    if (event) then
      -- Push alert (message) depends on platform (iOS or Android)
      alert = event.alert

      -- Android has it in the custom field
      if (event.custom and event.custom.alert) then
         alert = event.custom.alert
      end
      if (event.custom and event.custom.notificationId ) then
          notificationId  = event.custom.notificationId
      end

      if (alert and alert ~= "") then
         alert = string.gsub( alert, "\\", "")
       end
   end

    return title, alert
end

local function alertOnComplete( event )
    if "clicked" == event.action then
        local i = event.index
        
        if (i == 1) then
         if (forwardingUrl ~= nil and forwardingUrl ~= "") then
               system.openURL(forwardingUrl)
         else
            SceneManager.goToMessageCenter()
         end
        else
            -- Dismiss
            _G.push = nil
        end
    end
end

local function handlePush(title, alert,sid)
   -- Only show if successfully added to db and currently logged in user is expected to receive it
   local currSID = SceneManager.getUserSID()

   if (_G.push and tonumber(_G.push.id) and currSID and currSID ~= "" and tonumber(sid) == tonumber(currSID)) then
      local composer = require("composer")

      local currScene = composer.getSceneName("current")
      
      if (currScene ~= "SceneMessageCenter") then

        if (currScene == nil or currScene == "SceneLogin") then
          -- Do nothing, since we could still be logging in, or app is loading. Dashboard should pick this up.
        else
          -- If currently in the dashboard, update the new badge count
          if (currScene == "SceneDashboard") then
            local DScene = composer.getScene("SceneDashboard")

            if (DScene) then
              -- This will call the updater that will then display the following alert once done
              -- Otherwise, we might have a multiple alert problem or neverending ProgressDialog
              DScene:update()
            end
          else
            native.showAlert(title, alert, { "Message Center", "Dismiss" }, alertOnComplete)
         end
       end
      else
         -- Get reference and manually execute the details popup
         local MCScene = composer.getScene("SceneMessageCenter")

         if (MCScene) then
            MCScene:update()
         end
      end
   end
end

local function handleNotification(event)
    local title, alert = parseAlert(event)

    if (title and alert) then
       if (event.custom) then
         forwardingUrl = event.custom.forward_url
       end

       if (forwardingUrl ~= nil and forwardingUrl ~= "") then
           native.showAlert(title, alert, { "Cancel", "OK" }, alertOnComplete)
       elseif (event.custom and event.custom.type and event.custom.type ~= "" and alert and alert ~= "") then
         -- If we are currently handling a push, don't show the new one
         -- This should slightly change if we ever go back to local db storage
         if (_G.push == nil) then
           -- Increase badge count
           local badge_num = native.getProperty( "applicationIconBadgeNumber" )
           if (badge_num) then
            native.setProperty( "applicationIconBadgeNumber", badge_num + 1 )
          end

            --print("badge number is "..tostring(badge_num))

           local sid = event.custom.sid or SceneManager.getUserSID()
           --local sid = "1383"

           local db = require("db")

           -- It is possible to receive the push before 1st run, so we make sure
           -- there is a db ready.
           if (not db.getHasInitialized()) then
              db.init()
           end

           -- NOTE: Might not assume SID is correct, and maybe use what is pushed in the payload. ??
           --insertMessage(sid, item, item2, type, type2, text)
           -- NOTE: We are using an API call to get notifications, but not ready to rip out the legacy
           -- local storage just yet.
           _G.push = {}
           _G.push.id = 99--db.insertMessage(sid,event.custom.item,nil,event.custom.type,nil,alert)
           _G.push.sid = sid
           _G.push.alert = alert
           _G.push.item = event.custom.item
           
           if (_G.push.id and _G.push.id > 0) then
              handlePush(title,alert,sid)
           end
          end
       else
         native.showAlert(title, alert , { "OK" } )
       end
   end
end

local function onNotification( event )
    --native.setProperty( "applicationIconBadgeNumber", 0 )
    --Log ("onNotification: "..tostring(event.type))
    --Log("my device id is",event.token)

    if event.type == "remoteRegistration" then
        if event.token ~= nil then
         _G.deviceToken = SceneManager.getSetting(SceneManager.SETTINGS_NOTIFICATION_DEVICE_TOKEN,event.token)

            --Log ("token: "..tostring(_G.deviceToken))
            --Log ("hasRegistered: "..tostring(SceneManager.getSetting(SceneManager.SETTINGS_NOTIFICATION_HAS_REGISTERED,nil)))
            ------------------------------------------------------------
            -- PUSHBOTS REGISTRATION
            ------------------------------------------------------------
            if (SceneManager.getSetting(SceneManager.SETTINGS_NOTIFICATION_HAS_REGISTERED,nil) == nil) then
               Log ("Registering device...")
               pushbots:registerDevice( _G.deviceToken, pushbots.NIL, function(e)
               if not e.error then
                  --native.showAlert( "Pushbots", e.response, { "OK" } )
                  if e.code == 200 then
                        pushbots:clearBadgeCount( _G.deviceToken )
                        Log ("Registered")
                        SceneManager.setSetting(SceneManager.SETTINGS_NOTIFICATION_HAS_REGISTERED,true)
                  end
                  else
                     --native.showAlert( "Pushbots", e.error, { "OK" } )
                  end
                  end
               )
            end
            ------------------------------------------------------------

            -- Print the registration event to the log.
            Log("### --- Registration Event ---")
            --utils.printTable(event)
        else
            Log("no token returned, too bad")
        end
    elseif event.type == "remote" then
        -- A push notification has just been received. Print it to the log.
        Log("### --- Notification Event ---")
        utils.printTable(event)

        local settings = GGData:new("settings")
        _G.deviceToken = settings:get("deviceToken")

        pushbots:clearBadgeCount(_G.deviceToken)

        --mark opened
        pushbots:pushOpened()

        handleNotification(event)
    end
 	--local badge_num = native.getProperty( "applicationIconBadgeNumber" )
	--print("badge number is "..tostring(badge_num))

end

-- For testing code quickly
_G.sendFakeNotification = function()
   handleNotification({alert="The shipper for shipment #442 has accepted a quote in the amount of $4,834.29",custom={type="quote",item=442}})
end

-- Handles if the app was closed
local launchArgs = ...

if launchArgs and launchArgs.notification then
   -- call the event listener manually:
    onNotification( launchArgs.notification )
end
--utils.printTable(launchArgs)

Runtime:addEventListener( "notification", onNotification )

native.setProperty( "applicationIconBadgeNumber", 0 )
-- End of Push Notifications

local function sendLocalNotification(name,distance)
   --local badge_count = 
   
   local notifyOptions =
   {
      alert = "",
      badge = badge_count,
      --sound = "",
      --custom = { scene = "sceneManage" }
   }
   local feed_notifier = system.scheduleNotification( NUMBER_OF_SECONDS_BEFORE_FIRING_NOTIFICATION, notifyOptions )
   system.vibrate()
end

notifications.registerForPushNotifications()

-- Initialize background handlers
local bgServices = require("bgServices")
bgServices.init()
--417-501-8919 shipper phone #

--print ("device ratio: "..display.pixelHeight / display.pixelWidth)
--print ("deviceWidth: "..display.pixelWidth..", deviceHeight: "..display.pixelHeight)
--print ("contentWidth: "..display.contentWidth..", contentHeight: "..display.contentHeight)

-- Debug, and development below this line
-- NOTE: Make sure plugins are enabled in build.settings for release build

if (_G.beta) then
   local GC = require("AppConstants")

   SceneManager.setUserRoleType(GC.USER_ROLE_TYPE_CARRIER)
   --SceneManager.setUserRole(GC.API_ROLE_DISPATCH)
   --SceneManager.goToLocateDrivers()
   --SceneManager.goToPostShipment()
   local composer = require("composer")
   --SceneManager.setUserSID("1330") -- carrierMobile
   --SceneManager.setUserSID("1384") -- carrierJan
   SceneManager.setUserSID("1169") -- carrierFeb
   --SceneManager.setUserSID("1336") -- shipperMobile
   --SceneManager.setUserSID("1383") -- shipperJan
   --SceneManager.setUserSID("1168") -- shipperFeb (has matched shipments that can be used for locating)
   --SceneManager.setUserSID("1350") -- driverMobile -- 1337
   --SceneManager.setUserSID("1183") -- carrierDriver1
   --SceneManager.setUserSID("1184") -- rewardShipper, ShipperReward

   SceneManager.readSessionId()
   SceneManager.setAccessorialState(true) -- When a driver
   --composer.gotoScene("SceneFindFreight",{effect=GC.SCENE_TRANSITION_TYPE,time=GC.SCENE_TRANSITION_TIME_MS})
   --composer.gotoScene("ScenePostShipment",{effect=GC.SCENE_TRANSITION_TYPE,time=GC.SCENE_TRANSITION_TIME_MS})
   --SceneManager.showLocation()
   --SceneManager.goToMyQuotes()
   --SceneManager.showLoadQuotes()
   --SceneManager.goToMyTrailers()
   --SceneManager.goToMyBanking()
   --SceneManager.showShipmentDetails()
   --_G.shipmentTypeState = 4 -- Incomplete
   --SceneManager.goToMyShipments()
   --SceneManager.showClaimPhoto()
   --SceneManager.goToLocateShipment()
   --SceneManager.showRequestedAccessorials()
  SceneManager.goToDashboard()
  --SceneManager.showReferGBT()
  --SceneManager.goToMyFeedback()
   --SceneManager.goTo("my_shipments")
  --SceneManager.goToLoginScene()
   --SceneManager.showMap()
   --[[
      https://www.gbthq.com:8443/shipper/requestHistory (loadIdGuid is in POST data)
      https://www.gbthq.com:8443/carrier/requestHistory?loadIdGuid=424
      https://www.gbthq.com:8443/driver/requestHistory?loadIdGuid=424

   ]]--

   --local db = require("db")
   --db.insertMessage(SceneManager.getUserSID(), 427, '', 'accessorial', '', 'The shipper for shipment #427 has denied an accessorial request.')
   --db.insertMessage(SceneManager.getUserSID(), '','', 'banking', '', 'Go By Truck has placed two small deposits in a personal or business bank account. Please login to verify the account.')
   --db.insertMessage(SceneManager.getUserSID(), '','', 'banking', '', 'Go By Truck has placed two small deposits in a personal or business bank account. Please login to verify the account.')
   --db.insertMessage(SceneManager.getUserSID(), 457, '', 'feedback', '', 'Don\'t forget to leave feedback for the shipper for shipment #457.')
   --db.insertMessage(SceneManager.getUserSID(), 442, 400, 'quote', '', 'The shipper for shipment #442 has accepted a quote in the amount of $4,834.29')
   --db.insertMessage(SceneManager.getUserSID(), 442, '', 'shipment', '', 'The shipper for shipment #442 has requested an update on the location of the shipment.')

else
   --SceneManager.goToLoginScene()
   SceneManager.showOverlay("SceneChooser","")
   --_G.sendFakeNotification()
end

_G.alertBoxes = 0

local function handleBack()
  local composer = require("composer")
  local currScene = composer.getSceneName( "current" )
  --print ("currScene: "..currScene)
  --print("_G.apiCall = "..tostring(_G.apiCall))
  --print("_G.alert = "..tostring(_G.alert))
  --print("type(_G.customOverlay) = "..tostring(type(_G.customOverlay)))
  --print("type(_G.overlay) = "..tostring(type(_G.overlay)))
  --print("type(_G.sceneExit) = "..tostring(type(_G.sceneExit)))
  --print("_G.appExit = "..tostring(_G.appExit))
  --print("----------------------------------")
  
  -- NOTE: These have to be checked in the order they will be stacked on the scene
  if (_G.apiCall == true) then
    -- Do nothing
  elseif (_G.toolsMenu) then
    _G.toolsMenu:hide()
    _G.toolsMenu = nil
  elseif (_G.alertBoxes > 0) then
    -- We have alerts
  elseif (_G.alert) then
    --_G.alert:forceClose()
    --_G.alert = nil
  elseif (_G.customOverlay and type(_G.customOverlay) == "function") then
    _G.customOverlay()
    _G.customOverlay = nil
  elseif (_G.overlay and type(_G.overlay) == "function") then
    _G.overlay()
    _G.overlay = nil
  elseif (_G.sceneExit and type(_G.sceneExit) == "function") then
    _G.sceneExit()
    _G.sceneExit = nil
  elseif (_G.appExit == true) then
    -- NOTE: Current allowed scenes SceneLogin and SceneDashboard
    -- This should help keep the app from closing abruptly on the user if we miss one of the above.
    native.requestExit()
  end
end

local function onKeyEvent( event )
   local phase = event.phase
   local keyName = event.keyName
   local handled = false

   --print( event.phase, event.keyName )

  if ( "back" == keyName and phase == "up" ) or 
  ( "a" == keyName and phase == "down" ) then
      handleBack()
  elseif ("n" == keyName and phase == "down") then
    -- Send fake push notification for testing
    _G.sendFakeNotification()
  end
   
  return true
end
-- ALEX
--[[
_G.handleTemp1 = 0

local function onKeyEvent( event )
   local phase = event.phase
   local keyName = event.keyName
   local handled = false

   print( event.phase, event.keyName )

   if ( "back" == keyName and phase == "up" ) and (GC.GOT_LIST == true or GC.TOOLS_OVERLAY == true) then
      --handleBack()
	  print("CHECKING AND CATCHING A BACK PRESS WHEN A LIST OVERLAY IS ABOVE AN OVERLAY")
	  --GC.LISTWIDGET_HOLDER:removeSelf() -- THIS REMOVES THE INFO BELOW THE SMALL LIST
   elseif ( "back" == keyName and phase == "up" ) and (GC.GOT_LIST == false or GC.TOOLS_OVERLAY == false) then
      handleBack()
   end
   if  ( "a" == keyName and phase == "down" ) and _G.handleTemp1 == 0 then
   _G.handleTemp1 = _G.handleTemp1+1
	timer.performWithDelay(1000, function()
	
		print("return _G.handleTemp1 number back to center")
		_G.handleTemp1 = 0
	end, 1)
      handleBack()
	end
   return true
end

]]--
--add the key callback
Runtime:addEventListener( "key", onKeyEvent )

