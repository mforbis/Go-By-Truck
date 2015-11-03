local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local utils = require("utils")
local ProgressDialog = require("progressDialog")
local locationTemplate = require("locationTemplate")
local fileio = require("fileio")

local sceneGroup = nil
local overlay = nil
local border = nil
local header = nil
local title = nil
local close = nil
local mapview = nil
local pd
local lblMessage = nil

local TIMEOUT_MS = 60000
local PADDING = 10

local params
local poiLat, poiLon
local centerLat, centerLon
local sAddr, dAddr

local actionTimer = nil
local loadingPage

local MAP_TYPE_DIRECTIONS = "directions"
local MAP_TYPE_LOCATION = "location"

local mapType

local function stopPD()
   if (pd) then
      pd:dismiss()
      pd = nil
   end
end

local function stopTimeout()
   if (actionTimer) then
      timer.cancel(actionTimer)
      actionTimer = nil
   end
end

local function handleTimeout()
   lblMessage.text = SceneManager.getRosettaString("server_timeout")
   lblMessage.isVisible = true
   stopWebView()
end

local function startTimeout()
   stopTimeout()
   actionTimer = timer.performWithDelay(TIMEOUT_MS, handleTimeout)
end

local function stopWebView()
   loadingPage = false
   stopPD()
   mapview:stop()
end

local function webViewCallback( event )
   --print ("webViewCallback:")
   --print ("type: "..tostring(event.type))
   --print ("errorCode: "..tostring(event.errorCode))
   --print ("url: "..tostring(event.url))
   --print ("-------------")

   if (event.errorCode) then
      --lblMessage.text = SceneManager.getRosettaString("server_error")
      --stopWebView()
      -- TODO: Fix situations on iOS where errorMessage = 'NSURLerrorDomain error -999'
      -- We can ignore, but haven't seen to insure code will work 100%
   elseif (event.type == "loaded") then
      stopWebView()
      mapview.isVisible = true
   end
end

local function loadWebView(url, baseDirectory)
   loadingPage = true
   lblMessage.isVisible = false
   mapview.isVisible = false
   pd = ProgressDialog:new({graphic="graphics/busy.png"})
   --"https://www.google.com/maps/dir/Springfield,+MO/Springfield,+MO/Grapevine,+TX/@35.801282,-95.2065427,7z/data=!3m1!4b1!4m20!4m19!1m5!1m1!1s0x87cf62f745c8983f:0x6bfd6cb31e690da0!2m2!1d-93.2922989!2d37.2089572!1m5!1m1!1s0x87cf62f745c8983f:0x6bfd6cb31e690da0!2m2!1d-93.2922989!2d37.2089572!1m5!1m1!1s0x864c2a75ec1fa05f:0x2c300170a0312f0d!2m2!1d-97.0780654!2d32.9342919!3e0"
   mapview:request(url, baseDirectory)
end

local function createLocationFile()
   local l = locationTemplate.LOCATION_TEMPLATE

   if (mapType == MAP_TYPE_LOCATION) then
      l = string.gsub(l, "{sAddr}", "", 1)
      l = string.gsub(l, "{dAddr}", "", 1)
      
      l = string.gsub(l, "{poiLat}", poiLat, 1)
      l = string.gsub(l, "{poiLon}", poiLon, 1)
   else
      l = string.gsub(l, "{sAddr}", string.lower(sAddr), 1)
      l = string.gsub(l, "{dAddr}", string.lower(dAddr), 1)

      l = string.gsub(l, "{poiLat}", "null", 1)
      l = string.gsub(l, "{poiLon}", "null", 1)
   end

   fileio.write(l,GC.LOCATION_FILENAME)
end

local function loadMap()
   createLocationFile()

   loadWebView(GC.LOCATION_FILENAME,system.DocumentsDirectory)
end

local function handleClose()
   if (not loadingPage) then
      composer.hideOverlay()
   end
end

local function onEventCallback(event)
   if (event.target.id == "close") then
   end
end

local function createWebview()
   mapview = native.newWebView( 0, 0, border.width, border.height - 32 )
   mapview:addEventListener( "urlRequest", webViewCallback )
   mapview.x, mapview.y = lblMessage.x, lblMessage.y
   sceneGroup:insert(mapview)

   loadMap()
end

function scene:create( event )
   sceneGroup = self.view

   local strTitle = ""
   local fontSize = 18

   -- For testing
   --event.params = {type=GC.DRIVER_LOCATION,data={name="Driver Mobile",latitude="32.87358",longitude="-96.93071"}}
   
   if (event.params) then
      params = event.params
      
      if (params.type) then
         if (params.type == GC.DRIVER_LOCATION or params.type == GC.SHIPMENT_LOCATION) then
            mapType = MAP_TYPE_LOCATION

            strTitle = params.data.name
            if (params.type == GC.DRIVER_LOCATION) then strTitle=strTitle.."'s Location" end

            poiLat = params.data.latitude
            poiLon = params.data.longitude
            centerLat = poiLat
            centerLon = poiLon
         elseif (params.type == GC.SHOW_DIRECTIONS) then
            mapType = MAP_TYPE_DIRECTIONS

            sAddr = params.data.sAddr
            dAddr = params.data.dAddr
            strTitle = sAddr.." --> "..dAddr
            fontSize = 16
         end
      end
   end

   overlay = display.newRect( sceneGroup,0, 0, display.contentWidth, display.contentHeight )
   overlay:setFillColor(0,0,0,0.5)
   overlay.x, overlay.y = display.contentCenterX, display.contentCenterY

   border = display.newRect(sceneGroup,0,0,display.contentWidth - 40, display.contentHeight - 40)
   border.strokeWidth = 2
   border:setStrokeColor(1, 1, 1)
   border:setFillColor(unpack(GC.WHITE))
   border.x, border.y = overlay.x, overlay.y

   header = display.newRect(sceneGroup,0,0,border.width, 40)
   header:setFillColor(unpack(GC.DARK_GRAY))
   header.x, header.y = border.x, border.stageBounds.yMin + header.height * 0.5

   title = display.newText({text = strTitle, x=0, y=0, width=header.width, height = header.height, align="center",font = GC.APP_FONT, fontSize = fontSize})
   sceneGroup:insert(title)
   title:setFillColor(1, 1, 1)
   title.x, title.y = header.x, header.y

   close = display.newImageRect(sceneGroup,"graphics/close.png",30,30)
   close:addEventListener("tap",handleClose)
   close.x, close.y = border.stageBounds.xMax, border.stageBounds.yMin

   lblMessage = display.newText(sceneGroup,"",0,0,GC.APP_FONT, 16)
   lblMessage.isVisible = false
   lblMessage:setFillColor(unpack(GC.DARK_GRAY))
   lblMessage.x, lblMessage.y = border.x, border.y + 16

   if (system.getInfo("platformName") == "Android" and mapType == MAP_TYPE_LOCATION) then
      mapview = native.newMapView(0, 0, border.width, border.height - 32)
      mapview.mapType = "normal"
      mapview.x, mapview.y = lblMessage.x, lblMessage.y
      sceneGroup:insert(mapview)

      --mapview:setCenter(tonumber(poiLat), tonumber(poiLon))
      mapview:setRegion(tonumber(poiLat), tonumber(poiLon), 0.17, 0.17, false)

      local function mapAddressHandler( event )
         local success, errorMessage = true, ""

         if event.isError then
            success = false
            errorMessage = event.errorMessage
         else
            success, errorMessage = mapview:addMarker( tonumber(poiLat), tonumber(poiLon), { title=params.data.name or "", imageFile =  { baseDir=system.ResourceDirectory, filename="graphics/greentruck.png"} } )
         end

         if (success) then
            -- Everything ok
         else
            -- Error, so default to webview this time
            print (errorMessage)
            mapview:removeSelf()
            mapview = nil

            createWebview()
         end
      end

      -- Markers don't seem to show up all the time unless we drop them after returning from a callback
      mapview:nearestAddress(tonumber(poiLat), tonumber(poiLon), mapAddressHandler )
   else
      createWebview()
   end
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = handleClose
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneMap")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   border:removeSelf()
   border = nil

   close:removeSelf()
   close = nil

   title:removeSelf()
   title = nil

   if (mapview) then
      mapview:removeSelf()
      mapview = nil
   end

   header:removeSelf()
   header = nil
end

---------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
---------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

---------------------------------------------------------------------------------

return scene