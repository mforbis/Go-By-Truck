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
local MessageY = display.contentHeight - 40

local BUTTON_OFFSET = 10
local ICON_DELETE_SIZE = 24

local sceneGroup = nil

local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local lblNoObjects = nil
local btnEdit = nil
local btnAdd = nil
local count = nil

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
local HEADERS = {"trailer_type","length_width","max_payload"}
local HEADER_OFFX = {PADDING_LEFT, display.contentWidth - 120, display.contentWidth - 40}

local list = nil
local listTop = nil

local currObjectIndex = nil
local currListRow = nil

local objects = nil

local isEditing = nil

local showingOverlay = nil
local showingToast = nil

local messageQ = nil

local function setCount(value)
   if (count) then
      if (tonumber(value)) then
         count.text = " ("..value..")"
      else
         count.text = value
      end

      title.x = display.contentCenterX - count.width * 0.5
      count.x = title.stageBounds.xMax + count.width * 0.5
   end
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="MyTrailers",reason="Invalid JSON"})
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
         row.trailerType.x = lblHeaders[1].x + offset
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

local function removeObjectCallback(response)
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.status == "true") then
      list:deleteRow(currListRow)
      if (list:getNumRows() == 0) then
         list.isVisible = false
         lblNoObjects.isVisible = true
         --toggleEdit()
         btnEdit.isVisible = false
         setCount("")
      else
         setCount(list:getNumRows())
      end
   else
      messageQ = "could_not_remove"
   end

   showMessage()
end

local function removeObject()
   api.removeTrailer({sid=SceneManager.getUserSID(),id=objects[currObjectIndex].trailerId,callback=removeObjectCallback})
end

local function removeOnComplete( event )
   local i = event.target.id
   if 1 == i then
      removeObject()
   end
end

local function showRemovePrompt()
    alert:show({title = SceneManager.getRosettaString("remove"), buttonAlign = "horizontal",
      message = SceneManager.getRosettaString("remove_trailer_question"),
            buttons={SceneManager.getRosettaString("yes"),
            SceneManager.getRosettaString("no")},
            callback=removeOnComplete})
end

local function findObjectIndexById(id)
   local index = nil

   for i=1,#objects do
      if objects[i].trailerId == id then
         index = i
      end
   end

   return index
end

local onComplete

local function showAddEditTrailer(object)
   -- NOTE: Old way of using a native scene
   --SceneManager.goToAddEditTrailer(objects[currObjectIndex])

   -- NOTE: New way that uses a webview
   local params = nil

   if (object) then
      params = {trailerId=objects[currObjectIndex].trailerId}
   end

   SceneManager.goTo("trailer_addedit",params,true,onComplete)
end

local function objectComplete(event,value)
   --local id = event.target.id
   local id = value

   if (id == 1) then
      -- Edit
      showAddEditTrailer(objects[currObjectIndex])
   elseif (id == 2) then
      -- Delete
      showRemovePrompt()
   end
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
   
   row.trailerType = display.newText(row,objects[row.index].trailerType,lblHeaders[1].x,groupContentHeight*0.5,GC.APP_FONT, 16)
   row.trailerType:setFillColor(unpack(GC.DARK_GRAY))
   row.trailerType.anchorX = 0
   
   local length = objects[row.index].length
   if (length == "other") then length = objects[row.index].lengthOther end

   local width = objects[row.index].width
   if (width == "other") then width = objects[row.index].widthOther end
   
   local lengthWidth

   if (width == nil or length == nil) then
      lengthWidth = GC.TRAILER_MISSING_ATTRIBUTE_TEXT
   else
      lengthWidth = length.."\n"..width
   end

   row.trailerLengthWidth = display.newText({text=lengthWidth,width=50,x=lblHeaders[2].x,y=row.trailerType.y,font=GC.APP_FONT,fontSize=16,align="center"})
   row:insert(row.trailerLengthWidth)
   row.trailerLengthWidth:setFillColor(unpack(GC.DARK_GRAY))
   
   local maxPayload = objects[row.index].maxPayload or GC.TRAILER_MISSING_ATTRIBUTE_TEXT

   row.maxPayload = display.newText(row,maxPayload,lblHeaders[3].x,row.trailerType.y,GC.APP_FONT, 16)
   row.maxPayload:setFillColor(unpack(GC.DARK_GRAY))
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
      currObjectIndex = findObjectIndexById(row.id)
      if (isEditing) then
         showRemovePrompt()
      elseif (not showingOverlay) then
         alert:show({title = SceneManager.getRosettaString("select_location"),
            list = {options = {SceneManager.getRosettaString("edit"),SceneManager.getRosettaString("delete")},radio = false},
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=objectComplete})
--[[
         alert:show({title = SceneManager.getRosettaString("select_option"),
            buttons={SceneManager.getRosettaString("edit"),
            SceneManager.getRosettaString("cancel")},
            cancel = 2,close=false,
            callback=objectComplete})
]]--
      end
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      row.trailerLengthWidth:setFillColor(unpack(textColor))
      row.trailerType:setFillColor(unpack(textColor))
      row.maxPayload:setFillColor(unpack(textColor))
   end
end

local function populateList()
   if (#objects > 0) then
      if (list) then
         list:removeSelf()
         list = nil
      end
      setCount(#objects)

      lblNoObjects.isVisible = false
      btnEdit.isVisible = false
      list = newWidget.newTableView {
         top = listTop,
         height = display.contentHeight - listTop,
         width = display.contentWidth,
         hideBackground = true,
         hideScrollBar = false,
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
      btnEdit.isVisible = false
      setCount("")
   end
end

local function getObjectsCallback(response)
   if (response == nil or response.trailers == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      objects = response.trailers
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

   if (isEditing) then
      toggleEdit()
   end

   api.getMyTrailers({sid=SceneManager.getUserSID(),callback=getObjectsCallback})
end

onComplete = getObjects

local function onBack()
   SceneManager.goToDashboard()
end

local function onEventCallback(event)
   if (event.target.id == "back")then
      onBack()
   elseif (event.target.id == "edit") then
      toggleEdit()
   elseif (event.target.id == "add") then
      showAddEditTrailer()
   end
end

function scene:create( event )
   sceneGroup = self.view

   isEditing = false
   showingOverlay = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("my_trailers"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   count = display.newText(sceneGroup,"",0,0,GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   count.x, count. y = display.contentWidth - 25, titleBG.y

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

   btnEdit = widget.newButton{
      id = "edit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("edit",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 60,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnEdit.x, btnEdit.y = display.contentWidth - btnEdit.width * 0.5 - 5 , titleBG.y
   btnEdit.isVisible = false
   sceneGroup:insert(btnEdit)

   btnAdd = widget.newButton{
      id = "add",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("add",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      icon = {default="graphics/plus.png",width=GC.ACTION_BUTTON_ICON_SIZE,height=GC.ACTION_BUTTON_ICON_SIZE,align="left"},
      width = 140,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnAdd.x, btnAdd.y = display.contentCenterX, titleBG.stageBounds.yMax + btnAdd.height * 0.5 + 10
   sceneGroup:insert(btnAdd)
   
   lblNoObjects = display.newText(sceneGroup, SceneManager.getRosettaString("no_trailers"), 0, 0, GC.APP_FONT, 24)
   lblNoObjects:setFillColor(unpack(GC.DARK_GRAY))
   lblNoObjects.isVisible = false
   lblNoObjects.x, lblNoObjects.y = display.contentCenterX, display.contentCenterY

   headerBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, HEADER_HEIGHT )
   headerBG:setFillColor(unpack(GC.DARK_GRAY))
   headerBG.x, headerBG.y = display.contentCenterX, btnAdd.stageBounds.yMax + headerBG.height * 0.5 + 10

   listTop = headerBG.stageBounds.yMax

   lblHeaders = {}

   lblHeaders[1] = display.newText({text=SceneManager.getRosettaString(HEADERS[1],1),x=HEADER_OFFX[1],y=headerBG.y,font=GC.APP_FONT,fontSize=16})
   lblHeaders[1].anchorX = 0
   sceneGroup:insert(lblHeaders[1])

   lblHeaders[2] = display.newText({text=SceneManager.getRosettaString(HEADERS[2],1),width=70,x=HEADER_OFFX[2],y=headerBG.y, font=GC.APP_FONT,fontSize=12,align="center"})
   sceneGroup:insert(lblHeaders[2])

   lblHeaders[3] = display.newText({text=SceneManager.getRosettaString(HEADERS[3],1),width=70,x=HEADER_OFFX[3],y=headerBG.y, font=GC.APP_FONT,fontSize=12,align="center"})
   sceneGroup:insert(lblHeaders[3])

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
      if (not showingOverlay and not showingToast) then
         composer.removeScene("SceneMyTrailers")
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

   lblNoObjects:removeSelf()
   lblNoObjects = nil
   
   if (list) then
      list:removeSelf()
      list = nil
   end

   btnEdit:removeSelf()
   btnEdit = nil

   btnAdd:removeSelf()
   btnAdd = nil

   headerBG:removeSelf()
   headerBG = nil

   count:removeSelf()
   count = nil

   for i=1,#lblHeaders do
      lblHeaders[1]:removeSelf()
      table.remove(lblHeaders, 1)
   end
   lblHeaders = nil
end

function scene:update()
   getObjects()
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