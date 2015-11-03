local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local newWidget = require("widget")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local alert = require("alertBox")
local utils = require("utils")

-- TODO: Handle successful uploads (pod). Message sent back via _G.messageQ)
-- NOTE: claim photos will allow multiples, so we don't just close like the pod above

local MessageX = display.contentCenterX
local MessageY = 360

local BUTTON_OFFSET = 10

local sceneGroup = nil

local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local lblNoShipments = nil
local btnRefresh = nil
local divider = nil

local lvListBGColor = {1,1,1}
local lvListHighlightBGColor = GC.MEDIUM_GRAY
local lvListRowHeight = 70

local PADDING_LEFT = 10
local PADDING_RIGHT = 10
local PADDING_TOP = 5
local PADDING_BOTTOM = 15

local list = nil
local listTop = nil

local currListRow = nil

local shipments = nil

local showingOverlay = nil
local showingToast = nil

local API_TIMEOUT_MS = 10000
local apiTimer = nil
local messageQ = nil

local shipmentOptions = nil

local dropOffIndex = nil

local detailsCommand = nil

local function getLocationsByType(type,lTable)
   local locations = {}
   for i = 1, #lTable do
      if (tostring(lTable[i].type) == tostring(type)) then
         table.insert(locations,i)
      end
   end

   return locations
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      --showStatus(messageQ)
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function showToast(text)
   showingToast = true
   composer.removeScene("toast")
   local options = {isModal = true, params = {message = text}}
   composer.showOverlay("toast", options)
end

local function hideToast()
   if (showingToast) then
      composer.hideOverlay("toast")
      showingToast = false
   end
end

local function stopTimeout()
   if (apiTimer) then
      timer.cancel(apiTimer)
      apiTimer = nil
   end
end

local function handleTimeout()
   stopTimeout()
   hideToast()
   showStatus("server_timeout")
end

local function startTimeout()
   stopTimeout()
   apiTimer = timer.performWithDelay(API_TIMEOUT_MS, handleTimeout)
end

local function reloadData()
   for i = 1, #list._view._rows do
      if (list._view._rows[i]) then
         local row = list._view._rows[i]._view
         row.delete.isVisible = isEditing
         row.number.x = PADDING_LEFT
         row.locations.x = row.number.x
      end
   end
end

local function toggleEdit()
   isEditing = not isEditing

   if (isEditing) then
      btnEdit:setLabel(SceneManager.getRosettaString("done",1))
   else
      btnEdit:setLabel(SceneManager.getRosettaString("edit",1))
   end
   
   if (list:getNumRows() > 0) then
      reloadData()
   end
end

local function showMap()
   -- View Map
   -- NOTE: Temporary
   -- NOTE: This has been temporarily moved here, since we can't call an overlay
   -- while displaying another.
   -- TODO: Once the getMyShipments API call matches getDriverLoads this
   -- will be deprecated.

   --SceneManager.showMap({type=GC.DRIVER_LOCATION,data=objects[row.index]})
   SceneManager.showMap({type=GC.SHIPMENT_LOCATION,data={latitude = shipments[currListRow].latitude, longitude=shipments[currListRow].longitude, name=SceneManager.getRosettaString("shipment")..": #"..shipments[currListRow].loadIdGuid}})
end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   -- LOOK:
   -- Shipment #
   -- Date/Time Posted, Auto Accept Amount:
   -- Centered to the right a view ref # button
   
   row.id = shipments[row.index].loadIdGuid
   
   local offset = PADDING_LEFT
   
   row.number = display.newText(row,SceneManager.getRosettaString("shipment").." #: "..shipments[row.index].loadIdGuid,0,0,GC.APP_FONT, 16)
   row.number:setFillColor(unpack(GC.DARK_GRAY))
   row.number.anchorX = 0
   row.number.x, row.number.y = offset, PADDING_TOP + row.number.height * 0.5

   row.date = display.newText(row,SceneManager.getRosettaString("posted")..": "..(shipments[row.index].postedDate or shipments[row.index].pickUpDate),0,0,GC.APP_FONT, 12)
   row.date:setFillColor(unpack(GC.DARK_GRAY))
   row.date.anchorX = 0
   row.date.x, row.date.y = (offset), groupContentHeight - PADDING_BOTTOM

   -- TODO: Once the getMyShipments API call matches getDriverLoads this
   -- will be deprecated.
   -- NOTE: Might have to format separate elements later (ie. add zip)
   local fromCityState = shipments[row.index].fromCityState
   local toCityState = shipments[row.index].toCityState

   if (fromCityState == nil) then
      fromCityState = shipments[row.index].pickup.cityState
      toCityState = shipments[row.index].delivery.cityState
   end

   row.locations = display.newText(row,fromCityState.." ----> "..toCityState,0,0,GC.APP_FONT, 12)
   row.locations:setFillColor(unpack(GC.DARK_GRAY))
   row.locations.anchorX, row.locations.anchorY = 0,1
   row.locations.x, row.locations.y = offset, row.number.y+30
end

local function validLocation(lat,lng)
   local valid = true

   valid = (lat ~= nil and lat ~= "" and lat ~= 0)
   valid = (lng ~= nil and lng ~= "" and lng ~= 0)
   
   return valid
end

-- handles row presses/swipes
local function onRowTouch( event )
   local row = event.target
   local rowSelected = false
   local textColor = nil

   if event.phase == "press" then
      rowSelected = true
      textColor = GC.WHITE
   elseif event.phase == "release" then
      textColor = GC.DARK_GRAY
      currListRow = row.index
      -- TODO: Show map or alert if no GPS location
      if (validLocation(shipments[row.index].latitude, shipments[row.index].longitude)) then
         showMap()
      else
         alert:show({title = SceneManager.getRosettaString("no_location"),
            message=SceneManager.getRosettaString("locate_shipment_error"),
            buttons={SceneManager.getRosettaString("ok")},
         })
      end
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      row.locations:setFillColor(unpack(textColor))
      row.date:setFillColor(unpack(textColor))
      row.number:setFillColor(unpack(textColor))
   end
end

local function populateList()
   if (#shipments > 0) then
      local top = btnRefresh.stageBounds.yMax + 10
      lblNoShipments.isVisible = false
      
      list = newWidget.newTableView {
         top = listTop,
         height = display.contentHeight - listTop,
         width = display.contentWidth,
         hideBackground = true,
         onRowRender = onRowRender,
         onRowTouch = onRowTouch,
         noLines = true
         --maskFile = "graphics/"..lvListMaskFileName
      }
      sceneGroup:insert(list)

      -- insert rows into list (tableView widget)
      local colors = {GC.LIGHT_GRAY2,GC.WHITE}

      for i=1,#shipments do
         list:insertRow{
            rowHeight = lvListRowHeight,
            rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
         }
      end
   else
      lblNoShipments.isVisible = true
   end
end

local function getShipmentsCallback(response)
   hideToast()
   stopTimeout()
   
   if (response == nil or response.shipments == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      -- TODO: Somebody thought it was a good idea to not follow the service
      -- request for the API, so the format of getMyShipments doesn't match getDriverLoads
      -- We now need to format the shipments, so they match from here on out
      if (isDriver) then
         shipments = {}
         for key, value in pairs(response.shipments) do
            -- turn address1..address2..addressn into locations table
            value.locations = {}
            local i = 1
            while (value["address"..i]) do
               table.insert(value.locations,value["address"..i])
               i = i + 1
            end
            table.insert( shipments, value )
         end
      else
         shipments = response.shipments
      end

      populateList()
   end

   showMessage()
end

local function getShipments()
   if (isEditing) then
      toggleEdit()
   end
   if (list) then
      list:removeSelf()
      list = nil
   end

   --showToast()
   --startTimeout()

   api.getMyShipments({sid=SceneManager.getUserSID(),type="matched",showPD=false,callback=getShipmentsCallback})
end

local function onBack()
   SceneManager.goToDashboard()
end

local function onEventCallback(event)
   if (event.target.id == "back")then
      onBack()
   elseif (event.target.id == "refresh") then
      getShipments()
   end
end

function scene:create( event )
   sceneGroup = self.view

   showingOverlay = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   listTop = titleBG.stageBounds.yMax

   title = display.newText(sceneGroup, SceneManager.getRosettaString("locate_shipment"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnHome = widget.newButton{
      id = "back",
      default = "graphics/home.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnHome.x, btnHome.y = btnHome.width * 0.5 + 5, titleBG.y
   sceneGroup:insert(btnHome)

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnBack.x, btnBack.y = display.contentWidth - btnBack.width * 0.5 - 5, titleBG.y
   sceneGroup:insert(btnBack)

   btnRefresh = widget.newButton{
      id = "refresh",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("refresh",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      icon = {default="graphics/refresh.png",width=GC.ACTION_BUTTON_ICON_SIZE,height=GC.ACTION_BUTTON_ICON_SIZE,align="left"},
      width = 140,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnRefresh.x = display.contentCenterX
   
   btnRefresh.y = titleBG.stageBounds.yMax + btnRefresh.height * 0.5 + 10
   sceneGroup:insert(btnRefresh)

   divider = display.newRect( 0, 0, display.contentWidth, 2 )
   divider.anchorY = 0
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnRefresh.stageBounds.yMax + 10
   sceneGroup:insert(divider)

   listTop = divider.stageBounds.yMax
   
   lblNoShipments = display.newText(sceneGroup, SceneManager.getRosettaString("no_results_found"), 0, 0, GC.APP_FONT, 24)
   lblNoShipments:setFillColor(unpack(GC.DARK_GRAY))
   lblNoShipments.isVisible = false
   lblNoShipments.x, lblNoShipments.y = display.contentCenterX, display.contentCenterY

   getShipments()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.sceneExit = onBack
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      if (not showingOverlay and not showingToast) then
         composer.removeScene("SceneLocateShipment")
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnBack:removeSelf()
   btnBack = nil

   btnHome:removeSelf()
   btnHome = nil
   
   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   lblNoShipments:removeSelf()
   lblNoShipments = nil
   
   if (list) then
      list:removeSelf()
      list = nil
   end

   btnRefresh:removeSelf()
   btnRefresh = nil

   divider:removeSelf()
   divider = nil
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
