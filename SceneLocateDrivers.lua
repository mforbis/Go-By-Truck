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

local MessageX = display.contentCenterX
local MessageY = 360

local BUTTON_OFFSET = 10
local ICON_DELETE_SIZE = 24

local sceneGroup = nil

local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local lblNoObjects = nil
local btnRefresh = nil

local lvListBGColor = {1,1,1}
local lvListHighlightBGColor = GC.MEDIUM_GRAY
local lvListRowHeight = 60

local PADDING_LEFT = 10
local PADDING_RIGHT = 10
local PADDING_TOP = 0
local PADDING_BOTTOM = 0

local HEADER_HEIGHT = 50
local headerBG = nil
local lblHeaders = nil
local HEADERS = {"driver","status"}
local HEADER_OFFX = {PADDING_LEFT, display.contentWidth - PADDING_RIGHT}

local list = nil
local listTop = nil

local currObjectIndex = nil
local currListRow = nil

local objects = nil

local messageQ = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="LocateDrivers",reason="Invalid JSON"})
      end

      showStatus(messageQ)
      messageQ = nil
   end
end

local function getRowOffset()
   local offset = 0
   if isEditing then
      offset = ICON_DELETE_SIZE * 0.5 + PADDING_LEFT * 2
   end
   return offset
end

local function reloadData()
   local offset = getRowOffset()
   for i = 1, #list._view._rows do
      if (list._view._rows[i]) then
         local row = list._view._rows[i]._view
         row.delete.isVisible = isEditing
         row.name.x = lblHeaders[1].x + offset
      end
   end
end

local function sendCallback(response)
   --print ("response: "..tostring(response.status))

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      messageQ = "app_sent"
   else
      messageQ = "could_not_send"
   end
   
   showMessage()
end

local function sendComplete(event)
   local id = event.target.id
   
   if (id == 2) then
      api.sendDriverApp({sid=objects[currListRow].userGuid,callback=sendCallback})
   end
end

local function driverLocationOn(date)
   local timeStamp = utils.makeTimeStamp(date)
   --print ("timeStamp: "..timeStamp)
   --print ("date: "..os.date("%B %d, %Y %I:%M:%S %p",timeStamp))
   --print ("diff: "..os.time() - timeStamp)

   return (os.time() - timeStamp) < 10 * 60  -- 10+ minutes off
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
   
   row.delete = display.newImageRect(row, "graphics/delete.png", ICON_DELETE_SIZE, ICON_DELETE_SIZE)
   row.delete.x, row.delete.y = PADDING_LEFT + row.delete.width * 0.5, groupContentHeight * 0.5
   row.delete.isVisible = isEditing
   
   row.id = objects[row.index].trailerId
   
   local offset = getRowOffset(row.index)
   
   row.name = display.newText(row,objects[row.index].name,lblHeaders[1].x,groupContentHeight*0.5,GC.APP_FONT, 16)
   row.name:setFillColor(unpack(GC.DARK_GRAY))
   row.name.anchorX = 0

   local fontSize = 16
   local status = SceneManager.getRosettaString("on")

   if (objects[row.index].modifiedDate) then
      if (not driverLocationOn(objects[row.index].modifiedDate)) then
         status = SceneManager.getRosettaString("last_located")..":\n"..objects[row.index].modifiedDate
         fontSize = 12
      end
   elseif (objects[row.index].latitude == nil and objects[row.index].longitude == nil) then
      status = SceneManager.getRosettaString("never")
   end

   row.status = display.newText( {text=status,width=140,x=lblHeaders[2].x,y=row.name.y,font=GC.APP_FONT,fontSize=fontSize,align="center"} )
   row:insert(row.status)
   row.status:setFillColor(unpack(GC.DARK_GRAY))
   
   --[[
   local length = objects[row.index].length
   if (length == "other") then length = objects[row.index].lengthOther end

   local width = objects[row.index].width
   if (width == "other") then width = objects[row.index].widthOther end
   
   row.trailerLengthWidth = display.newText({text=length.."\n"..width,width=50,x=lblHeaders[2].x,y=row.name.y,font=GC.APP_FONT,fontSize=16,align="center"})
   row:insert(row.trailerLengthWidth)
   row.trailerLengthWidth:setFillColor(unpack(GC.DARK_GRAY))
   
   row.maxPayload = display.newText(row,objects[row.index].maxPayload,lblHeaders[3].x,row.name.y,GC.APP_FONT, 16)
   row.maxPayload:setFillColor(unpack(GC.DARK_GRAY))
   ]]--
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
      if (objects[row.index].latitude and objects[row.index].longitude) then
         SceneManager.showMap({type=GC.DRIVER_LOCATION,data=objects[row.index]})
      else
         alert:show({title = SceneManager.getRosettaString("send_app"),
            message=SceneManager.getRosettaString("driver_never_located_message"),
            buttons={SceneManager.getRosettaString("cancel"),
            SceneManager.getRosettaString("send_app")},buttonAlign="horizontal",
            callback=sendComplete})
      end
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      row.name:setFillColor(unpack(textColor))
      row.status:setFillColor(unpack(textColor))
   end
end

local function populateList()
   if (#objects > 0) then
      if (list) then
         list:removeSelf()
         list = nil
      end

      lblNoObjects.isVisible = false
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

      for i=1,#objects do
         list:insertRow{
            rowHeight = lvListRowHeight,
            rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
         }
      end
   else
      lblNoObjects.isVisible = true
   end
end

local function getObjectsCallback(response)
   if (response == nil or response.locations == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      objects = response.locations
      populateList()
   end

   showMessage()
end

local function getObjects()
   if (_G.messageQ) then
      messageQ = _G.messageQ
      _G.messageQ = nil

      showMessage()
   end

   api.getDriverLocations({sid=SceneManager.getUserSID(),callback=getObjectsCallback})
end

local function onBack()
   SceneManager.goToDashboard()
end

local function onEventCallback(event)
   if (event.target.id == "back")then
      onBack()
   elseif (event.target.id == "refresh") then
      getObjects()
   end
end

function scene:create( event )
   sceneGroup = self.view

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("locate_drivers"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
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
      icon = {default="graphics/refresh.png",width=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,height=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,align="left"},
      width = 140,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnRefresh.x, btnRefresh.y = display.contentCenterX, titleBG.stageBounds.yMax + btnRefresh.height * 0.5 + 10
   sceneGroup:insert(btnRefresh)
   
   lblNoObjects = display.newText(sceneGroup, SceneManager.getRosettaString("no_drivers"), 0, 0, GC.APP_FONT, 24)
   lblNoObjects:setFillColor(unpack(GC.DARK_GRAY))
   lblNoObjects.isVisible = false
   lblNoObjects.x, lblNoObjects.y = display.contentCenterX, display.contentCenterY

   headerBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, HEADER_HEIGHT )
   headerBG:setFillColor(unpack(GC.DARK_GRAY))
   headerBG.x, headerBG.y = display.contentCenterX, btnRefresh.stageBounds.yMax + headerBG.height * 0.5 + 10

   listTop = headerBG.stageBounds.yMax

   lblHeaders = {}

   lblHeaders[1] = display.newText({text=SceneManager.getRosettaString(HEADERS[1],1),x=HEADER_OFFX[1],y=headerBG.y,font=GC.APP_FONT,fontSize=16})
   lblHeaders[1].anchorX = 0
   sceneGroup:insert(lblHeaders[1])

   lblHeaders[2] = display.newText({text=SceneManager.getRosettaString(HEADERS[2],1),x=HEADER_OFFX[2],y=headerBG.y,font=GC.APP_FONT,fontSize=16})
   lblHeaders[2].x = lblHeaders[2].x - lblHeaders[2].width * 0.5
   sceneGroup:insert(lblHeaders[2])

   --lblHeaders[2] = display.newText({text=SceneManager.getRosettaString(HEADERS[2],1),width=70,x=HEADER_OFFX[2],y=headerBG.y, font=GC.APP_FONT,fontSize=12,align="center"})
   --sceneGroup:insert(lblHeaders[2])

   --lblHeaders[3] = display.newText({text=SceneManager.getRosettaString(HEADERS[3],1),width=50,x=HEADER_OFFX[3],y=headerBG.y, font=GC.APP_FONT,fontSize=12,align="center"})
   --sceneGroup:insert(lblHeaders[3])

   getObjects()
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
      composer.removeScene("SceneLocateDrivers")
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

   lblNoObjects:removeSelf()
   lblNoObjects = nil
   
   if (list) then
      list:removeSelf()
      list = nil
   end

   btnRefresh:removeSelf()
   btnRefresh = nil

   headerBG:removeSelf()
   headerBG = nil

   for i=1,#lblHeaders do
      lblHeaders[1]:removeSelf()
      table.remove(lblHeaders, 1)
   end
   lblHeaders = nil
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