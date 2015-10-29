local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local api = require("api")
local shipperInfo = require("shipperInfo")
local utils = require("utils")
local status = require("status")

local LIST_ROW_HEIGHT = 152
local AUTO_ACCEPT_HEADER_HEIGHT = 20
local AUTO_ACCEPT_HEADER_WIDTH = 130
local AUTO_ACCEPT_HEADER_BG_COLOR = {200/255,200/255,200/255}
local EVEN_ROW_COLOR = {238/255,238/255,238/255}
local RESULTS_HEIGHT = 20
local PADDING = 10
local SPACE = 5
local LINE_HEIGHT = 2
local DIVIDER = "  |  "

local sceneGroup = nil
local bg = nil
local btnClose = nil
local title = nil
local titleBG = nil
local list = nil
local bgResults, lblResults = nil, nil

local objects = nil

local currListRow

local apiCommand
local messageQ = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,display.contentHeight - 100,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function updateResultsLabel()
   lblResults.text = #objects.." "..SceneManager.getRosettaString("shipment").."(s)"
end

local function apiCallback(response)
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      if (apiCommand == "view_shipper_profile") then
         -- Simple hack to insert text for current company status
         response.companyStatusName = SceneManager.getRosettaString(utils.statusCodeToStatusName(response.companyStatus,true),1)
         shipperInfo:show(response)
      elseif (apiCommand == "shipment_details") then
         --shipmentDetails:show({scene="find_freight",shipment=response.shipment})
         SceneManager.showShipmentDetails({shipment = response.shipment,role=SceneManager.getUserRoleType(),canEdit=false})
      end
   end

   showMessage()
end

local function optionOnComplete(event,value)
   local id = value
   
   if (id == "shipment_details") then
      apiCommand = "shipment_details"
      api.getShipmentDetails({sid=SceneManager.getUserSID(),id=objects[currListRow].loadIdGuid,callback=apiCallback})
   elseif (id == "view_shipper_profile") then
      apiCommand = "view_shipper_profile"
      api.getShipperInfo({sid=SceneManager.getUserSID(),shipperId=objects[currListRow].shipperId,callback=apiCallback})
   elseif (id == "quote_this_shipment") then
      SceneManager.goTo("quote_shipment_find",{loadIdGuid=objects[currListRow].loadIdGuid,lowestQuote=objects[currListRow].lowestQuote,tripMiles=objects[currListRow].tripMiles,external="false"},true)
      --https://www.gbthq.com:8443/carrier/quotePopup?loadIdGuid=140&lowestQuote=&tripMiles=609&external=false
   elseif (id == "counter_shipment_quote") then
   elseif (id == "view_map") then
      SceneManager.showMap({type=GC.SHOW_DIRECTIONS,data={sAddr=objects[currListRow].fromCityState,dAddr=objects[currListRow].toCityState}})
   end
end

-- NOTE: These options should change slightly based on current shipment details
local function getOptions()
   local ids, options = {},{}

   table.insert(ids, "shipment_details")
   table.insert(options, SceneManager.getRosettaString("shipment_details"))

   -- NOTE: Should only be able to show when shipment is in one of the following states:
   -- MATCHED, ARBITRATION, ARBITRATION_RESOLVED, RELEASED, CANCELLED_RESOLVED
   --table.insert(ids, "view_shipper_profile")
   --table.insert(options, SceneManager.getRosettaString("view_shipper_profile"))

   local lblQuote

   -- TODO: Quote should be quote or counter quote, but don't have isLowestQuote field in data
   if (objects[currListRow].isLowestQuote) then
   elseif (objects[currListRow].lowestQuote) then
      lblQuote = "counter_shipment_quote"
   else
      lblQuote = "quote_this_shipment"
   end

   if (lblQuote) then
      table.insert(ids, lblQuote)
      table.insert(options, SceneManager.getRosettaString(lblQuote))
   end

   --table.insert(ids, "view_map")
   --table.insert(options, SceneManager.getRosettaString("view_map"))

   return options, ids
end

local function showOptions()
   local options, ids = getOptions()
   alert:show({title = SceneManager.getRosettaString("select_option"),
      list = {options = options,radio = false},ids = ids,   
      buttons = {SceneManager.getRosettaString("cancel")},cancel = 1,
      callback=optionOnComplete})
end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   local strLine
   local yOffset

   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group
   
   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   row.elements = {}

   local object = objects[row.index]
   local index = 0
   yOffset = 0

   if object.autoAccept then
      index = index + 1
      row.elements[index] = display.newRect(0,0,AUTO_ACCEPT_HEADER_WIDTH,AUTO_ACCEPT_HEADER_HEIGHT)
      row.elements[index]:setFillColor(unpack(AUTO_ACCEPT_HEADER_BG_COLOR))
      row.elements[index].color = AUTO_ACCEPT_HEADER_BG_COLOR
      row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, row.elements[index].height * 0.5
      row:insert(row.elements[index])

      index = index + 1

      row.elements[index] = display.newText({text=SceneManager.getRosettaString("shipper_auto_accepts"),fontSize = 12,font = GC.APP_FONT})
      row.elements[index]:setFillColor(unpack(GC.WHITE))
      row.elements[index].color,row.elements[index].overColor = GC.WHITE,GC.DARK_GRAY
      row.elements[index].x, row.elements[index].y = row.elements[index-1].x,row.elements[index-1].y
      row:insert(row.elements[index])

      yOffset = AUTO_ACCEPT_HEADER_HEIGHT * 0.5 + PADDING
   else
      yOffset = 0--PADDING * 0.5
   end

   index = index + 1

   row.elements[index] = display.newText({text=string.upper(object.fromCityState).." > "..string.upper(object.toCityState),fontSize = 14,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.ORANGE))
   row.elements[index].color = GC.ORANGE
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   yOffset = row.elements[index].y
   row:insert(row.elements[index])
   --[[
   index = index + 1
   
   row.elements[index] = display.newImageRect(row, "graphics/white_arrow_right.png", 28, 16)
   row.elements[index].color = GC.ORANGE
   row.elements[index]:setFillColor(unpack(GC.ORANGE))
   row.elements[index].x, row.elements[index].y = row.elements[index-1].stageBounds.xMax + row.elements[index].width * 0.5 + SPACE, yOffset
   
   index = index + 1

   row.elements[index] = display.newText({text=string.upper(object.toCityState),fontSize = 16,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index-1].stageBounds.xMax + row.elements[index].width * 0.5 + SPACE, yOffset
   row:insert(row.elements[index])
   ]]--

   strLine = SceneManager.getRosettaString("shipment",1)..": "..object.loadIdGuid

   if (object.stops) then
      strLine = strLine..DIVIDER..SceneManager.getRosettaString("stops",1)..": "..object.stops
   end

   strLine = strLine..DIVIDER..SceneManager.getRosettaString("pieces",1)..": "..object.pieces
   --strLine = strLine..DIVIDER..SceneManager.getRosettaString("weight",1)..": "..object.weight
   
   index = index + 1
   yOffset = row.elements[index-1].y + row.elements[index-1].height * 0.5 + LINE_HEIGHT

   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   row:insert(row.elements[index])

   index = index + 1
   yOffset = row.elements[index-1].y + row.elements[index-1].height * 0.5 + LINE_HEIGHT

   strLine = SceneManager.getRosettaString("commodity",1)..": "..object.commodity
   
   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT,width=groupContentWidth - PADDING * 2,align="left"})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   
   index = index + 1

   row.elements[index] = display.newRect(0, 0, groupContentWidth, row.elements[index-1].height)
   row.elements[index]:setFillColor(unpack(EVEN_ROW_COLOR))
   row.elements[index].color,row.elements[index].overColor = EVEN_ROW_COLOR,GC.ORANGE
   row.elements[index].x, row.elements[index].y = groupContentWidth * 0.5, row.elements[index-1].y

   row:insert(row.elements[index])
   row:insert(row.elements[index-1])

   index = index + 1
   yOffset = row.elements[index-1].y + row.elements[index-1].height * 0.5 + LINE_HEIGHT

   strLine = SceneManager.getRosettaString("trip_miles",1)..": "..object.tripMiles
   strLine = strLine..DIVIDER..SceneManager.getRosettaString("pickup",1)..": "..object.pickupDate
   strLine = strLine..DIVIDER..SceneManager.getRosettaString("delivery",1)..": "..object.dropoffDate
   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   row:insert(row.elements[index])

   index = index + 1
   yOffset = row.elements[index-1].y + row.elements[index-1].height * 0.5 + LINE_HEIGHT

   strLine = SceneManager.getRosettaString("lowest_quote",1)..": "
   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   
   index = index + 1

   row.elements[index] = display.newRect(0, 0, groupContentWidth, row.elements[index-1].height)
   row.elements[index]:setFillColor(unpack(EVEN_ROW_COLOR))
   row.elements[index].color,row.elements[index].overColor = EVEN_ROW_COLOR,GC.ORANGE
   row.elements[index].x, row.elements[index].y = groupContentWidth * 0.5, row.elements[index-1].y

   row:insert(row.elements[index])
   row:insert(row.elements[index-1])

   if (object.lowestQuote and object.lowestQuote ~= "") then
      index = index + 1
      strLine = utils.getCurrencySymbol()
   
      strLine = strLine..utils.formatMoney(object.lowestQuote)
      row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
      row.elements[index]:setFillColor(unpack(GC.LIGHT_GREEN))
      row.elements[index].color = GC.LIGHT_GREEN
      row.elements[index].x, row.elements[index].y = row.elements[index-1].stageBounds.xMax + row.elements[index].width * 0.5 + SPACE, yOffset + row.elements[index].height * 0.5
      row:insert(row.elements[index])
   end
   
   index = index + 1
   yOffset = row.elements[index-1].y + row.elements[index-1].height * 0.5 + LINE_HEIGHT

   strLine = SceneManager.getRosettaString(utils.getTrailerTypeLabel(object.loadType))

   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY2))
   row.elements[index].color = GC.DARK_GRAY2
   row.elements[index].x, row.elements[index].y = row.elements[index].width * 0.5 + PADDING, yOffset + row.elements[index].height * 0.5
   row:insert(row.elements[index])

   index = index + 1

   strLine = utils.formatNumber(object.shipperScore,1).."%"
   -- NOTE: web app look changed, but leaving for future change
   --local scoreColor = utils.getFeedbackScoreColor(object.shipperScore)
   row.elements[index] = display.newText({text=strLine,fontSize = 14,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY2))
   row.elements[index].color = GC.DARK_GRAY2
   row.elements[index].x, row.elements[index].y = groupContentWidth - row.elements[index].width * 0.5 - PADDING, row.elements[index-1].y
   row:insert(row.elements[index])

   index = index + 1
   
   strLine = SceneManager.getRosettaString("shipper_feedback_score")..": "
   row.elements[index] = display.newText({text=strLine,fontSize = 12,font = GC.APP_FONT})
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x, row.elements[index].y = row.elements[index-1].stageBounds.xMin - row.elements[index].width * 0.5 - SPACE, yOffset + row.elements[index].height * 0.5
   row:insert(row.elements[index])

   if (#objects > 1 and row.index < #objects) then
      index = index + 1

      row.elements[index] = display.newRect(0,0,groupContentWidth,1)
      row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
      row.elements[index].x, row.elements[index].y = groupContentWidth * 0.5, groupContentHeight - 1
      row:insert(row.elements[index])
   end
end

-- handles row presses/swipes
local function onRowTouch( event )
   local row = event.target
   local rowPressed, rowSelected = false, false
   local textColor

   if event.phase == "press" then
      rowPressed = true
   elseif event.phase == "release" then
      currListRow = row.index
      rowSelected = true
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
   end

   for i=1,#row.elements do
      textColor = row.elements[i].color or GC.DARK_GRAY
      if (rowPressed) then
         textColor = row.elements[i].overColor or GC.WHITE
      end
      row.elements[i]:setFillColor(unpack(textColor))
   end
   
   if (rowSelected) then
      showOptions()
   end
end

local function populateList()
   updateResultsLabel()
   if (#objects > 0) then
      -- insert rows into list (tableView widget)
      local colors = {GC.LIGHT_GRAY2,GC.WHITE}

      local rowHeight
      for i=1,#objects do
         rowHeight = LIST_ROW_HEIGHT
         if (objects[i].autoAccept) then
            rowHeight = rowHeight + AUTO_ACCEPT_HEADER_HEIGHT
         end
         if (string.len(objects[i].commodity) > 40) then
            rowHeight = rowHeight + 20
         end
         list:insertRow{
            rowHeight = rowHeight,
            rowColor = {default=GC.WHITE,over=GC.ORANGE}
         }
      end

   else
      -- NOTE: We should never get here
   end
end

local function onClose()
   --composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,GC.SCENE_TRANSITION_TIME_MS)
   --SceneManager.goToFindFreight()
   composer.gotoScene("SceneFindFreight",{effect=GC.OVERLAY_ACTION_DISMISS,time=GC.SCENE_TRANSITION_TIME_MS})
end

local function onEventCallback(event)
   if (event.target.id == "close") then
      onClose()
   end
end

function scene:create( event )
   sceneGroup = self.view

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, 35 )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("results"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   bgResults = display.newRect(0,0,display.contentWidth,RESULTS_HEIGHT)
   bgResults.x, bgResults.y = titleBG.x, titleBG.stageBounds.yMax + bgResults.height * 0.5
   bgResults:setFillColor(unpack(GC.DARK_GRAY))
   sceneGroup:insert(bgResults)

   lblResults = display.newText(sceneGroup,"",0,0, GC.APP_FONT, 12)
   lblResults:setFillColor(unpack(GC.WHITE))
   lblResults.x, lblResults.y = bgResults.x, bgResults.y
   
   btnClose = widget.newButton{
      id = "close",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("search_again",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 130,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnClose.x, btnClose.y = display.contentCenterX, display.contentHeight - btnClose.height * 0.5 - 10
   sceneGroup:insert(btnClose)

   divider = display.newRect( 0, 0, display.contentWidth, 2 )
   divider.anchorY = 0
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnClose.stageBounds.yMin - PADDING
   sceneGroup:insert(divider)

   list = widgetNew.newTableView {
      top = 0,
      height = (divider.stageBounds.yMin - bgResults.stageBounds.yMax),
      width = display.contentWidth,
      hideBackground = true,
      onRowRender = onRowRender,
      onRowTouch = onRowTouch,
      noLines = true
   }
   list.y = bgResults.stageBounds.yMax + list.height * 0.5
   sceneGroup:insert(list)

   -- NOTE: For testing scene during building phase
   if (not event.params) then
      local json = require("json")
      local response = json.decode('{"status":"true","shipments":[{"loadIdGuid":"367","shipperId":"1336","shipperScore":"100.0","autoAccept":true,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","stops":"1","pieces":"3","weight":"13000","commodity":"Machinery & Equipment - Sewing Machines (Lots of them)","tripMiles":"606","pickUpDate":"10/03/2014","deliveryDate":"11/01/2014","lowestQuote":"300.00","loadType":"9"},{"loadIdGuid":"367","shipperId":"1336","shipperScore":"100.0","autoAccept":false,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","stops":"1","pieces":"3","weight":"13000","commodity":"Machinery & Equipment - Sewing Machines (Lots of them)","tripMiles":"606","pickUpDate":"10/03/2014","deliveryDate":"11/01/2014","lowestQuote":"300.00","loadType":"9"}],"error_msg":{"errorMessage":"","error":""}}')
      event.params = {}
      event.params.shipments = response.shipments
   end

   if (event.params and event.params.shipments) then
      objects = event.params.shipments
      populateList()
   end
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
   elseif ( phase == "did" ) then
      _G.sceneExit = close
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnClose:removeSelf()
   btnClose = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   list:removeSelf()
   list = nil

   divider:removeSelf()
   divider = nil

   bgResults:removeSelf()
   bgResults = nil

   lblResults:removeSelf()
   lblResults = nil

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