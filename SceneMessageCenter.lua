local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local newWidget = require("widget")
local GC = require("AppConstants")
local status = require("status")
local alert = require("alertBox")
local utils = require("utils")
local api = require("api")

local MessageX = display.contentCenterX
local MessageY = 360

local BUTTON_OFFSET = 10
local ICON_DELETE_SIZE = 24
local ICON_UNREAD_SIZE = 16
local maxMessageCharLength = 140

local sceneGroup = nil

local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local lblNoObjects = nil
local btnEdit = nil
local btnRefresh = nil

local lvListBGColor = {1,1,1}
local lvListHighlightBGColor = GC.MEDIUM_GRAY
local lvListRowHeight = 100

local PADDING_LEFT = 5
local PADDING_RIGHT = 5
local PADDING_TOP = 5
local PADDING_BOTTOM = 0

local HEADER_HEIGHT = 2
local headerBG = nil

local list = nil
local listTop = nil

local currObjectIndex = nil
local currListRow = nil

local objects = nil

local isEditing = nil

local showingOverlay = nil
local showingToast = nil

local messageQ = nil

local filter = nil

local getObjects
local gettingObjects

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function getRowOffset()
   local offset = ICON_DELETE_SIZE * 0.5 + PADDING_LEFT * 4
   if not isEditing then
      offset = -offset
   end
   return offset
end

-- NOTE: Currently not used. Removed edit button, and added remove option to alert box
local function reloadData()
   local offset = getRowOffset()
   for i = 1, #list._view._rows do
      if (list._view._rows[i]) then
         local row = list._view._rows[i]._view
         row.delete.isVisible = isEditing
         for j=1,#row.elements do
            if (j == 3) then
               row.elements[j].isVisible = not isEditing
            elseif (j == 4) then
               if (isEditing) then
                  row.elements[j].x = row.elements[3].x
               else
                  row.elements[j].x = row.elements[3].stageBounds.xMin - PADDING_LEFT
               end
            else
               -- TODO: This is getting clipped when adjusting to the smaller size
               if (j == 5) then
                  --row.elements[j].width = row.elements[j].width - offset
               end
               row.elements[j].x = row.elements[j].x + offset
            end
         end
      end
   end
end

local function toggleEdit()
   isEditing = not isEditing
   --[[
   if (isEditing) then
      btnEdit:setLabel(SceneManager.getRosettaString("done",1))
   else
      btnEdit:setLabel(SceneManager.getRosettaString("edit",1))
   end
   
   if (list:getNumRows() > 0) then
      reloadData()
   end
   ]]--
end

local function removeObjectCallback(response)
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.status == "true") then
      getObjects()
   else
      messageQ = "could_not_remove"
   end

   showMessage()
end

local function removeObject()
   --db.removeMessage(objects[currObjectIndex].id)
   --getObjects()
   api.deleteNotification({sid=SceneManager.getUserSID(),notificationId=objects[currObjectIndex].notificationId,callback=removeObjectCallback})
end

local function removeOnComplete( event )
   local i = event.target.id
   if 1 == i then
      removeObject()
   end
end

local function showRemovePrompt()
    alert:show({title = SceneManager.getRosettaString("remove"), buttonAlign = "horizontal",
      message = SceneManager.getRosettaString("remove_message"),
            buttons={SceneManager.getRosettaString("remove"),
            SceneManager.getRosettaString("no")},
            callback=removeOnComplete})
end

local function findObjectIndexById(id)
   local index = nil

   for i=1,#objects do
      if objects[i].notificationId == id then
         return i
      end
   end

   return index
end

-- Looks for the loadIdGuid and defaults to manually parsing it in the message text.
-- It should never have to default to parsing, but leaving just in case.
-- NOTE: Noticed that sometimes the loadIdGuid is missing, and have filed a bug report with GBT.
local function parseMessageForShipment(message)
  local shipment = nil

  if (message) then
   if (tonumber(message.loadIdGuid)) then
      shipment = message.loadIdGuid
   elseif (message.body) then
      local sText = string.match(message.body,"#%d+")
      if (sText) then
         shipment = tonumber(string.sub(sText, 2))
      end
   end
  end

  return shipment
end

local function readCallback(response)
   local message = objects[currObjectIndex]
   local category = message.type

   if (response == nil or response.status == nil) then
      
   elseif (response.status == "true") then
      -- NOTE: Deprecated for now
      --db.setMessageRead(message.id)
   end

   --message.read = 1
   --list:reloadData()
   --getObjects()
   
   if (category == GC.MESSAGE_TYPE_ACCESSORIAL) then
      getObjects() -- Overlay so update list
      local shipment = parseMessageForShipment(message)
      SceneManager.goTo("view_accessorials",{loadIdGuid=shipment},true,nil)
   elseif (category == GC.MESSAGE_TYPE_FEEDBACK) then
      SceneManager.goToMyFeedback()
   elseif (category == GC.MESSAGE_TYPE_BANKING) then
      SceneManager.goTo("gbt_bank",nil,false,nil)
   elseif (category == GC.MESSAGE_TYPE_SHIPMENT) then
      SceneManager.goToMyShipments()
   elseif (category == GC.MESSAGE_TYPE_QUOTE) then
      SceneManager.goToMyQuotes()
   end
end

local function handleMessage()
   local notificationId = objects[currObjectIndex].notificationId
   
   api.markNotificationAsRead({sid=SceneManager.getUserSID(),notificationId=notificationId,callback=readCallback})
end

local function objectComplete(event,value)
   local id = value --event.target.id
   
   if (id == 2) then
      showRemovePrompt()
   elseif (id == 1) then
      handleMessage()
   end
end

local function clipText(text,length)
   if (string.len(text) <= length) then
      return text
   else
      return string.sub(text, 1,length).."..."
   end
end

local function showMessageDetails(row)
   currListRow = row
   currObjectIndex = findObjectIndexById(objects[row].notificationId)
   local message = objects[row].body

   if (isEditing) then
      showRemovePrompt()
   elseif (not showingOverlay) then
      alert:show({title = SceneManager.getRosettaString(objects[row].type),
         message = message,
         list = {options = {SceneManager.getRosettaString("view"),SceneManager.getRosettaString("remove")},radio = false},
         buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
         callback=objectComplete
      })
      --[[
      alert:show({title = SceneManager.getRosettaString("message_details"),buttonAlign = "horizontal",
         message = objects[row.index].text.." this is just extra stuff to uncover a bug. but it looks to be working correctly.",
         buttons={SceneManager.getRosettaString("cancel"),
         SceneManager.getRosettaString("remove"),
         SceneManager.getRosettaString("ok")},
         cancel = 1,close=false,
         callback=objectComplete})
      ]]--
   end
end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   row.delete = display.newImageRect(row, "graphics/delete.png", ICON_DELETE_SIZE, ICON_DELETE_SIZE)
   row.delete.x, row.delete.y = PADDING_LEFT + row.delete.width * 0.5, groupContentHeight * 0.5
   row.delete.isVisible = isEditing
   
   row.id = objects[row.index].notificationId
   
   row.elements = {}

   local offset = getRowOffset(row.index)
   
   --row.elements[1] = display.newImageRect( row, "graphics/white_dot.png", ICON_UNREAD_SIZE, ICON_UNREAD_SIZE )
   --row.elements[1]:setFillColor(unpack(GC.ORANGE))
   --row.elements[1].id = "unread"
   --row.elements[1].x, row.elements[1].y = ICON_UNREAD_SIZE * 0.5 + PADDING_LEFT, ICON_UNREAD_SIZE * 0.5 + PADDING_TOP
   --row.elements[1].isVisible = objects[row.index].read == 0

   local unread = tonumber(objects[row.index].read) == 0

   -- notificationId = notification ID
   -- type = category of notification (banking, shipment, quote, etc.)
   -- body = notification message
   -- phoneType = 0 for ios 1 for android
   -- read = 0 for not read 1 for read
   
   row.elements[1] = display.newRect(row,0,0,2,groupContentHeight)
   row.elements[1].defaultColor = GC.ORANGE
   row.elements[1]:setFillColor(unpack(GC.ORANGE))
   row.elements[1].x, row.elements[1].y = row.elements[1].width * 0.5, groupContentHeight * 0.5
   row.elements[1].isVisible = unread

   -- In the future this could change to looking up an integer value
   local category = SceneManager.getRosettaString(objects[row.index].type)

   --row.elements[2] = display.newText(row,category,row.elements[1].stageBounds.xMax + PADDING_LEFT,0,GC.APP_FONT, 12)
   --row.elements[2].y = row.elements[1].y
   row.elements[2] = display.newText(row,category,row.elements[1].stageBounds.xMax + PADDING_LEFT,0,GC.APP_FONT, 12)
   row.elements[2].y = ICON_UNREAD_SIZE * 0.5 + PADDING_TOP
   row.elements[2]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[2].anchorX = 0

   --row.elements[3] = display.newText(row,">",0,0,native.systemFontBold, 14)
   --row.elements[3]:setFillColor(unpack(GC.DARK_GRAY))
   --row.elements[3].anchorX = 1
   --row.elements[3].x, row.elements[3].y = groupContentWidth - PADDING_RIGHT,row.elements[1].y

   -- API doesn't return date, so we disregard for now   
   --row.elements[3] = display.newText(row,objects[row.index].date,0,0,GC.APP_FONT, 12)
   --row.elements[3].id = "date"
   --row.elements[3]:setFillColor(unpack(GC.DARK_GRAY))
   --row.elements[3].anchorX = 1
   --row.elements[3].x, row.elements[3].y = groupContentWidth - PADDING_RIGHT,row.elements[2].y
   
   local textColor = GC.DARK_GRAY
   if (unread) then
      textColor = GC.ORANGE
   end

   local message = objects[row.index].body

   row.elements[3] = display.newText({text=clipText(message,maxMessageCharLength),width= groupContentWidth - row.elements[2].stageBounds.xMin - PADDING_RIGHT - PADDING_LEFT,height=70,x=PADDING_LEFT,y=ICON_UNREAD_SIZE * 0.5 + row.elements[2].height * 0.5 + 2,font=GC.APP_FONT,fontSize=14,align="left"})
   row.elements[3].defaultColor = textColor
   row.elements[3]:setFillColor(unpack(textColor))
   row:insert(row.elements[3])
   row.elements[3].anchorX, row.elements[3].anchorY = 0,0
   --print ("text: "..clipText(message,maxMessageCharLength))
   row.elements[4] = display.newRect(row,0,0,groupContentWidth,1)
   row.elements[4].overColor = GC.DARK_GRAY
   row.elements[4].defaultColor = GC.DARK_GRAY
   row.elements[4]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[4].x, row.elements[4].y = groupContentWidth * 0.5, groupContentHeight
end

-- handles row presses/swipes
local function onRowTouch( event )
   local row = event.target
   local rowSelected = false
   local rowColor = nil
   local defaultColor = GC.DARK_GRAY
   local overColor = GC.WHITE

   if event.phase == "press" then
      rowSelected = true
      rowColor = overColor
   elseif event.phase == "release" then
      rowColor = defaultColor
      showMessageDetails(row.index)
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      rowColor = defaultColor
   end

   if (rowColor) then
      for i=1, #row.elements do
         if (rowSelected and row.elements[i].overColor) then
            row.elements[i]:setFillColor(unpack(row.elements[i].overColor))
         elseif (not rowSelected and row.elements[i].defaultColor) then
            row.elements[i]:setFillColor(unpack(row.elements[i].defaultColor))
         else
            row.elements[i]:setFillColor(unpack(rowColor))
         end
      end
   end
end

local function populateList()
   if (list) then
      list:removeSelf()
      list = nil
   end

   if (objects and #objects > 0) then

      lblNoObjects.isVisible = false
      -- NOTE: Disabled this, and put it into an option
      --btnEdit.isVisible = true
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
      btnEdit.isVisible = false
   end
end

local function getNotificationsCallback(response)
   if (response == nil or response.status == nil) then
      -- Error
   elseif (response.status == "true") then
      objects = response.notifications or {}
   end

   populateList()

   gettingObjects = false

   if (isEditing) then
      toggleEdit()
   end

   -- TODO: This either will be deprecated or need to match the something in the new notification array
   -- Not sure if the API call returns the same notificationId as might possibly be in the push from PushBots
   -- So this is remarked for now.
   
   --[[
   if (_G.pushId) then
      local row = nil
      -- Find our mid within the currently loaded messages, and then pop the details
      for i = 1, #objects do
         if (objects[i].id == _G.pushId) then
            row = i
            break
         end
      end

      if (row) then
         showMessageDetails(row)
      end

      
      _G.pushId = nil
      _G.pushSID = nil -- This is new
   ]]--
   if (_G.push) then
      -- NOTE: Not sure how to handle this yet.
      -- NOTE: Could either match the alert text and hope they are similar, or have the GBT server
      -- send down the notificationId with the push to match up once we get here. If present then pop
      -- an alert.

      _G.push = nil
   end
end

getObjects = function()
   if (gettingObjects) then
      return
   end

   gettingObjects = true
   objects = {}
   -- Disregard the local database, and use the remote API call
   api.getNotificationsByUser({sid=SceneManager.getUserSID(),callback=getNotificationsCallback})

   --objects = db.getMessages(SceneManager.getUserSID(),filter)
end


local function onBack()
   SceneManager.goToDashboard()
end

local function onEventCallback(event)
   if (event.target.id == "back")then
      onBack()
   elseif (event.target.id == "edit") then
      toggleEdit()
   elseif (event.target.id == "refresh") then
      --_G.sendFakeNotification()
      getObjects()
   end
end

function scene:create( event )
   sceneGroup = self.view

   isEditing = false
   showingOverlay = false
   gettingObjects = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("message_center"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
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
   btnRefresh.x, btnRefresh.y = display.contentCenterX, titleBG.stageBounds.yMax + btnRefresh.height * 0.5 + 10
   sceneGroup:insert(btnRefresh)
   
   lblNoObjects = display.newText(sceneGroup, SceneManager.getRosettaString("no_messages"), 0, 0, GC.APP_FONT, 24)
   lblNoObjects:setFillColor(unpack(GC.DARK_GRAY))
   lblNoObjects.isVisible = false
   lblNoObjects.x, lblNoObjects.y = display.contentCenterX, display.contentCenterY

   headerBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, HEADER_HEIGHT )
   headerBG:setFillColor(unpack(GC.DARK_GRAY))
   headerBG.x, headerBG.y = display.contentCenterX, btnRefresh.stageBounds.yMax + headerBG.height * 0.5 + 10

   listTop = headerBG.stageBounds.yMax

   getObjects()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase
   
   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      native.setProperty( "applicationIconBadgeNumber", 0)
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
         composer.removeScene("SceneMessageCenter")
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

   btnRefresh:removeSelf()
   btnRefresh = nil

   headerBG:removeSelf()
   headerBG = nil
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