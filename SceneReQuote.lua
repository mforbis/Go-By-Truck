local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local newWidget = require("widget")
local GC = require("AppConstants")
local utils = require("utils")
local alert = require("alertBox")
local api = require("api")

local PADDING = 5
local BUTTON_HEIGHT = 40
local INFO_BOX_WIDTH = display.contentWidth - PADDING * 2
local INFO_BOX_HEIGHT = display.contentHeight - PADDING * 2

local sceneGroup = nil
local bg = nil
local btnCancel = nil
local btnSubmit = nil
local title = nil
local titleBG = nil
local list = nil
local noResults = nil
local tfAmount = nil

local loadIdGuid = nil
local lowestQuote = nil
local amount = nil
local quotes = nil

local elements
local yOffset
local currElement

local GBTFEEPCT = .1
local NETWORKFEE = .4

local quoteCarrierPay
local quoteFee

local offX

local messageQ = nil
local updated = nil

local function hideNativeElements()
   tfAmount.isVisible = false
end

local function showNativeElements()
   tfAmount.isVisible = true
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
   composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,GC.SCENE_TRANSITION_TIME_MS)
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

local function reQuoteCallback(response)
   messageQ = nil
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      _G.messageQ = "quote_sent"
      updated = true
      composer.hideOverlay("fade",100)
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function reQuote()
   --api.submitQuote({sid=SceneManager.getUserSID(),id=loadIdGuid,type="newQuote",amount=amount,callback=reQuoteCallback})
end

local function onSubmit()
   -- TODO: Do some checking, and the and API call
   if (amount and tonumber(amount)) then
      reQuote()
   else
      messageQ = "invalid_quote"
      showMessage()
   end
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

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   if (row.isCategory) then
      row.column1 = display.newText(row,SceneManager.getRosettaString("quote_amount",1),offX[1],groupContentHeight*0.5,GC.APP_FONT, 10)
      row.column1.anchorX = 0

      row.column2 = display.newText(row,SceneManager.getRosettaString("gbt_fee",1),offX[2],groupContentHeight*0.5,GC.APP_FONT, 10)
      row.column2.anchorX = 0

      row.column3 = display.newText(row,SceneManager.getRosettaString("carrier_pay",1),offX[3],groupContentHeight*0.5,GC.APP_FONT, 10)
      row.column3.anchorX = 0

      row.column4 = display.newText(row,SceneManager.getRosettaString("quote_status",1),offX[4],groupContentHeight*0.5,GC.APP_FONT, 10)
      row.column4.anchorX = 0
   else
      row.quoteAmount = display.newText(row,"$"..utils.formatNumber(quotes[row.index].quoteAmount),offX[1],groupContentHeight*0.5,GC.APP_FONT, 12)
      row.quoteAmount:setFillColor(unpack(GC.DARK_GRAY))
      row.quoteAmount.anchorX = 0

      row.gbtFee = display.newText(row,"$"..utils.formatNumber(getGBTFee(quotes[row.index].quoteAmount)),offX[2],groupContentHeight*0.5,GC.APP_FONT, 12)
      row.gbtFee:setFillColor(unpack(GC.DARK_GRAY))
      row.gbtFee.anchorX = 0

      row.carrierPay = display.newText(row,"$"..utils.formatNumber(getCarrierPay(quotes[row.index].quoteAmount)),offX[3],groupContentHeight*0.5,GC.APP_FONT, 12)
      row.carrierPay:setFillColor(unpack(GC.DARK_GRAY))
      row.carrierPay.anchorX = 0

      row.status = display.newText(row,getQuoteLabelFromStatusId(quotes[row.index].statusId),offX[4],groupContentHeight*0.5,GC.APP_FONT, 12)
      row.status:setFillColor(unpack(GC.DARK_GRAY))
      row.status.anchorX = 0
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

function scene:create( event )
   sceneGroup = self.view

   updated = false

   if (event.params and event.params.quotes) then
      quotes = event.params.quotes
   else
      local json = require("json")
      quotes = json.decode('[{"loadIdGuid":318,"quoteId":290,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1455.00,"modifiedDate":"Apr 14, 2014 7:52:28 AM","statusId":24},{"loadIdGuid":318,"quoteId":289,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1400.00,"modifiedDate":"Apr 14, 2014 7:51:17 AM","statusId":24},{"loadIdGuid":318,"quoteId":288,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1500.00,"modifiedDate":"Apr 14, 2014 7:51:01 AM","statusId":24}]')
   end

   loadIdGuid = quotes[1].loadIdGuid -- Assumes for now these are all the same
   lowestQuote = findLowestQuote()

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(0,0,0,0.5)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY
   bg.isVisible = false

   bg.touch = touchListener
   bg:addEventListener("touch")

   infoBox = display.newRect(sceneGroup,0,0,INFO_BOX_WIDTH,INFO_BOX_HEIGHT)
   infoBox:setFillColor(245/255,245/255,245/255)
   infoBox.x, infoBox.y = display.contentCenterX, display.contentCenterY
   
   titleBG = display.newRect( sceneGroup, 0, 0, infoBox.width, 30 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5 + infoBox.stageBounds.yMin

   title = display.newText(sceneGroup, SceneManager.getRosettaString("re-quote"), 0, 0, GC.SCREEN_TITLE_FONT, 18)
   title.x, title.y = titleBG.x, titleBG.y

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
   sceneGroup:insert(btnCancel)

   btnSubmit = widget.newButton{
      id = "submit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("submit",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 130,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onSubmit
   }
   btnSubmit.x, btnSubmit.y = display.contentWidth - btnSubmit.width * 0.5 - 20, btnCancel.y
   sceneGroup:insert(btnSubmit)

   elements = {}
   local elementWidth = infoBox.width - PADDING * 2
   local minX = infoBox.stageBounds.xMin + PADDING
   yOffset = titleBG.stageBounds.yMax + PADDING * 3

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("create_new_quote").." #"..loadIdGuid,0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 1.5
   nextElement()

   elements[currElement] = display.newRect(0,0,elementWidth,110)
   elements[currElement].strokeWidth=1
   elements[currElement]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMin + PADDING * 3
   local sectionY = elements[currElement].stageBounds.yMax + PADDING * 2
   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("current_lowest_quote").." ",0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + PADDING * 2 + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText("$"..utils.formatMoney(lowestQuote),0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.LIGHT_GREEN))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMax + PADDING * 3
   nextElement()

   local inputWidth = (elementWidth - PADDING * 8) / 3
   local x1 = minX + PADDING * 2 + inputWidth * 0.5
   local x2 = x1 + inputWidth + PADDING * 2
   local x3 = x2 + inputWidth + PADDING * 2

   elements[currElement] = display.newText(SceneManager.getRosettaString("your_new_quote"),0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = x1, yOffset
   sceneGroup:insert(elements[currElement])

   elements[currElement] = display.newText(SceneManager.getRosettaString("gbt_fee"),0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = x2, yOffset
   sceneGroup:insert(elements[currElement])   

   elements[currElement] = display.newText(SceneManager.getRosettaString("carrier_pay"),0,0,GC.APP_FONT,14)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = x3, yOffset
   sceneGroup:insert(elements[currElement])   

   yOffset = elements[currElement].stageBounds.yMax + PADDING + BUTTON_HEIGHT * 0.5
   nextElement()

   elements[currElement] = display.newRoundedRect(0,0,inputWidth,BUTTON_HEIGHT,GC.BUTTON_ACTION_RADIUS_SIZE)
   elements[currElement].strokeWidth=1
   elements[currElement]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = x1, yOffset
   sceneGroup:insert(elements[currElement])

--[[
   elements[currElement] = widget.newButton{
      id = "amount",x = 0,y = 0,labelAlign="left",xOffset = 4,
      width = inputWidth,height = BUTTON_HEIGHT,
      label = "",fontSize=12,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = x1, yOffset
   sceneGroup:insert(elements[currElement])
]]--

   tfAmount = native.newTextField(0, 0, inputWidth - 2, BUTTON_HEIGHT - 2)
   tfAmount.type = "number"
   tfAmount.inputType = "number"
   tfAmount.maxlength = 5
   tfAmount:addEventListener("userInput", inputListener)
   tfAmount.text = ""
   tfAmount.x, tfAmount.y = x1, yOffset
   sceneGroup:insert(tfAmount)
   
   nextElement()

   elements[currElement] = widget.newButton{
      id = "gbt_fee",x = 0,y = 0,labelAlign="left",xOffset = 4,
      width = inputWidth,height = BUTTON_HEIGHT,
      label = "0.00",fontSize=12,
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = x2, yOffset
   elements[currElement]:disable()
   sceneGroup:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "carrier_pay",x = 0,y = 0,labelAlign="left",xOffset = 4,
      width = inputWidth,height = BUTTON_HEIGHT,
      label = "0.00",fontSize=12,
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = x3, yOffset
   elements[currElement]:disable()
   sceneGroup:insert(elements[currElement])

   yOffset = sectionY + PADDING
   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("previous_quotes_by_company"),0,0,GC.APP_FONT,16)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset
   sceneGroup:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMax + PADDING
   nextElement()

   elements[currElement] = display.newRect( 0, 0, elementWidth, 1 )
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset
   sceneGroup:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect( 0, 0, elementWidth, 1 )
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, btnSubmit.stageBounds.yMin - PADDING
   sceneGroup:insert(elements[currElement])

   offX = {}
   local cellWidth = (elementWidth - PADDING * 2) / 4

   offX[1] = PADDING
   offX[2] = offX[1] + cellWidth
   offX[3] = offX[2] + cellWidth
   offX[4] = offX[3] + cellWidth

   list = newWidget.newTableView {
      top = yOffset,
      height = elements[currElement].y - yOffset,
      width = elementWidth,
      hideBackground = true,
      hideScrollBar = false,
      onRowRender = onRowRender,
      onRowTouch = onRowTouch,
      noLines = true,
      isLocked = (#quotes * 30) <= elements[currElement].y - yOffset
   }
   sceneGroup:insert(list)
   list.x = display.contentCenterX

   noResults = display.newText(sceneGroup, SceneManager.getRosettaString("no_results_found"), 0, 0, GC.APP_FONT, 24)
   noResults:setFillColor(unpack(GC.DARK_GRAY))
   noResults.isVisible = #quotes == 0
   noResults.x, noResults.y = list.x,list.y
   sceneGroup:insert(noResults)

   local colors = {GC.LIGHT_GRAY2,GC.WHITE}

   -- Add Header
   table.insert( quotes, 1,{})
   local rowColor

   for i=1,#quotes do
      if (i == 1) then
         rowColor = {default=GC.DARK_GRAY,over=GC.DARK_GRAY}
      else
         rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
      end
      list:insertRow{
         rowHeight = 30,
         rowColor = rowColor,
         isCategory = (i == 1)
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
      _G.overlay = onCancel
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase
   local parent = event.parent

   if ( phase == "will" ) then
      bg.isVisible = false

      tfAmount:removeSelf()
      tfAmount = nil
      _G.overlay = nil
   elseif ( phase == "did" ) then
      if (updated) then
         parent:update()
      end
      composer.removeScene("SceneReQuote")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

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