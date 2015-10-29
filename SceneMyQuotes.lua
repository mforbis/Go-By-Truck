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

local lvListBGColor = {1,1,1}
local lvListHighlightBGColor = GC.MEDIUM_GRAY

local lvListRowHeight = 80

local listTop = nil

local PADDING_LEFT = 10
local PADDING_RIGHT = 10
local PADDING_TOP = 5
local PADDING_BOTTOM = 5

local sceneGroup = nil
local bg = nil
local btnBack = nil
local btnHome = nil
local btnEdit = nil
local title = nil
local titleBG = nil
local btnFilter = nil
local btnRefresh = nil
local lblNoQuotes = nil
local countBg,count = nil, nil

local list = nil
local currListRow = nil

local showingOverlay = nil

local quotes = nil

local filterOption = nil

local isEditing = nil
local isCarrier = nil

local API_TIMEOUT_MS = 10000
local apiTimer = nil
local messageQ = nil

local currLoadId
local forceLoadQuotes

local onComplete = nil

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
      --showStatus(messageQ)

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="MyQuotes",reason="Invalid JSON"})
      end

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

local function getRowOffset(index)
   local row = list._view._rows[index]._view
   local offset = PADDING_LEFT
   if isEditing then
      offset = offset + row.delete.stageBounds.xMax
   end
   return offset
end

local function getDetailsCallback(response)
   hideToast()
   stopTimeout()

   if (response == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      response.loadIdGuid = response.loadIdGuid or response.options.loadIdGuid
      
      if (response.forkLift == nil and response.forklift) then
         response.forkLift = response.forklift
         response.liftgate = nil
      end

      SceneManager.showShipmentDetails({shipment = response,role=SceneManager.getUserRoleType(),canEdit=false,callback=detailsCallback})
   end

   showMessage()
end

local function getQuotesByLoadId(id)
   local q = {}

   for i = 1, #quotes do
      if (quotes[i].loadIdGuid == id) then
         table.insert(q,quotes[i])
      end
   end

   return q
end

local function removeObjectCallback(response)
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.status == "true") then
      list:deleteRow(currListRow)
      if (list:getNumRows() == 0) then
         list.isVisible = false
         lblNoQuotes.isVisible = true
         
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
   api.removeQuote({sid=SceneManager.getUserSID(),id=quotes[currListRow].quoteId,callback=removeObjectCallback})
   print("removing quote here")
   GC.GOT_LIST = false
   GC.LISTWIDGET_HOLDER = nil
end

local function removeOnComplete( event )
print("event.name is "..tostring(event))
   local i = event.target.id
   if 1 == i then
      removeObject()
   end
end

local function showRemovePrompt()
	GC.GOT_LIST = true
	print("GC.GOT_LIST = "..tostring(GC.GOT_LIST))
    alert:show({title = SceneManager.getRosettaString("remove"), buttonAlign = "horizontal",
      message = SceneManager.getRosettaString("remove_quote_question"),
            buttons={SceneManager.getRosettaString("yes"),
            SceneManager.getRosettaString("no")},
            callback=removeOnComplete})
end

local function loadQuotesCallback(response)
   messageQ = nil

   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      if (response.status and #response.quotes > 0) then
         -- TODO: Show overlay of quotes
         --SceneManager.showLoadQuotes({quote=quotes[currListRow],quotes=response.quotes})
      else
         messageQ = "no_results_found"
      end
   end

   showMessage()
end

local function getLoadQuotes()
   api.getLoadQuotes({sid=SceneManager.getUserSID(),id=quotes[currListRow].loadIdGuid,callback=loadQuotesCallback})
end

local function quoteComplete(event,value)
   local id = value
   print (event,value)
   if (id == "re-quote") then
      SceneManager.goTo("re-quote",{quoteId=quotes[currListRow].quoteId,loadIdGuid=quotes[currListRow].loadIdGuid,type="newQuote"},true,onComplete)
      --SceneManager.showReQuote({quotes=getQuotesByLoadId(quotes[currListRow].loadIdGuid)})
   elseif (id == "shipper_counter") then
      SceneManager.goTo("shipper_counter",{quoteId=quotes[currListRow].quoteId,loadIdGuid=quotes[currListRow].loadIdGuid,type="counterQuote"},true,onComplete)
   elseif (id == "accept_load") then
      SceneManager.goTo("accept_load",{quoteId=quotes[currListRow].quoteId,loadIdGuid=quotes[currListRow].loadIdGuid,source="quoteManager"},true,onComplete)
   elseif (id == "delete") then
      showRemovePrompt()
   elseif (id == "details") then
      --api.getShipmentDetails({sid=SceneManager.getUserSID(),id=quotes[currListRow].loadIdGuid,callback=getDetailsCallback})
      SceneManager.goTo("shipment_details",{loadIdGuid=quotes[currListRow].loadIdGuid},true,onComplete)
   elseif (id == "view_quotes") then
      SceneManager.goTo("view_quotes",{loadIdGuid=quotes[currListRow].loadIdGuid},true,onComplete)
      --getLoadQuotes()
   end
end

local function getQuoteChoices()
   local choices,ids = {},{}

   local statusId = quotes[currListRow].statusId

   -- TODO: This will change based on role and/or quote status later on
   if (isCarrier) then
      if (GC.QUOTE_TYPES[filterOption] == "countered" or GC.QUOTE_TYPES[filterOption] == "quoted") then
         table.insert(choices,SceneManager.getRosettaString("re-quote"))
         table.insert(ids,"re-quote")
      end

      if (statusId == GC.QUOTE_TYPE_SHIPPER_COUNTER) then
         table.insert(choices,SceneManager.getRosettaString("counter_quote"))
         table.insert(ids,"shipper_counter")
      elseif (statusId == GC.QUOTE_TYPE_PENDING_APPROVED) then
         --ACCEPTED CONFIRM
         table.insert(choices,SceneManager.getRosettaString("confirm_shipment"))
         table.insert(ids,"accept_load")
      end
   else
      -- TODO: Shipper specific options
      table.insert(choices,SceneManager.getRosettaString("view_quotes"))
      table.insert(ids,"view_quotes")
   end

   if (statusId ~= GC.QUOTE_TYPE_LOST_QUOTE) then
      table.insert(choices,SceneManager.getRosettaString("shipment_details"))
      table.insert(ids,"details")
   end

   -- Shippers have the quotes grouped by load, so we will handle deleting there
   if (isCarrier) then
      table.insert(choices,SceneManager.getRosettaString("delete"))
      table.insert(ids,"delete")
   end

   return choices,ids
end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   local numLines = 3

   -- TODO: Modify to allow different elements based on isCarrier
   local rowHeight = (lvListRowHeight - PADDING_TOP * (numLines + 1)) / numLines
   local yOffset = rowHeight * 0.5 + PADDING_TOP

   row.delete = display.newImageRect(row, "graphics/delete.png", 24, 24)
   row.delete.x, row.delete.y = PADDING_LEFT + row.delete.width * 0.5, groupContentHeight * 0.5
   row.delete.isVisible = isEditing
   
   row.id = quotes[row.index].loadIdGuid
   
   local offset = getRowOffset(row.index)
   
   row.number = display.newText(row,SceneManager.getRosettaString("shipment").." #: "..quotes[row.index].loadIdGuid,0,0,GC.APP_FONT, 16)
   row.number:setFillColor(unpack(GC.DARK_GRAY))
   row.number.anchorX = 0
   row.number.x, row.number.y = offset, yOffset

   --row.date = display.newText(row,SceneManager.getRosettaString("posted")..": "..quotes[row.index].postedDate,0,0,GC.APP_FONT, 12)
   --row.date:setFillColor(unpack(GC.DARK_GRAY))
   --row.date.anchorX = 1
   --row.date.x, row.date.y = groupContentWidth - PADDING_RIGHT, row.number.y

   local quoteLabel = "lowest_quote"
   local quoteAmount = quotes[row.index].lowestQuote
   
   yOffset = yOffset + rowHeight + PADDING_TOP

   row.locations = display.newText(row,quotes[row.index].fromCityState.." ----> "..(quotes[row.index].toCityState or "N/A"),0,0,GC.APP_FONT, 12)
   row.locations:setFillColor(unpack(GC.DARK_GRAY))
   row.locations.anchorX = 0
   row.locations.x, row.locations.y = offset, yOffset

   yOffset = yOffset + rowHeight + PADDING_TOP

   if (isCarrier) then
      quoteLabel = "my_quote_amount"
      quoteAmount = quotes[row.index].quoteAmount
      row.date = display.newText(row,SceneManager.getRosettaString("modified_date")..": "..quotes[row.index].modifiedDate,0,0,GC.APP_FONT, 12)
      row.date:setFillColor(unpack(GC.DARK_GRAY))
      row.date.anchorX = 0
      row.date.x, row.date.y = offset, yOffset

      local status = quotes[row.index].statusId
      local info = nil

      if (status == GC.QUOTE_TYPE_SHIPPER_COUNTER) then
         info = "shipper_countered"
      elseif (status == GC.QUOTE_TYPE_PENDING_APPROVED) then
         info = "accepted_confirm"
      end

      if (info) then
         row.info = display.newText(row,SceneManager.getRosettaString(info),0,0,GC.APP_FONT, 12)
         row.info:setFillColor(unpack(GC.DARK_GRAY))
         row.info.x, row.info.y = groupContentWidth - row.info.width * 0.5 - PADDING_RIGHT, yOffset
      end
   else
      local fontSize = 13
      
      local reserve = tonumber(quotes[row.index].reserve) or 0
      local fundedAmount = tonumber(quotes[row.index].fundedAmount) or 0

      if (reserve >= 1000 or fundedAmount >= 1000) then
         fontSize = 12
      end

      reserve = utils.formatMoney(reserve)
      
      fundedAmount = utils.formatMoney(fundedAmount)
      
      row.reserve = display.newText(row,SceneManager.getRosettaString("auto_accept")..": "..utils.getCurrencySymbol()..tostring(reserve),0,0,GC.APP_FONT, fontSize)
      row.reserve:setFillColor(unpack(GC.DARK_GRAY))
      row.reserve.anchorX = 0
      row.reserve.x, row.reserve.y = offset, yOffset

      row.funded = display.newText(row,SceneManager.getRosettaString("funded")..": "..utils.getCurrencySymbol()..tostring(fundedAmount),0,0,GC.APP_FONT, fontSize)
      row.funded:setFillColor(unpack(GC.DARK_GRAY))
      row.funded.anchorX = 1
      row.funded.x, row.funded.y = groupContentWidth - PADDING_RIGHT, yOffset
   end

   if (quoteAmount) then
      row.quote = display.newText( {text=SceneManager.getRosettaString(quoteLabel)..": "..utils.getCurrencySymbol()..tostring(utils.formatMoney(quoteAmount)),x=0,y=0
            ,font=GC.APP_FONT,fontSize = 14,align="center"} )
      row.quote:setFillColor(unpack(GC.DARK_GRAY))
      row:insert(row.quote)
      row.quote.anchorX = 1
      row.quote.x, row.quote.y = groupContentWidth - PADDING_RIGHT, row.quote.height * 0.5 + PADDING_TOP-- groupContentHeight * 0.5
   end
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
      currLoadId = quotes[currListRow].loadIdGuid
   
      if (isEditing) then
         showRemovePrompt()
      elseif (not showingOverlay) then
         -- TODO: This probably should be different. Waiting for response on what Dawn feels the app needs for quote functionality
         local options,ids = getQuoteChoices()
         alert:show({title = SceneManager.getRosettaString("please_select"),
            list = {options = options,radio = false},ids = ids,
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=quoteComplete})
      end
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      row.locations:setFillColor(unpack(textColor))
      row.number:setFillColor(unpack(textColor))
      if (row.quote) then
         row.quote:setFillColor(unpack(textColor))
      end

      if (isCarrier) then
         row.date:setFillColor(unpack(textColor))
         if (row.info) then
            row.date:setFillColor(unpack(textColor))
         end
      else
         row.reserve:setFillColor(unpack(textColor))
         row.funded:setFillColor(unpack(textColor))
      end
   end
end

local function reloadData()
   for i = 1, #list._view._rows do
      if (list._view._rows[i]) then
         local row = list._view._rows[i]._view
         row.delete.isVisible = isEditing
         row.number.x = getRowOffset(i)
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

local function loadIdValid(id)
   for i = 1, #quotes do
      if (quotes[i].loadIdGuid == currLoadId) then
         return true
      end
   end
   
   return false
end

local function populateList()
   if (#quotes > 0) then
      setCount(#quotes)
      lblNoQuotes.isVisible = false
      --btnEdit.isVisible = isCarrier
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
	  GC.LISTWIDGET_HOLDER = list
      -- insert rows into list (tableView widget)
      local colors = {GC.LIGHT_GRAY2,GC.WHITE}


      for i=1,#quotes do
         list:insertRow{
            rowHeight = lvListRowHeight,
            rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
         }
      end
      
      if (forceLoadQuotes and loadIdValid(currLoadId)) then
         forceLoadQuotes = false
         getLoadQuotes()
      end
   else
      lblNoQuotes.isVisible = true
      btnEdit.isVisible = false
      setCount("")
   end
end

local function getQuotesCallback(response)
   hideToast()
   stopTimeout()
   
   if (response == nil or response.quotes == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      quotes = response.quotes
      populateList()
   end

   showMessage()
end

local function getQuotes()
   if (isEditing) then
      toggleEdit()
   end
   if (list) then
      list:removeSelf()
      list = nil
   end
   
   --showToast()
   --startTimeout()
   local quoteType = nil
   if (isCarrier) then
      quoteType = GC.QUOTE_TYPES[filterOption]
   end
   api.getMyQuotes({sid=SceneManager.getUserSID(),type=quoteType,showPD=false,callback=getQuotesCallback})
end

local function handleUpdate()
   if (_G.messageQ) then
      alert:show({
         message = SceneManager.getRosettaString(_G.messageQ),
         buttons={SceneManager.getRosettaString("ok")},
         callback=getQuotes
      })
      _G.messageQ = nil
   end
end

onComplete = getQuotes

local function filterOnComplete1(event,value)
	if GC.GOT_LIST == true and GC.BACKPRESS == true then
		return true
	elseif GC.GOT_LIST == true and GC.BACKPRESS == false then
		if (value ~= filterOption) then
			filterOption = value
			_G.quoteFilterOption = filterOption
			btnFilter:setLabel(SceneManager.getRosettaString(GC.QUOTE_LABELS[filterOption]))
			getQuotes()
		end
   end
end

local function filterOnComplete(event,value)
		if (event and not event.target and value ~= filterOption) then
			filterOption = value
			_G.quoteFilterOption = filterOption
			btnFilter:setLabel(SceneManager.getRosettaString(GC.QUOTE_LABELS[filterOption]))
			getQuotes()
		end
end

local function showFilterOptions()
   alert:show({title = SceneManager.getRosettaString("choose_quote_type"),
      list = {
         options={
            SceneManager.getRosettaString(GC.QUOTE_LABELS[1]),
            SceneManager.getRosettaString(GC.QUOTE_LABELS[2]),
            SceneManager.getRosettaString(GC.QUOTE_LABELS[3]),
            SceneManager.getRosettaString(GC.QUOTE_LABELS[4]),
            SceneManager.getRosettaString(GC.QUOTE_LABELS[5]),
         }, selected = filterOption
      },
      buttons = {SceneManager.getRosettaString("cancel")},cancel = 1,
      callback=filterOnComplete})
end

local function onEventCallback(event)
   if (event.target.id == "back") then
      SceneManager.goToDashboard()
   elseif (event.target.id == "edit") then
      toggleEdit()
   elseif (event.target.id == "filter") then
      showFilterOptions()
   elseif (event.target.id == "refresh") then
      getQuotes()
   end
end

function scene:create( event )
   sceneGroup = self.view

   filterOption = _G.quoteFilterOption or 1

   forceLoadQuotes = false
   showingOverlay = false
   isEditing = false
   isCarrier = SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("my_quotes"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
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

   count = display.newText(sceneGroup,"",0,0,GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   count.x, count. y = display.contentWidth - 25, titleBG.y

   listTop = btnRefresh.stageBounds.yMax + 10
      
   if (isCarrier) then
      btnFilter = widget.newButton{
         id = "filter",
         icon = {default="graphics/dropdown.png",width=16,height=12,align="right",matchTextColor=true},
         labelAlign="left",xOffset = 10,
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 18,
         label=SceneManager.getRosettaString(GC.QUOTE_LABELS[filterOption]),
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 140,
         height = GC.BUTTON_ACTION_HEIGHT,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onEventCallback
      }
      btnFilter.x, btnFilter.y = btnFilter.width * 0.5 + BUTTON_OFFSET, titleBG.stageBounds.yMax + btnFilter.height * 0.5 + 10
      sceneGroup:insert(btnFilter)
      btnRefresh.x, btnRefresh.y = display.contentWidth - btnRefresh.width * 0.5 - BUTTON_OFFSET, titleBG.stageBounds.yMax + btnRefresh.height * 0.5 + 10
   end

   lblNoQuotes = display.newText(sceneGroup, SceneManager.getRosettaString("no_results_found"), 0, 0, GC.APP_FONT, 24)
   lblNoQuotes:setFillColor(unpack(GC.DARK_GRAY))
   lblNoQuotes.isVisible = false
   lblNoQuotes.x, lblNoQuotes.y = display.contentCenterX, display.contentCenterY

   getQuotes()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.sceneExit = SceneManager.goToDashboard
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
      if (not showingOverlay) then
         composer.removeScene("SceneMyQuotes")
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

   if (list) then
      list:removeSelf()
      list = nil
   end

   lblNoQuotes:removeSelf()
   lblNoQuotes = nil

   if (btnFilter) then
      btnFilter:removeSelf()
      btnFilter = nil
   end

   count:removeSelf()
   count = nil
   
   btnRefresh:removeSelf()
   btnRefresh = nil

   btnEdit:removeSelf()
   btnEdit = nil
end

function scene:update()
   handleUpdate()
end

function scene:popLoadQuotes()
   forceLoadQuotes = true
   getQuotes()
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