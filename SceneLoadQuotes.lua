local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local newWidget = require("widget")
local GC = require("AppConstants")
local utils = require("utils")
local alert = require("alertBox")
local api = require("api")
local overlayFundShipment = require("overlayFundShipment")

local PADDING = 5
local BUTTON_HEIGHT = 40
local INFO_BOX_WIDTH = display.contentWidth - PADDING * 2
local INFO_BOX_HEIGHT = display.contentHeight - PADDING * 2

local LIST_VIEW_ROW_HEIGHT = 80

local sceneGroup = nil
local bg = nil
local btnCancel = nil
local btnDelete = nil
local title = nil
local titleBG = nil
local list = nil
local noResults = nil

local loadIdGuid = nil
local amount = nil
local quotes = nil
local quote = nil

local elements
local yOffset
local currElement

local GBTFEEPCT = .1
local NETWORKFEE = .4

local quoteCarrierPay
local quoteFee

local messageQ = nil
local updated = nil
local popScene = nil

local currListRow = nil
local currQuoteId = nil

local function hideNativeElements()
   
end

local function showNativeElements()
  
end

local function onMessageCallback()
   showNativeElements()
end

local function showMessage()
   if (messageQ) then
      hideNativeElements()
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")},
         callback=onMessageCallback
      })
      messageQ = nil
   end
end

local function onCancel()
   composer.hideOverlay("fade",0)
end

local function refreshScene()
   popScene = true
   onCancel()
end

local function onDelete()
end

local function nextElement()
   currElement = #elements + 1
end

local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end
end

local function getQuoteLabelFromStatusId(statusId)
   local label = ""

   for i=1,#GC.QUOTE_DEFINITIONS do
      if (GC.QUOTE_DEFINITIONS[i].status == statusId) then
         label = GC.QUOTE_DEFINITIONS[i].label
         break
      end
   end

   if (label ~= "") then label = SceneManager.getRosettaString(label) end

   return label
end

local function getGBTFee(amount)
   return (amount * GBTFEEPCT + NETWORKFEE)
end

local function getCarrierPay(amount)
   return (amount * (1 - GBTFEEPCT)) - NETWORKFEE
end

local function updateAmounts(value)
   if (value and tonumber(value)) then
      amount = value
      --getElementById("amount"):setLabel(value)
      quoteCarrierPay = getCarrierPay(amount)
      quoteFee = getGBTFee(amount)
   else
      quoteCarrierPay = "0.00"
      quoteFee = "0.00"
   end
   getElementById("gbt_fee"):setLabel(utils.formatNumber(quoteFee))
   getElementById("carrier_pay"):setLabel(utils.formatNumber(quoteCarrierPay))
end

local function amountOnComplete( event,value )
   updateAmounts(value)
end

local function onAmount()
   alert:show({title = SceneManager.getRosettaString("my_quote_amount"),id="amount",
      input = {text=amount,type="number",maxlength=5},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,cancel=1,
      callback=amountOnComplete})
end

local function findLowestQuote()
   local lowest = nil
   for i=1,#quotes do
      if (lowest) then
         if (quotes[i].quoteAmount < lowest) then
            lowest = quotes[i].quoteAmount
         end
      else
         lowest = quotes[i].quoteAmount
      end
   end

   return tonumber(lowest or "0")
end

local function onEventCallback(event)
   if (event.target.id == "amount") then
      onAmount()
   end
end

local function declineQuoteCallback(response)
   messageQ = nil
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      refreshScene()
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function declineQuote(type)
   api.declineQuote({sid=SceneManager.getUserSID(),id=loadIdGuid,quoteId=quotes[currListRow].quoteId,type=type,callback=declineQuoteCallback})
end

local function declineReasonCallback(event,value)
   local i = event.target.id

   if i == 1 then
      declineQuote("price")
   elseif i == 2 then
      declineQuote("profile")
   else
      alert:show({message = SceneManager.getRosettaString("decline_cancelled"),
         buttons={SceneManager.getRosettaString("ok")},buttonHeight=30
      })
   end
end

local function declineCallback(event,value)
   local i = event.target.id
   
   if (i == 1) then
      alert:show({title = SceneManager.getRosettaString("decline_reason_title"),sendCancel=true,
      message = SceneManager.getRosettaString("decline_reason_message"), cancel = 3,
      buttons={SceneManager.getRosettaString("quote_amount"),SceneManager.getRosettaString("profile"),SceneManager.getRosettaString("cancel")},buttonHeight=30,
      callback=declineReasonCallback})
   end
end

local function onDecline()
   alert:show({title = SceneManager.getRosettaString("decline_confirm_title"),
      message = SceneManager.getRosettaString("decline_confirm_message"),buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("yes"),SceneManager.getRosettaString("no")},buttonHeight=30,
      callback=declineCallback})
end

local function counterCallback(response)
   messageQ = nil
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      refreshScene()
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function counterOnComplete( event,value )
   -- TODO: Add fee and pay now
   if (tonumber(value)) then
      api.counterQuote({sid=SceneManager.getUserSID(),loadIdGuid=loadIdGuid,quoteId=quotes[currListRow].quoteId,
         amount=value,callback=counterCallback})
   else
      alert:show({title = SceneManager.getRosettaString("error"),
      message = SceneManager.getRosettaString("invalid_counter_quote"),
         buttons={SceneManager.getRosettaString("ok")},buttonHeight=30
      })
   end
end

local function buildCounterMessage()
   local message = ""

   message = SceneManager.getRosettaString("carriers_quote")..": "..utils.formatMoney(quotes[currListRow].carrierQuote)
   message = message.."\n"..SceneManager.getRosettaString("shipment_funded")..": "..utils.formatMoney(quote.fundedAmount)

   return message
end

local function onCounter()
   alert:show({title = SceneManager.getRosettaString("your_counter_quote"),
      message = buildCounterMessage(),
      input = {text=amount,type="number",maxlength=5},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,cancel=1,
      callback=counterOnComplete})
end

local function buildAcceptMessage()
   local message = SceneManager.getRosettaString("accept_quote_message")

   message = string.gsub(message, "{quoteAmount}", quotes[currListRow].carrierQuote)
   message = string.gsub(message, "{loadIdGuid}", loadIdGuid)

   return message
end

local function handleAPICallback(response)
   local result = false
   messageQ = nil

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      result = true
   else
      messageQ = "invalid_server_response"
   end

   showMessage()

   return result
end

local function acceptCallback(response)
   messageQ = nil

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      refreshScene()
   else
      messageQ = "invalid_server_response"
   end

   showMessage()
end

local function fundCallback(state)
   if (state) then
      _G.currQuoteId = currQuoteId
      _G.command = "accept"
      refreshScene()
   end
end

local function paymentCallback(response)
   if (handleAPICallback(response)) then
      response.loadIdGuid = loadIdGuid
      response.fromCityState = quote.fromCityState
      response.toCityState = quote.toCityState
      response.fundedAmount = quote.fundedAmount
      response.quoteAmount =  quotes[currListRow].carrierQuote
      response.quoteId = quotes[currListRow].quoteId
      response.callback = fundCallback
      overlayFundShipment:new(response)
   end
end

local function acceptOnComplete(event,value)
   local id = event.target.id

   if (id == 2) then
      api.acceptQuote({sid=SceneManager.getUserSID(),id=loadIdGuid,quoteId=quotes[currListRow].quoteId,callback=acceptCallback})
   end
end

local function acceptQuote()
   alert:show({title = SceneManager.getRosettaString("accept_quote"),buttonAlign="horizontal",
      message = buildAcceptMessage(),
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,cancel=1,
      callback=acceptOnComplete})
end

local function outstandingCallback(response)
   messageQ = nil
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      -- Odd bug in that response in string adds a trailing space, so test API uses result instead
      response.response = response.result or response.response
      
      if (response.response == "yes") then
         -- TODO: Get payment options
         api.getPaymentOptions({sid=SceneManager.getUserSID(),callback=paymentCallback})
         -- TODO: show fund load scene
      elseif (response.response == "no") then
         acceptQuote()
      elseif (response.response == "quoteOutdated") then
         -- Force refresh scene, since quote is outdated
         refreshScene()
      else
         messageQ = "invalid_server_response"
      end
   else
      messageQ = "invalid_server_response"
   end
   
   showMessage()
end

local function onAccept()
   api.outstandingCharges({sid=SceneManager.getUserSID(),id=loadIdGuid,quoteId=quotes[currListRow].quoteId,quoteAmount=quotes[currListRow].carrierQuote,callback=outstandingCallback})
end

local function quoteComplete(event,value)
   local id = value

   if (id == "accept") then
      onAccept()
   elseif (id == "counter") then
      onCounter()
   elseif (id == "decline") then
      onDecline()
   end
end

local function getQuoteAmountAndFormat(amount)
   if amount and tostring(amount) ~= "0" and tonumber(amount) then
      return "$"..utils.formatMoney(amount)
   end

   return ""
end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   local rowHeight = (LIST_VIEW_ROW_HEIGHT - PADDING * 4) / 3
   local row1 = rowHeight * 0.5 + PADDING
   local row2 = row1 + rowHeight + PADDING
   local row3 = row2 + rowHeight + PADDING

   row.elements = {}
   local index = 1

   local amount = getQuoteAmountAndFormat(quotes[row.index].carrierQuote)
   
   row.elements[index] = display.newText(row,SceneManager.getRosettaString("carrier_quote")..": "..amount,0,row1,GC.APP_FONT, 14)
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x = row.elements[index].width * 0.5 + PADDING

   index = index + 1

   row.elements[index] = display.newText(row,getQuoteLabelFromStatusId(quotes[row.index].statusId),0,row1,GC.APP_FONT, 14)
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x = groupContentWidth - row.elements[index].width * 0.5 - PADDING

   index = index + 1
   
   amount = getQuoteAmountAndFormat(quotes[row.index].shipperQuote)

   row.elements[index] = display.newText(row,SceneManager.getRosettaString("shipper_quote")..": "..amount,0,row2,GC.APP_FONT, 14)
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x = row.elements[index].width * 0.5 + PADDING

   index = index + 1
   
   row.elements[index] = display.newText(row,SceneManager.getRosettaString("quote_made")..": "..quotes[row.index].date,0,row3,GC.APP_FONT, 14)
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x = row.elements[index].width * 0.5 + PADDING

   index = index + 1
   
   row.elements[index] = display.newText(row,SceneManager.getRosettaString("score")..": "..utils.formatNumber(quotes[row.index].feedbackScore).."%",0,row3,GC.APP_FONT, 14)
   row.elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   row.elements[index].x = groupContentWidth - row.elements[index].width * 0.5 - PADDING
end

local function onRowTouch(event)
   local row = event.target
   local rowSelected = false
   local textColor = nil

   if event.phase == "press" then
      rowSelected = true
      textColor = GC.WHITE
   elseif event.phase == "release" then
      textColor = GC.DARK_GRAY
      currListRow = row.index
      currQuoteId = quotes[currListRow].quoteId

      alert:show({
         title = SceneManager.getRosettaString("please_select"),
            list = {options = {SceneManager.getRosettaString("accept"),SceneManager.getRosettaString("counter"),
            SceneManager.getRosettaString("decline")--[[,SceneManager.getRosettaString("view_carrier_profile"),SceneManager.getRosettaString("view_safety_profile")]]},radio = false},
            ids = {"accept","counter","decline"},--"view_carrier_profile","view_safety_profile"},
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=quoteComplete
      })
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      if (row.elements) then
         for i = 1, #row.elements do
            row.elements[i]:setFillColor(unpack(textColor))
         end
      end
   end
end

local function removeNonNumbers(s)
   if (not tonumber(string.sub(s,string.len(s)))) then
      s = string.sub(s, 1, string.len(s) - 1)
   end

   return s
end

local function inputListener (event)
   if event.phase == "began" then
   elseif event.phase == "ended" then
      native.setKeyboardFocus( nil )
   elseif event.phase == "submitted" then
      native.setKeyboardFocus( nil )
   elseif event.phase == "editing" then
      if (tfAmount.type == "number") then
         tfAmount.text = removeNonNumbers(tfAmount.text)
      end

      if (tfAmount.maxlength and string.len(tfAmount.text) > tfAmount.maxlength) then
         tfAmount.text = string.sub( tfAmount.text, 1, tfAmount.maxlength )
      end
      updateAmounts(tonumber(tfAmount.text))
   end
end

local function touchListener (s,event)
   local result = true
   
   if (event.phase == "ended") then
      native.setKeyboardFocus( nil )
   end
   return result
end

local function onHelp()
   alert:show({message=SceneManager.getRosettaString("manage_quotes_message"),
         buttons={SceneManager.getRosettaString("ok")}})
end

local function findIndexByQuoteId(id)
   for i = 1, #quotes do
      if quotes[i].quoteId == id then
         return i
      end
   end

   return nil
end

local function handleCommand()
   if (_G.command == "accept") then
      if (_G.currQuoteId) then
         local idx = findIndexByQuoteId(_G.currQuoteId)
         if (idx) then
            currQuoteId = _G.currQuoteId
            currListRow = idx
            acceptQuote()
         end
      end
   end
   _G.currQuoteId = nil
   _G.command = nil
end

function scene:create( event )
   sceneGroup = self.view

   updated = false
   popScene = false

   if (event.params and event.params.quote and event.params.quotes) then
      quote = event.params.quote
      quotes = event.params.quotes
   else
      local json = require("json")
      quote = json.decode('{"loadIdGuid":414,"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","reserve":0.00,"fundedAmount":0.00,"lowestQuote":333.73}')
      quotes = json.decode('[{"quoteId":330,"carrierQuote":333.73,"shipperQuote":0,"date":"10-29-2014 16:45","carrierId":1169,"feedbackScore":100,"statusId":24}]')
   end

   loadIdGuid = quote.loadIdGuid -- Assumes for now these are all the same
   
   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(0,0,0,0.5)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY
   bg.isVisible = false

   bg.touch = touchListener
   bg:addEventListener("touch")

   infoBox = display.newRect(sceneGroup,0,0,INFO_BOX_WIDTH,INFO_BOX_HEIGHT)
   infoBox:setFillColor(245/255,245/255,245/255)
   infoBox.x, infoBox.y = display.contentCenterX, display.contentCenterY
   
   titleBG = display.newRect( sceneGroup, 0, 0, infoBox.width, 40 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5 + infoBox.stageBounds.yMin

   title = display.newText(sceneGroup, SceneManager.getRosettaString("manage_quotes_for").." #"..loadIdGuid, 0, 0, GC.SCREEN_TITLE_FONT, 16)
   --title.x, title.y = titleBG.stageBounds.xMin + title.width * 0.5 + PADDING, titleBG.y
   title.x, title.y = display.contentCenterX, titleBG.y

   btnCancel = widget.newButton{
      id = "cancel",
      defaultColor = defaultColor,
      overColor = overColor,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("cancel",1),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER },
      width = 130,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onCancel
   }
   btnCancel.x, btnCancel.y = btnCancel.width * 0.5 + 20, infoBox.stageBounds.yMax - btnCancel.height * 0.5 - PADDING
   btnCancel.x = display.contentCenterX
   sceneGroup:insert(btnCancel)

   btnDelete = widget.newButton{
      id = "delete",
      defaultColor = GC.COLOR_RED,
      overColor = GC.COLOR_DARK_RED,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("delete",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 130,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.COLOR_DARK_RED,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onDelete
   }
   btnDelete.x, btnDelete.y = display.contentWidth - btnDelete.width * 0.5 - 20, btnCancel.y
   btnDelete.isVisible = false
   sceneGroup:insert(btnDelete)

   elements = {}
   local elementWidth = infoBox.width - PADDING * 2
   local minX = infoBox.stageBounds.xMin + PADDING
   yOffset = titleBG.stageBounds.yMax + PADDING

   --nextElement()

   --elements[currElement] = widget.newButton{
   --   defaultColor = GC.WHITE,
   --   overColor = GC.MEDIUM_GRAY,
   --   default="graphics/question.png",
   --   width = 30,
   --   height = 30,
   --   onRelease = onHelp
   --}
   --elements[currElement].x, elements[currElement].y = infoBox.stageBounds.xMax - elements[currElement].width * 0.5 - PADDING, titleBG.y
   --sceneGroup:insert(elements[currElement])

   --nextElement()

   --elements[currElement] = display.newText(SceneManager.getRosettaString("manage_quotes_for").." #"..loadIdGuid,0,0,GC.APP_FONT,16)
   --elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   --elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset
   --sceneGroup:insert(elements[currElement])

   --yOffset = elements[currElement].stageBounds.yMax + PADDING * 1.5
   nextElement()

   elements[currElement] = display.newRect(0,0,elementWidth,100)
   elements[currElement].strokeWidth=1
   elements[currElement]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMin + PADDING * 2
   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("shipment_details_sub"),0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset
   sceneGroup:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(" #"..loadIdGuid,0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.ORANGE))
   elements[currElement].x, elements[currElement].y = 0, yOffset
   sceneGroup:insert(elements[currElement])

   -- Separate text elements need to be properly centered
   local width = elements[currElement-1].width + elements[currElement].width
   elements[currElement-1].anchorX = 0
   elements[currElement].anchorX = 0
   elements[currElement-1].x = display.contentCenterX - (width * 0.5)
   elements[currElement].x = elements[currElement-1].stageBounds.xMax

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 0.5
   nextElement()
   
   elements[currElement] = display.newLine( sceneGroup, 0, 0, elementWidth - PADDING * 2, 0 )
   elements[currElement]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[currElement].strokeWidth = 1
   elements[currElement].x, elements[currElement].y = minX + PADDING, yOffset

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 2
   nextElement()

   elements[currElement] = display.newText(quote.fromCityState.." --> "..quote.toCityState,0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + PADDING + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   --yOffset = elements[currElement].stageBounds.yMax + PADDING * 1.5
   --nextElement()

   --elements[currElement] = display.newText(SceneManager.getRosettaString("to")..": "..quote.toCityState,0,0,GC.APP_FONT,14)
   --elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   --elements[currElement].x, elements[currElement].y = minX + PADDING + elements[currElement].width * 0.5, yOffset
   --sceneGroup:insert(elements[currElement])   

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 1.5
   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("auto_accept")..": $"..utils.formatMoney(quote.reserve),0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + PADDING + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])   

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 1.5
   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("funded_amount")..": $"..utils.formatMoney(quote.fundedAmount),0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + PADDING + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 3
   nextElement()

   elements[currElement] = display.newRect( 0, 0, elementWidth, 1 )
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset
   sceneGroup:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect( 0, 0, elementWidth, 1 )
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, btnDelete.stageBounds.yMin - PADDING
   sceneGroup:insert(elements[currElement])

   list = newWidget.newTableView {
      top = yOffset,
      height = elements[currElement].y - yOffset,
      width = elementWidth,
      hideBackground = true,
      hideScrollBar = false,
      onRowRender = onRowRender,
      onRowTouch = onRowTouch,
      noLines = true,
      isLocked = (#quotes * LIST_VIEW_ROW_HEIGHT) <= elements[currElement].y - yOffset
   }
   sceneGroup:insert(list)
   list.x = display.contentCenterX

   noResults = display.newText(sceneGroup, SceneManager.getRosettaString("no_results_found"), 0, 0, GC.APP_FONT, 24)
   noResults:setFillColor(unpack(GC.DARK_GRAY))
   noResults.isVisible = #quotes == 0
   noResults.x, noResults.y = list.x,list.y
   sceneGroup:insert(noResults)

   local colors = {GC.LIGHT_GRAY2,GC.WHITE}

   for i=1,#quotes do
      list:insertRow{
         rowHeight = LIST_VIEW_ROW_HEIGHT,
         rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
      }
   end
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      bg.isVisible = true
      --overlayFundShipment:new({})
      handleCommand()
      _G.overlay = onCancel
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase
   local parent = event.parent

   if ( phase == "will" ) then
      bg.isVisible = false
      _G.overlay = nil
   elseif ( phase == "did" ) then
      if (updated) then
         parent:update()
      end
      if (popScene and parent) then
         parent:popLoadQuotes()
      end

      composer.removeScene("SceneLoadQuotes")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnDelete:removeSelf()
   btnDelete = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   for i=1,#elements do
      elements[1]:removeSelf()
      table.remove(elements[1])
   end
   elements = nil

   if (list) then
      list:removeSelf()
      list = nil
   end

   noResults:removeSelf()
   noResults = nil
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