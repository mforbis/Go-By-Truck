local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local utils = require("utils")
local status = require("status")

-- NOTE: Left off needing to adjust the y values for certain fields if other is selected
-- Hide other length, and width

local MessageX = display.contentCenterX
local MessageY = 360

local PADDING = 10
local LINE_PADDING = 4
local INFO_BOX_WIDTH = display.contentWidth - PADDING * 2
local INFO_BOX_HEIGHT = 360
local SHADOW_SHIFT_AMOUNT = 2
local BUTTON_HEIGHT = 35

local FONT_SIZE = 14

local FORM_VALID = 0
local FORM_MISSING_FIELD = "form_missing_required"
local FORM_INVALID_VALUE = "form_invalid_value"

local sceneGroup = nil

local overlay = nil
local btnCancel = nil
local btnSubmit = nil
local title = nil
local titleBG = nil

local details = nil

local elements = nil

local missingField = nil

local updated

local creditCard = nil
local amount = nil
local cvv = nil

local invalidField = nil

local messageQ = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function validate()
   if (creditCard == nil or amount == "" or cvv == "") then
      return FORM_MISSING_FIELD
   end

   if (not tonumber(amount)) then
      invalidField = "amount"
      return FORM_INVALID_VALUE
   end

   if (not tonumber(cvv)) then
      invalidField = "cvv"
      return FORM_INVALID_VALUE
   end

   return FORM_VALID
end


local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end
end

local function getElementIndexById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return i
      end
   end
end

local function alertOnComplete( event,value )
   local i = event.target.id
   -- TODO
   if (event.id == "creditCard") then
      -- Grab id to set creditCard to
   elseif (event.id == "amount") then
      amount = value
      getElementById("amount"):setLabel(amount)
   elseif (event.id == "cvv") then
      cvv = value
      getElementById("cvv"):setLabel(cvv)
   end
end

local function onCancel()
   composer.hideOverlay()
end

local function apiCallback(response)
   --print ("response: "..tostring(response.status))

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      _G.messageQ = actionString.."_successful"
      updated = true
      composer.hideOverlay()
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function onSubmit()
   local result = validate()
   if (result == FORM_VALID) then
      -- TODO: Add API Request
      --api.addEditTrailer({sid=SceneManager.getUserSID(),trailer=details,callback=apiCallback})
   else
      local errorMsg = SceneManager.getRosettaString(result)
      if (result == FORM_INVALID_VALUE) then
         errorMsg = errorMsg..":\n"..SceneManager.getRosettaString(invalidField)
      end

      alert:show({title = SceneManager.getRosettaString("error"),
         message = errorMsg,
            buttons={SceneManager.getRosettaString("ok")},buttonHeight=30,
            callback=alertOnComplete})
   end
end

local function onCreditCard()
   -- TODO: Add Selections from data received
   alert:show({title = SceneManager.getRosettaString("select_credit_card"),id="creditCard",
      buttons={SceneManager.getRosettaString("cancel")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onAmount()
   alert:show({title = SceneManager.getRosettaString("amount"),id="amount",
      input = {text=amount,type="number"},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onCVV()
   alert:show({title = SceneManager.getRosettaString("cvv"),id="cvv",
      input = {text=cvv,type="number",maxlength=4},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onEventCallback(event)
   if (event.target.id == "cancel") then
      onCancel()
   elseif (event.target.id == "submit") then
      onSubmit()
   elseif (event.target.id == "creditCard") then
      onCreditCard()
   elseif (event.target.id == "amount") then
      onAmount()
   elseif (event.target.id == "cvv") then
      onCVV()
   end
end

function scene:create( event )
   sceneGroup = self.view

   updated = false
   creditCard = 1
   amount = "143.00"
   cvv = "314"

   overlay = display.newRect(sceneGroup,0,0,display.contentWidth,display.contentHeight)
   overlay:setFillColor(0,0,0,0.5)
   overlay.x, overlay.y = display.contentCenterX,display.contentCenterY

   infoShadow = display.newRect( sceneGroup, 0,0, INFO_BOX_WIDTH + SHADOW_SHIFT_AMOUNT, INFO_BOX_HEIGHT + SHADOW_SHIFT_AMOUNT )
   infoShadow:setFillColor(unpack(GC.MEDIUM_GRAY))
   
   infoBox = display.newRect(sceneGroup,0,0,INFO_BOX_WIDTH,INFO_BOX_HEIGHT)
   infoBox:setFillColor(1,1,1)
   infoBox.x, infoBox.y = display.contentCenterX, display.contentCenterY
   infoShadow.x, infoShadow.y = infoBox.x + SHADOW_SHIFT_AMOUNT, infoBox.y + SHADOW_SHIFT_AMOUNT

   titleBG = display.newRect( sceneGroup, 0, 0, infoBox.width, 30 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5 + infoBox.stageBounds.yMin

   title = display.newText(sceneGroup, SceneManager.getRosettaString("add_funds"), 0, 0, GC.SCREEN_TITLE_FONT, 18)
   title.x, title.y = titleBG.x, titleBG.y
   
   elements = {}
   local elementWidth = infoBox.width - PADDING * 2

   elements[2] = display.newText(sceneGroup,"  = "..SceneManager.getRosettaString("required"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[2]:setFillColor(unpack(GC.DARK_GRAY))
   elements[2].anchorX = 1
   elements[2].x, elements[2].y = infoBox.stageBounds.xMax - PADDING, elements[2].height * 0.5 + titleBG.stageBounds.yMax

   elements[1] = display.newText(sceneGroup,"*",0,0,GC.APP_FONT,FONT_SIZE)
   elements[1]:setFillColor(unpack(GC.RED))
   elements[1].x, elements[1].y = elements[2].stageBounds.xMin, elements[2].y

   elements[3] = display.newText(sceneGroup,"* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[3]:setFillColor(unpack(GC.RED))
   elements[3].x, elements[3].y = elements[3].width * 0.5 + PADDING + infoBox.stageBounds.xMin, elements[1].y

   elements[4] = display.newText(sceneGroup,SceneManager.getRosettaString("select_credit_card"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[4]:setFillColor(unpack(GC.DARK_GRAY))
   elements[4].anchorX = 0
   elements[4].x, elements[4].y = elements[3].stageBounds.xMax, elements[3].y

   local buttonLabelXOffset = 10
   local amountWidth = 200

   elements[5] = widget.newButton{
      id = "creditCard",x = 0,y = 0,labelAlign="left",xOffset = buttonLabelXOffset,
      icon = {default="graphics/selector.png",width=11,height=20,align="right",matchTextColor=true},
      width = elementWidth,height = BUTTON_HEIGHT,
      label = SceneManager.getRosettaString("please_select_a_credit_card"),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }, size = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[5].x, elements[5].y = display.contentCenterX, elements[4].stageBounds.yMax + BUTTON_HEIGHT * 0.5 + LINE_PADDING * 0.5
   sceneGroup:insert(elements[5])

   elements[6] = display.newText(sceneGroup,"* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[6]:setFillColor(unpack(GC.RED))
   elements[6].x, elements[6].y = elements[3].x, elements[6].height * 0.5 + elements[5].stageBounds.yMax + LINE_PADDING

   elements[7] = display.newText(sceneGroup,SceneManager.getRosettaString("amount"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[7]:setFillColor(unpack(GC.DARK_GRAY))
   elements[7].anchorX = 0
   elements[7].x, elements[7].y = elements[6].stageBounds.xMax, elements[6].y

   elements[8] = widget.newButton{
      id = "amount",x = 0,y = 0,labelAlign="left",xOffset = buttonLabelXOffset,
      label = amount,
      width = amountWidth,height = BUTTON_HEIGHT,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }, size = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[8].x, elements[8].y = elements[5].stageBounds.xMin + elements[8].width * 0.5 - buttonLabelXOffset * 0.5, elements[7].stageBounds.yMax + BUTTON_HEIGHT * 0.5 + LINE_PADDING * 0.5
   sceneGroup:insert(elements[8])
   
   elements[9] = widget.newButton{
      id = "cvv",x = 0,y = 0,labelAlign="left",xOffset = buttonLabelXOffset,
      label = cvv,
      width = elementWidth - amountWidth - PADDING,height = BUTTON_HEIGHT,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }, size = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onEventCallback
   }
   elements[9].x, elements[9].y = elements[5].stageBounds.xMax - elements[9].width * 0.5 - buttonLabelXOffset * 0.5, elements[8].y
   sceneGroup:insert(elements[9])

   elements[10] = display.newText(sceneGroup,"* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[10]:setFillColor(unpack(GC.RED))
   elements[10].x, elements[10].y = elements[9].stageBounds.xMin + elements[10].width * 0.5, elements[6].y

   elements[11] = display.newText(sceneGroup,SceneManager.getRosettaString("cvv"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[11]:setFillColor(unpack(GC.DARK_GRAY))
   elements[11].anchorX = 0
   elements[11].x, elements[11].y = elements[10].stageBounds.xMax, elements[10].y

   
   
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
      onRelease = onEventCallback
   }
   btnCancel.x, btnCancel.y = btnCancel.width * 0.5 + 20, infoBox.stageBounds.yMax - btnCancel.height * 0.5 - 10
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
      onRelease = onEventCallback
   }
   btnSubmit.x, btnSubmit.y = display.contentWidth - btnSubmit.width * 0.5 - 20, btnCancel.y
   sceneGroup:insert(btnSubmit)

end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = onCancel
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase
   local parent = event.parent

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneAddFundsCC")
      if (updated) then
         parent:update()
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   infoBox:removeSelf()
   infoBox = nil

   infoShadow:removeSelf()
   infoShadow = nil

   for i=1,#elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil
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