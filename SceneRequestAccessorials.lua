local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local toggle = require("toggle")
local api = require("api")

local PADDING = 10
local SPACE = 5
local FONT_SIZE = 16
local OVER_COLOR = {0.75,0.75,0.75}
local CHECK_SIZE = 30
local HELP_SIZE = 25
local BUTTON_HEIGHT = 40
local BUTTON_XOFFSET = 5

local gbtPercent = .1 -- Should be returned from server
local flatFee = 0 -- Might change in the future

local errAddress = "One or more of your selected accessorials requires an address"
local errOption = "Select Appropriate Option"
local errMisrepDesc = "Please enter a reason for misrepresentation"
local errOtherName = "Please enter a name for other accessorial"
local errNoOptions = "One or more accessorials are required"

local sceneGroup = nil
local bg = nil
local title = nil
local titleBG = nil
local btnCancel = nil
local btnSubmit = nil
local scrollView = nil
local divider = nil
local divider2 = nil

local elements = nil
local index = nil

local loadIdGuid = nil
local addresses = nil

local accElementWidth = nil
local accX = nil

local carrierPaid
local gbtFee
local accessorialTotal

local numAccessorials

local misrepresentedDescription

local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end

   return nil
end

local function showMessage()
   if (messageQ) then
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function errorCallback(event,value)
   local element = nil

   if (event.id) then
      element = getElementById(event.id)
   end

   if (element) then
      scrollView:scrollToPosition({y=-(element.y - element.height * 0.5 - PADDING + 1),time=200})
   end
end

local function handleError(id,message)
   alert:show({
      title = SceneManager.getRosettaString("error"),id=id,
      message = message,
      buttons={SceneManager.getRosettaString("ok")},
      callback=errorCallback
   })
end

local function findAccessorialById(id)
   for i = 1, #GC.ACCESSORIALS do
      if (GC.ACCESSORIALS[i].id == id) then
         return i
      end
   end

   return nil
end

local function updateReasonState()
   local index = findAccessorialById("misrepresented_shipment")

   if (index) then
      if (getElementById("checkbox_"..index).state) then
         getElementById("misrepresentedDescription"):enable()
      else
         misrepresentedDescription = ""
         getElementById("misrepresentedDescription"):disable()
      end
   end
end

local function updateOtherState()
   local index = findAccessorialById("other")

   if (index) then
      if (getElementById("checkbox_"..index).state) then
         getElementById("otherName"):enable()
      else
         getElementById("otherName"):disable()
         getElementById("otherName"):setLabel("")
      end
   end
end

local function nextElement()
   index = #elements + 1
end

local function onCancel()
   composer.hideOverlay("zoomOutInFade",200)
end

local function requestAccessorialsCallback(response)
   messageQ = nil
   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      -- TODO: handle successful request
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function getValue(id)
   local value = 0

   if (getElementById(id)) then
      return tonumber(getElementById(id):getLabel()) or 0
   end

   return value
end

local function validate()
   local addressGuid = getElementById("address").addressGuid

   if (getElementById("address").addressGuid == 0) then
      handleError("lblAaddress",errAddress)
      return false
   end

   local checked = 0

   for i = 1, #GC.ACCESSORIALS do
      if (getElementById("checkbox_"..i).state) then
         checked = checked + 1
         if (getValue("pay_"..i) == 0) then
            handleError("checkbox_"..i,errOption)
            return false
         elseif (GC.ACCESSORIALS[i].id == "misrepresented_shipment" and misrepresentedDescription == "") then
            handleError("misrepresentedDescription",errMisrepDesc)
            return false
         elseif (GC.ACCESSORIALS[i].id == "other" and getElementById("otherName"):getLabel() == "") then
            handleError("lblOtherName",errOtherName)
            return false
         end
      end
   end

   if (checked == 0) then
      handleError("checkbox_1",errNoOptions)
      return false
   end

   return true
end

local function onSubmit()
   -- Let's just build out a table for the API to use
   local form = {}

   if (validate()) then
      form.sid = SceneManager.getUserSID()
      form.loadIdGuid = loadIdGuid
      form.carrierPaid = carrierPaid
      form.gbtFee = gbtFee
      form.accessorialTotal = accessorialTotal

      for i = 1, #GC.ACCESSORIALS do
         local label = GC.ACCESSORIALS[i].qLabel or GC.ACCESSORIALS[i].id
         form[label.."_pay"] = getValue("pay_"..i)
         form[label.."_fee"] = getValue("fee_"..i)
         form[label.."_amt"] = getValue("amt_"..i)
         form[label] = tostring(getElementById("checkbox_"..i).state)
      end

      form.otherName = getElementById("otherName"):getLabel()

      form.misrepresentedDescription = misrepresentedDescription

      form.addressGuid = getElementById("address").addressGuid or 0

      api.requestAccessorials({form=form,callback=requestAccessorialsCallback})
   end
end

local function addTextElement(text,x,y,isAbsolute,color)
   nextElement()
   elements[index] = display.newText(text,0,0,GC.APP_FONT,FONT_SIZE)
   elements[index]:setFillColor(unpack(color or GC.DARK_GRAY))
   
   local x = elements[index].width * 0.5 + x
   local y = elements[index].height * 0.5 + y
   if (isAbsolute == true) then
      x = x
      y = y
   end

   elements[index].x, elements[index].y = x,y
   scrollView:insert(elements[index])
end

local function onToggle(self)
   local eid = tonumber(utils.split(self.id,"_")[2])
   
   if (GC.ACCESSORIALS[eid].id == "misrepresented_shipment") then
      updateReasonState()
   end

   if (GC.ACCESSORIALS[eid].id == "other") then
      updateOtherState()
   end
end

local function addToggle(params)
   nextElement()
   elements[index] = toggle.new({id=params.id, x = 0, y = 0,on = "graphics/check_on.png", onWidth = CHECK_SIZE, onHeight = CHECK_SIZE,
      off = "graphics/check_off.png", offWidth = CHECK_SIZE, offHeight = CHECK_SIZE,
      state = params.state or false, callback = params.callback or onToggle})
   elements[index].x, elements[index].y = params.x + CHECK_SIZE * 0.5, params.y + CHECK_SIZE * 0.5
   scrollView:insert(elements[index])
end

local function onHelp(event)
   if (event.phase == "release") then
      if (event.target.text) then
         alert:show({message=event.target.text,width=display.contentWidth - PADDING * 2,
            buttons={SceneManager.getRosettaString("ok")}})
      end
   elseif (event.phase == "moved") then
      local dy = math.abs(( event.y - event.yStart ))
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus(event)
      end
   end
end

local function updateTotals()
   carrierPaid = 0
   gbtFee = 0
   accessorialTotal = 0

   for i = 1, #GC.ACCESSORIALS do
      carrierPaid = carrierPaid + getValue("pay_"..i)
      gbtFee = gbtFee + getValue("fee_"..i)
      accessorialTotal = accessorialTotal + getValue("amt_"..i)
   end
   --print (carrierPaid,gbtFee,accessorialTotal)

   getElementById("carrierPaid"):setLabel(utils.formatMoney(carrierPaid))
   getElementById("gbtFee"):setLabel(utils.formatMoney(gbtFee))
   getElementById("accessorialTotal"):setLabel(utils.formatMoney(accessorialTotal))
end

local function calculateFee(value)
   if (tonumber(value)) then
      return (value / ((1 - gbtPercent) * 10))
   end

   return 0
end

local function calculateAmount(value)
   if (tonumber(value)) then
      return (value / (1 - gbtPercent))
   end

   return 0
end

local function getFeeAmount(value)
   return utils.formatMoney(calculateFee(value)), utils.formatMoney(calculateAmount(value))
end

local function updateInput(id,value)
   local eid = utils.split(id,"_")[2]
   local state = false
   local newValue = ""
   local fee,amount = "",""

   if (eid) then
      if (value ~= "") then
         if (tonumber(value) == nil) then
            value = 0
         else
            fee,amount = getFeeAmount(value)
         end

         state = true

         newValue = utils.formatMoney(value)
      end

      getElementById("checkbox_"..eid).setState(state)
      getElementById(id):setLabel(newValue)

      getElementById("fee_"..eid):setLabel(fee)
      getElementById("amt_"..eid):setLabel(amount)
      
      updateTotals()

      if (GC.ACCESSORIALS[tonumber(eid)].id == "misrepresented_shipment") then
         updateReasonState()
      end

      if (GC.ACCESSORIALS[tonumber(eid)].id == "other") then
         updateOtherState()
      end
   else
      getElementById(id):setLabel(value)
   end
end

local function inputOnComplete(event,value)
   local i = event.target.id
   
   if (i == 2) then
      if (event.id) then
         updateInput(event.id,value)
      end
   end
end

local function showInput(event)
   if (event.phase == "release") then
      if (event.target.id) then
         alert:show({title = event.target.title,id=event.target.id,sendCancel = true,
            input = {text=event.target:getLabel(),type=event.target.type,maxlength=event.target.maxLength},buttonAlign="horizontal",
            buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,cancel=1,
            callback=inputOnComplete})
      end
   elseif (event.phase == "moved") then
      local dy = math.abs( ( event.y - event.yStart ) )
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus( event )
      end
   end
end

local function addInput(params)
   nextElement()
   elements[index] = widget.newButton{
      id = params.id,x = 0,y = 0,labelAlign=params.labelAlign or "left",xOffset = BUTTON_XOFFSET,
      width = params.width,height = params.height or BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      --label=params.label,
      --icon = icon,
      hint = {text=params.hint,color = GC.MEDIUM_GRAY},
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = showInput
   }
   
   if (params.disabled == true) then
      elements[index]:disable()
   end

   elements[index].x, elements[index].y = params.x + elements[index].width * 0.5 - BUTTON_XOFFSET * 0.5, params.y + elements[index].height * 0.5
   elements[index].maxLength = params.maxLength or 10
   elements[index].value = params.value
   elements[index]:setLabel(params.value)
   elements[index].type = "text"
   elements[index].title = SceneManager.getRosettaString("please_enter")

   if (params.useScene == true) then
      sceneGroup:insert(elements[index])
   else
      scrollView:insert(elements[index])
   end
end

local function addHelp(params)
   nextElement()

   elements[index] = widget.newButton{
      id = params.id,
      defaultColor = GC.DARK_GRAY,
      overColor = GC.ORANGE,
      default="graphics/question.png",
      width = HELP_SIZE,
      height = HELP_SIZE,
      onEvent = onHelp
   }
   elements[index].text = params.text
   elements[index].x, elements[index].y = params.x + HELP_SIZE * 0.5 + PADDING, params.y
   scrollView:insert(elements[index])
end

local function addAccessorial(id,x,y,accessorial)
   local xOffset = x
   local y = y
   addToggle({id="checkbox_"..id,x=x,y=y})

   xOffset = elements[index].stageBounds.xMax
   y = elements[index].y

   addHelp({id=i,text=accessorial.help,x=xOffset,y=y})

   nextElement()
   elements[index] = display.newText(accessorial.label,0,0,GC.APP_FONT,FONT_SIZE)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].anchorX = 0
   elements[index].x, elements[index].y = elements[index-1].stageBounds.xMax + PADDING,y
   scrollView:insert(elements[index])

   y = elements[index].y + elements[index].height * 0.5 + PADDING

   if (accessorial.label2) then
      nextElement()
      elements[index] = display.newText(accessorial.label2,0,0,GC.APP_FONT,FONT_SIZE)
      elements[index]:setFillColor(unpack(GC.DARK_GRAY))
      elements[index].anchorX = 0
      elements[index].x, elements[index].y = elements[index-1].x,y
      scrollView:insert(elements[index])

      y = elements[index].y + elements[index].height * 0.5 + PADDING
   end

   addInput({id="pay_"..id,value="",width=accElementWidth,maxLength=10,type="text",x=accX[1],y=y})

   addInput({id="fee_"..id,value="",width=accElementWidth,maxLength=10,type="text",x=accX[2],y=y,disabled=true})

   addInput({id="amt_"..id,value="",width=accElementWidth,maxLength=10,type="text",x=accX[3],y=y,disabled=true})
   
   -- Misrepresented freight needs input for reason (max: 250)
   if (accessorial.id == "misrepresented_shipment") then
      y = elements[index].y + elements[index].height * 0.5 + PADDING

      nextElement()
      elements[index] = widget.newButton{
         id = "misrepresentedDescription",
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 18,
         label="Reason for Request",
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 150,
         height = 35,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onReason
      }
      elements[index].x, elements[index].y = scrollView.x,y + elements[index].height * 0.5
      scrollView:insert(elements[index])
      updateReasonState()
   end
end

local function scrollListener(event)
   --local x, y = scrollView:getContentPosition()
   --print (y)
   if (event.phase == nil) then
      -- snapping back
      
   end
end

local function addressCallback(event,value)
   local element = getElementById("address")

   element.row = value
   element.addressGuid = addresses[value].id or addresses[value].addressGuid
   element:setLabel(addresses[value].label)
end

local function getAddressLabels()
   local labels = {}

   for i = 1, #addresses do
      table.insert(labels,addresses[i].label)
   end

   return labels
end

local function onAddress()
   alert:show({title=SceneManager.getRosettaString("please_select"),width=display.contentWidth - PADDING * 2,
      list = {options = getAddressLabels(),selected = getElementById("address").row or 1,fontSize=14},
      buttons={SceneManager.getRosettaString("cancel")},cancel = 1,
      callback=addressCallback
   })
end

local function onEventCallback(event)
   if (event.phase == "release") then
      if (event.target.id == "address") then
         onAddress()
      end
   elseif (event.phase == "moved") then
      local dy = math.abs( ( event.y - event.yStart ) )
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus( event )
      end
   end
end

function scene:create( event )
   sceneGroup = self.view

   carrierPaid = 0
   gbtFee = 0
   accessorialTotal = 0
   misrepresentedDescription = ""

   elements = {}

   addresses = {}

   if (event.params) then
      loadIdGuid = event.params.loadIdGuid
      addresses = event.params.addresses
   else
      loadIdGuid = 89
      addresses = {
         {addressGuid=116,label="314 w walnut SPRINGFIELD, MO 65807"},
         {addressGuid=117,label="314 w walnut AUSTIN, TX 78710"}
      }  
   end

   --if (addresses == nil or #addresses == 0) then
   --   addresses = {
   --      {addressGuid=116,label="314 w walnut SPRINGFIELD, MO 65807"},
   --      {addressGuid=117,label="314 w walnut AUSTIN, TX 78710"}
   --   } 
   --end

   table.insert(addresses,1,{id=0,label=SceneManager.getRosettaString("select_associated_address")})
   table.insert(addresses,{id=-1,label=SceneManager.getRosettaString("does_not_apply")})

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(245/255,245/255,245/255)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, 35 )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("request_accessorials_title")..loadIdGuid, 0, 0, GC.SCREEN_TITLE_FONT, FONT_SIZE)
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
   btnCancel.x, btnCancel.y = display.contentCenterX - btnCancel.width * 0.5 - PADDING, display.contentHeight - btnCancel.height * 0.5 - PADDING
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
   btnSubmit.x, btnSubmit.y = display.contentCenterX + btnSubmit.width * 0.5 + PADDING, btnCancel.y
   sceneGroup:insert(btnSubmit)

   local infoCellWidth = (display.contentWidth - PADDING * 4) / 3
   local yOffset = titleBG.stageBounds.yMax + PADDING

   accX = {}
   accX[1] = PADDING
   accX[2] = accX[1] + infoCellWidth + PADDING
   accX[3] = accX[2] + infoCellWidth + PADDING

   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("carrier_pay"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[1] + infoCellWidth * 0.5,yOffset
   sceneGroup:insert(elements[index])

   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("gbt_fee"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[2] + infoCellWidth * 0.5,yOffset
   sceneGroup:insert(elements[index])
   
   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("amount"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[3] + infoCellWidth * 0.5,yOffset
   sceneGroup:insert(elements[index])

   yOffset = elements[index].stageBounds.yMax + PADDING * 0.5
   addInput({id="carrierPaid",value="0.00",width=infoCellWidth,maxLength=10,type="text",x=accX[1],y=yOffset,disabled=true,useScene=true})

   addInput({id="gbtFee",value="0.00",width=infoCellWidth,maxLength=10,type="text",x=accX[2],y=yOffset,disabled=true,useScene=true})
   addInput({id="accessorialTotal",value="0.00",width=infoCellWidth,maxLength=10,type="text",x=accX[3],y=yOffset,disabled=true,useScene=true})

   divider = display.newRect(0,0,display.contentWidth,1)
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnCancel.stageBounds.yMin - PADDING
   sceneGroup:insert(divider)

   divider2 = display.newRect(0,0,display.contentWidth,1)
   divider2:setFillColor(unpack(GC.DARK_GRAY))
   divider2.x, divider2.y = display.contentCenterX, elements[index].stageBounds.yMax + PADDING - 1
   sceneGroup:insert(divider2)

   scrollView = widgetNew.newScrollView
   {
      left     = 0,
      top      = 0,
      width    = display.contentWidth,
      height   = divider.stageBounds.yMin - divider2.stageBounds.yMax,
      listener = scrollListener,
      hideBackground = true,
      bottomPadding  = 20,
      horizontalScrollDisabled   = true
   }
   scrollView.anchorY = 0
   scrollView.x, scrollView.y = display.contentCenterX, divider2.stageBounds.yMax + 1
   sceneGroup:insert(scrollView)

   local elementWidth = scrollView.width - PADDING * 2
   local minX = PADDING
   yOffset = 0

   addTextElement("*",minX,yOffset,nil,{1,0,0})

   nextElement()
   elements[index] = display.newText({
      text=SceneManager.getRosettaString("request_accessorials_address"),
      x = display.contentCenterX, y = yOffset + 27,
      width = elementWidth,
      height = 54,
      font = GC.APP_FONT, fontSize = 14,
      align="left",
      })
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].id = "lblAaddress"
   scrollView:insert(elements[index])

   yOffset = elements[index].y + elements[index].height * 0.5
   nextElement()
   
   elements[index] = widget.newButton{
      id = "address",x = 0,y = 0,labelAlign="left",xOffset = 5,
      width = elementWidth,height = BUTTON_HEIGHT, overColor = OVER_COLOR,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = addresses[1].label,labelWidth=elementWidth - 25,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback   
   }
   elements[index].x, elements[index].y = display.contentCenterX, yOffset + elements[index].height * 0.5 + PADDING
   elements[index].row = 1
   elements[index].addressGuid = 0
   scrollView:insert(elements[index])

   yOffset = elements[index].y + elements[index].height * 0.5

   addTextElement(SceneManager.getRosettaString("accessorials",1),minX,yOffset)

   yOffset = elements[index].y + elements[index].height * 0.5

   local accY = yOffset

   nextElement()
   elements[index] = display.newRoundedRect(0,0,elementWidth,400,5)
   elements[index].x, elements[index]. y = display.contentCenterX, yOffset + elements[index].height * 0.5 + PADDING
   elements[index].id = "acc_frame"
   elements[index].strokeWidth = 1
   elements[index]:setStrokeColor(unpack(GC.DARK_GRAY))
   scrollView:insert(elements[index])

   accElementWidth = ((elementWidth) - PADDING * 4) / 3
   local accMinX = elements[index].stageBounds.xMin + PADDING

   accX[1] = accMinX
   accX[2] = accX[1] + accElementWidth + PADDING
   accX[3] = accX[2] + accElementWidth + PADDING

   yOffset = yOffset + PADDING

   addTextElement(SceneManager.getRosettaString("accessorial",1),accMinX,yOffset)

   yOffset = elements[index].y + elements[index].height * 0.5 + PADDING

   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("carrier_pay"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[1] + accElementWidth * 0.5,yOffset
   scrollView:insert(elements[index])

   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("gbt_fee"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[2] + accElementWidth * 0.5,yOffset
   scrollView:insert(elements[index])
   
   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("amount"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = accX[3] + accElementWidth * 0.5,yOffset
   scrollView:insert(elements[index])
   
   yOffset = elements[index].y + elements[index].height * 0.5 + PADDING
   
   for i = 1, #GC.ACCESSORIALS do
      addAccessorial(i,accMinX,yOffset,GC.ACCESSORIALS[i])
      yOffset = elements[index].y + elements[index].height * 0.5 + PADDING
   end

   yOffset = elements[index].y + elements[index].height * 0.5 + PADDING * 2

   nextElement()
   elements[index] = display.newText(SceneManager.getRosettaString("other_accessorial_name"), 0, 0, GC.SCREEN_TITLE_FONT, 14)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].anchorX = 0
   elements[index].x, elements[index].y = accX[1],yOffset
   elements[index].id = "lblOtherName"
   scrollView:insert(elements[index])

   yOffset = elements[index].y + elements[index].height * 0.5 + PADDING

   addInput({id="otherName",value="",width=accElementWidth * 3 + PADDING * 2,maxLength=20,type="text",x=accX[1],y=yOffset})
   updateOtherState()

   local newHeight = (elements[index].y + elements[index].height * 0.5 + PADDING) - accY
   getElementById("acc_frame").height = newHeight
   getElementById("acc_frame").y = newHeight * 0.5 + accY + PADDING
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

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneRequestAccessorials")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   divider:removeSelf()
   divider = nil

   divider2:removeSelf()
   divider2 = nil

   for i = 1, #elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil

   scrollView:removeSelf()
   scrollView = nil
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