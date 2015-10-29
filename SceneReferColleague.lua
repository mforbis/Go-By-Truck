local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local toggle = require("toggle")
local alert = require("alertBox")
local utils = require("utils")

local PADDING_OUTER = 10
local PADDING_KEY = 25
local LINE_PADDING = 5
local CHAR_SPACING = 5
local BUTTON_HEIGHT = 40

local FORM_VALID = 0
local FORM_MISSING_NAME = "missing_name"
local FORM_MISSING_EMAIL = "missing_email"
local FORM_INVALID_EMAIL = "invalid_email"

local MessageX, MessageY = display.contentCenterX, display.contentHeight - 110

local sceneGroup = nil
local overlay = nil
local bg = nil
local title = nil
local scrollView = nil

local btnSubmit, btnClose = nil, nil

local elements = nil

local yOffset = nil

local messageQ = nil

local RED = {1,0,0}

local STATUS_VALUES = {10,48,20}

local customerName
local customerEmail
local emailCount
local emails
local customerType

local currType

local CUSTOMER_TYPES = {"shipper","carrier","three_pl"}
local hasFocus

--[[
Form:
customerName
customerEmail
emailCount (set to # of valid email addresses)
customerType (shipper,carrier,three_pl)

Get the emails and split by space, comma, semicolon, colon, and new line??

]]--

function string:split( inSplitPattern, outResults )
   if not outResults then
    outResults = { }
   end

   if (self and self ~= "") then
      local theStart = 1
      local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
      
      while theSplitStart do
         table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
         theStart = theSplitEnd + 1
         theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
      end
      table.insert( outResults, string.sub( self, theStart ) )
   end

   return outResults
end

local function serializeTable(self, char, out)
   out = ""

   local i

   for i = 1, #self do
      out = out..self[i]..char
   end
   out = string.sub(out, 1, string.len(out) - 1)

   return out
end

local function strLeft(str, char)
  local strNew = nil
  local start,_ = string.find(str, char)
  
  if (start ~= nil) then
    strNew = string.sub(str,1, start - 1)
  end
  
  return strNew
end

local function strRight(str, char)
  local strNew = nil
  local start,_ = string.find(str, char)
  
  if (start ~= nil) then
    strNew = string.sub(str,start + 1)
  end
  
  return strNew
end

-- Returns whether str is a valid email address
-- traps for @, and '..' usage
-- not 100%, but gets us close enough
local function isEmail(email)
   return email:match("[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?")
end

local function isEmailOld(str)
   local _,nAt = str:gsub('@','@') -- Counts the number of '@' symbol
   if nAt > 1 or nAt == 0 or str:len() > 254 or str:find('%s') then return false end
   local localPart = strLeft(str,'@') -- Returns the substring before '@' symbol
   local domainPart = strRight(str,'@') -- Returns the substring after '@' symbol
   if localPart == nil or domainPart == nil then return false end

   if not localPart:match("[%w!#%$%%&'%*%+%-/=%?^_`{|}~]+") or (localPart:len() > 64) then return false end
   if localPart:match('^%.+') or localPart:match('%.+$') or localPart:find('%.%.+') then return false end

   if not domainPart:match('[%w%-_]+%.%a%a+$') or domainPart:len() > 253 then return false end
   local fDomain = strLeft(domainPart,'%.') --_.strLeftBack(domainPart,'%.') -- Returns the substring in the domain-part before the last (dot) character
   if fDomain:match('^[_%-%.]+') or fDomain:match('[_%-%.]+$') or fDomain:find('%.%.+') then return false end

   return true
end

local function trimString( s )
   return string.match( s,"^()%s*$") and "" or string.match(s,"^%s*(.*%S)" )
end

-- The form is supposed to have a new email on a different line
local function formatEmail(emails)
   local formatted = ""

   if (type(emails) == "table" and #emails > 0) then
      for i = 1, #emails do
         formatted = formatted..emails[i]..","
      end
   end

   if (formatted ~= "") then
      formatted = string.sub( formatted, 1, string.len(formatted) - 1 )
   end

   return formatted
end

local function fixEmail(email)
   local fixed = string.lower(email)
   --Test@moonbeam.co:another@world.com;laugh@funny.com cry@funny.com, laugh@funny.com

   --print ("'"..email.."'")
   
   -- Clip extra spaces at the begginning
   fixed = trimString(email)
   
   -- Fix extra spaces between, but still allow one since that is another way to separate
   while (string.find(fixed,"  ")) do
      fixed = string.gsub(fixed, "  ", " ")
   end

   --print ("'"..fixed.."'")
   
   fixed = string.gsub( fixed, " ", ",")
   fixed = string.gsub( fixed, ";", ",")
   fixed = string.gsub( fixed, ":", ",")
   fixed = string.gsub( fixed, "\n", ",")
   fixed = string.gsub( fixed, ",,", ",")

   return fixed
end

local function getUniqueEmails(email)
   local uniqueEmails = {}
   
   -- loop through string put unique ones into table return table

   local Emails = email:split(",")
   
   -- Remove duplicates
   for i = 1, #Emails do
      local add = true
      for j = 1, #uniqueEmails do
         if uniqueEmails[j] == Emails[i] then
            add = false
         end
      end
      if (add) then
         table.insert( uniqueEmails, Emails[i] )
      end
   end

   return uniqueEmails
end

local function hideNativeElements()
   for i=1, #elements do
      if (elements[i].native) then
         --elements[i].isVisible = false
         elements[i].isEditable = false
      end
   end
end

local function showNativeElements()
   for i=1, #elements do
      if (elements[i].native) then
         --elements[i].isVisible = true
         elements[i].isEditable = true
      end
   end
end

local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end
end

local function updateAddressLabel()
   local text = ""

   if (emailCount > 0 ) then
      --text = SceneManager.getRosettaString("unique_emails")..": "..emailCount
   end
   
   getElementById("emailAddressCount").text = emailCount
end

local function updateType(type)
   currType = type
   customerType = CUSTOMER_TYPES[currType]
   
   getElementById("customerType"):setLabel(SceneManager.getRosettaString(CUSTOMER_TYPES[currType]))
end

local function countValidEmails(t)
   local count = 0

   for i=1,#t do
      if (isEmail(t[i])) then
         count = count + 1
      end
   end

   return count
end

local function updateEmail(email)
   -- Clean it up to make it easier to manage
   email = fixEmail(email)

   -- remove any duplicates
   emails = getUniqueEmails(email)

   emailCount = countValidEmails(emails)

   -- Put the new values back, but put each on a new line for visual clarity
   getElementById("customerEmail").text = formatEmail(emails)

   --print ("email: "..tostring(email))

   -- Prepare the emails for API usage
   customerEmail = serializeTable(emails,",")
   
   updateAddressLabel()

   --getElementById("customerEmail"):setLabel(customerEmail)
   --getElementById("customerEmail").text = customerEmail

   if (emailCount > 1) then
      --getElementById("customerName"):disable()
      --getElementById("customerName"):setLabel("")
      -- No longer disables name
      --getElementById("customerName").text = ""
   else
      --getElementById("customerName"):enable()
   end
end

local function updateName(name)
   customerName = trimString(name)
   --getElementById("customerName"):setLabel(customerName)
   getElementById("customerName").text = customerName
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function onAlertComplete()
   print ("here")
   getElementById("customerEmail").isVisible = true
   showNativeElements()
end

local function showMessage()
   if (messageQ) then
      --showStatus(messageQ)

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="ReferColleague",reason="Invalid JSON"})
      end

      hideNativeElements()
      --getElementById("customerEmail").isVisible = false
      alert:show({
         title = SceneManager.getRosettaString("error"),sendCancel = true,
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")},callback=onAlertComplete
      })
      messageQ = nil
   end
end

local function onClose()
   composer.hideOverlay()
end

local function alertOnComplete( event,value )
	if GC.GOT_LIST == true then
		return true
	else
		showNativeElements()
		getElementById("customerEmail").isVisible = true
		local i
		if event.target.id then
			i = event.target.id
		end
		
		if (event.id == "customerType") then
			updateType(i)
		elseif (event.id == "customerEmail") then
			updateEmail(value)
		elseif (event.id == "customerName") then
			updateName(value)
		end
	end
end

local function onCustomerName()
   hideNativeElements()
   alert:show({title = SceneManager.getRosettaString("colleague_full_name"),id="customerName",
      input = {text=customerName},buttonAlign="horizontal",sendCancel = true,
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      cancel = 1,callback=alertOnComplete})
end

local function onCustomerEmail()
   hideNativeElements()
   alert:show({title = SceneManager.getRosettaString("colleague_email"),id="customerEmail",
      input = {text=customerEmail,type="email"},buttonAlign="horizontal",sendCancel = true,
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      cancel=1,callback=alertOnComplete})
end

local function onCustomerType()
   hideNativeElements()
   getElementById("customerEmail").isVisible = false
   alert:show({title = SceneManager.getRosettaString("who_referring"),id="customerType",
      buttons={SceneManager.getRosettaString(CUSTOMER_TYPES[1]),SceneManager.getRosettaString(CUSTOMER_TYPES[2]),
      SceneManager.getRosettaString(CUSTOMER_TYPES[3]),
      SceneManager.getRosettaString("cancel")},buttonHeight=30, cancel = 4,sendCancel = true,
      callback=alertOnComplete})
end

local function apiCallback(response)
   showNativeElements()
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      _G.messageQ = "referral_sent"
      onClose()
   else
      messageQ = "could_not_send_referral"
   end

   showMessage()
end

local function referColleague()
   hideNativeElements()
   if customerName == "" then
		print(" caught a blank colleague name here. Pre-filling before calling api.referColleague()")
		customerName = "Dear Colleague"
	end
	print(" emailCount = "..emailCount)
   api.referColleague({sid=SceneManager.getUserSID(),customerName=customerName,customerEmail=customerEmail,emailCount=emailCount,customerType=customerType,callback=apiCallback})
end

local function hasValidEmail()
   if (emails == nil or #emails == 0) then
      return false
   end

   for i = 1, #emails do
      if (not isEmail(emails[i])) then
         return false
      end
   end

   return true
end

local function validateForm()
	--[[
   if (customerName == "" and emailCount < 2) then
		-- checking here for populated name
      return FORM_MISSING_NAME
	  --return FORM_VALID
   end
	]]
   if (emailCount == 0) then
      return FORM_MISSING_EMAIL
   end
   if (emailCount == 1 and customerName == "") then
      return FORM_MISSING_NAME 
   end

   if (not hasValidEmail()) then
      return FORM_INVALID_EMAIL
   end
   if (customerName == "") then
		-- checking here for populated name
      --return FORM_MISSING_NAME
	  return FORM_VALID
   end
   return FORM_VALID
end

local function snapScrollBack()
   if (scrollView.oldPos) then
      scrollView:scrollToPosition{y = scrollView.oldPos,time = 200}
      scrollView.oldPos = nil
   end
end

local function onEventCallback(event)
   if (event.phase == "release") then
      snapScrollBack()
      if (event.target.id == "submit") then
         local validate = validateForm()

         if (validate == FORM_VALID) then
            referColleague()
         else
            --getElementById("customerEmail").isVisible = false
            alert:show({
               title = SceneManager.getRosettaString("error"),
               message = SceneManager.getRosettaString(validate),
               buttons={SceneManager.getRosettaString("ok")},sendCancel = true,
               callback=alertOnComplete
            })
         end
      elseif (event.target.id == "close") then
         onClose()
      elseif (event.target.id == "customerType") then
         onCustomerType()
      elseif (event.target.id == "customerName") then
         onCustomerName()
      elseif (event.target.id == "customerEmail") then
         onCustomerEmail()
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

local function updateValues(id)
   if (id == "customerEmail") then
      updateEmail(getElementById("customerEmail").text)
   elseif (id == "customerName") then
      updateName(getElementById("customerName").text)
   end
end

local function inputListener( event )
   if event.phase == "began" then
      if (hasFocus == nil) then
         hasFocus = event.target
      end

      local x, y = scrollView:getContentPosition()

      --print ("pos: x="..x..",y:"..y)
      -- Before showing keyboard, lets scroll the list up to not cover it up.
      if (y >= 0 and display.contentHeight <= 480) then
         scrollView.oldPos = y
         scrollView:scrollToPosition{y = -50,time = 200}
      end
   elseif event.phase == "ended" or event.phase == "submitted" then
      if (hasFocus and hasFocus.id == event.target.id) then
         --native.setKeyboardFocus( nil )
         hasFocus = nil
      end
      updateValues(event.target.id)
   elseif event.phase == "editing" then
      local text = tostring(event.target.text)

      if (string.sub(text,string.len(text)) == "\n") then
         if (event.target.id == "customerEmail") then
            updateEmail(event.target.text)
         elseif (event.target.id == "customerName") then
            --print (string.sub(text,string.len(text)))
            hasFocus = nil
            text = string.sub(text,1,string.len(text)-1)
            native.setKeyboardFocus( nil )
            updateName(text)
         end
      end
   end

   --hasFocus = event.target
end

local function updateNativeScrollElements()
   if (getElementById("customerEmail").stageBounds.yMax > scrollView.stageBounds.yMax) or
      (getElementById("customerEmail").stageBounds.yMin <= scrollView.stageBounds.yMin) then
      getElementById("customerEmail").isVisible = false
   else
      getElementById("customerEmail").isVisible = true
   end
end

local function scrollListener(event)
   if (event.phase == nil) then
      -- snapping back
      --getElementById("customerEmail").isVisible = true
   else
      if (event.phase == "moved") then
         local x, y = scrollView:getContentPosition()

         --print ("pos: x="..x..",y:"..y)
         --print ("y: "..y..", element y: "..getElementById("customerEmail").stageBounds.yMax)

      elseif (event.phase == "began") then
         hasFocus = nil
         native.setKeyboardFocus( nil )
         -- Let's scroll the list back to its original position if
         -- we scrolled it up to show the keyboard.
         snapScrollBack()
      end
         --updateNativeScrollElements()
   end
end

function scene:create( event )
   sceneGroup = self.view

   customerName = ""
   customerEmail = ""
   emailCount = 0
   customerType = nil
   currType = nil
   hasFocus = nil

   overlay = display.newRect(sceneGroup,0,0,display.contentWidth,display.contentHeight)
   overlay:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   overlay.x, overlay.y = display.contentCenterX,display.contentCenterY

   local contentWidth = display.contentWidth - PADDING_OUTER * 2
   local contentHeight = display.contentHeight - PADDING_OUTER * 3 - BUTTON_HEIGHT
   local buttonWidth = (contentWidth - PADDING_OUTER) * 0.5

   btnClose = widget.newButton{
      id = "close",
      defaultColor = defaultColor,
      overColor = overColor,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("close",1),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER },
      width = buttonWidth,
      height = BUTTON_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = {0.4,0.4,0.4},
      strokeWidth = 1,
      onRelease = onEventCallback
   }
   btnClose.x, btnClose.y = buttonWidth * 0.5 + PADDING_OUTER, display.contentHeight - btnClose.height * 0.5 - 10
   sceneGroup:insert(btnClose)

   btnSubmit = widget.newButton{
      id = "submit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("submit",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = buttonWidth,
      height = BUTTON_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnSubmit.x, btnSubmit.y = display.contentWidth - buttonWidth * 0.5 - PADDING_OUTER, btnClose.y
   sceneGroup:insert(btnSubmit)

   bg = display.newRect(sceneGroup,0,0,contentWidth,contentHeight)
   bg:setFillColor(1,1,1)
   bg.x,bg.y = display.contentCenterX,bg.height * 0.5 + PADDING_OUTER

   local fontSizeLabel = 18

   scrollView = widgetNew.newScrollView
   {
      left = 0,
      top = 0,
      width = contentWidth,
      height = contentHeight,
      bottomPadding = 10,
      id = "onBottom",
      horizontalScrollDisabled = true,
      verticalScrollDisabled = display.contentHeight > 480,
      hideBackground = true,
      listener = scrollListener,
   }
   scrollView.anchorY = 0
   scrollView.x, scrollView.y = display.contentCenterX, bg.stageBounds.yMin
   sceneGroup:insert(scrollView)

   elements = {}

   local minX = PADDING_OUTER
   local elementWidth = bg.width - PADDING_OUTER * 2

   yOffset = 0

   local idx = 1

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("refer_colleague"),width=elementWidth,font=GC.APP_FONT,fontSize=24} )
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height * 0.5

   --elements[1] = display.newText( {text="*",font=GC.APP_FONT,fontSize=16} )
   --elements[1]:setFillColor( unpack(RED) )
   --elements[1].x, elements[1].y = minX + elements[1].width * 0.5, yOffset + elements[1].height * 0.5
   --scrollView:insert(elements[1])

   idx = idx + 1

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("colleague_full_name"),font=GC.APP_FONT,fontSize=fontSizeLabel} )
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height * 0.5 + LINE_PADDING

   --[[   
   idx = idx + 1

   elements[idx] = widget.newButton{
      id = "customerName",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      label = "",
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }, fontSize = 16, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = 1, onEvent = onEventCallback
   }
   elements[idx].x, elements[idx].y = scrollView.width * 0.5, yOffset + BUTTON_HEIGHT * 0.5
   scrollView:insert(elements[idx])
   ]]--

   idx = idx + 1

   elements[idx] = display.newRect( 0, 0, elementWidth, BUTTON_HEIGHT)
   elements[idx].strokeWidth = 1
   elements[idx]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5
   scrollView:insert(elements[idx])
  
   idx = idx + 1

   elements[idx] = native.newTextBox( 0, 0, elementWidth - 4, elements[idx-1].height - 4)
   elements[idx].id="customerName"
   elements[idx].isEditable = true
   elements[idx].native = true
   elements[idx]:addEventListener( "userInput", inputListener )
   elements[idx].font = native.newFont( GC.APP_FONT, 16 )
   elements[idx]:setTextColor( unpack(GC.DARK_GRAY) )
   elements[idx].hasBackground = false
   elements[idx].x, elements[idx].y = scrollView.width * 0.5, (yOffset) + elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height * 0.5

   idx = idx + 1

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("colleague_email"),font=GC.APP_FONT,fontSize=fontSizeLabel} )
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5 + PADDING_OUTER
   scrollView:insert(elements[idx])

   idx = idx + 1

   elements[idx] = display.newText( {text=emailCount,font=GC.APP_FONT,fontSize=fontSizeLabel} )
   elements[idx].id = "emailAddressCount"
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].anchorX = 1
   elements[idx].x, elements[idx].y = scrollView.stageBounds.xMax - PADDING_OUTER * 2, elements[idx-1].y
   scrollView:insert(elements[idx])

   idx = idx + 1

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("colleague_email_directions"),width=elementWidth,font=GC.APP_FONT,fontSize=12} )
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].anchorX,elements[idx].anchorY = 0,0
   elements[idx].x, elements[idx].y = minX, elements[idx-2].y + elements[idx-2].height * 0.5
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height + LINE_PADDING

   idx = idx + 1

   elements[idx] = display.newRect( 0, 0, elementWidth, BUTTON_HEIGHT + 20 )
   elements[idx].strokeWidth = 1
   elements[idx]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5
   scrollView:insert(elements[idx])
  
   idx = idx + 1

   elements[idx] = native.newTextBox( 0, 0, elementWidth - 4, elements[idx-1].height - 8)
   elements[idx].id="customerEmail"
   elements[idx].isEditable = true
   elements[idx].inputType = "email"
   elements[idx].native = true
   elements[idx]:addEventListener( "userInput", inputListener )
   elements[idx].font = native.newFont( GC.APP_FONT, 16 )
   elements[idx]:setTextColor( unpack(GC.DARK_GRAY) )
   elements[idx].hasBackground = false
   
   elements[idx].x, elements[idx].y = scrollView.width * 0.5,  (yOffset) + elements[idx].height * 0.5
   scrollView:insert(elements[idx])
 
   yOffset = elements[idx].y + elements[idx].height * 0.5 + LINE_PADDING

   idx = idx + 1

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("please_choose_category"),font=GC.APP_FONT,fontSize=fontSizeLabel} )
   elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
   elements[idx].x, elements[idx].y = minX + elements[idx].width * 0.5, yOffset + elements[idx].height * 0.5 + PADDING_OUTER
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height * 0.5 + LINE_PADDING

   idx = idx + 1

   elements[idx] = widget.newButton{
      id = "customerType",x = 0,y = 0,labelAlign="left",xOffset = 10,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      width = elementWidth,height = BUTTON_HEIGHT,
      label = "",
      labelColor = { default=GC.DARK_GRAY, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }, fontSize = 16, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = 1, onEvent = onEventCallback
   }
   elements[idx].x, elements[idx].y = scrollView.width * 0.5, yOffset + elements[idx].height * 0.5
   updateType(1)
   scrollView:insert(elements[idx])

   yOffset = elements[idx].y + elements[idx].height * 0.5 + LINE_PADDING * 2

   for i=1,3 do
      idx = idx + 1
      elements[idx] = display.newText( {text=SceneManager.getRosettaString("refer_note"..i),width=elementWidth,font=GC.APP_FONT,fontSize=12} )
      elements[idx]:setFillColor( unpack(GC.DARK_GRAY) )
      elements[idx].anchorX,elements[idx].anchorY = 0,0
      elements[idx].x, elements[idx].y = minX, yOffset
      scrollView:insert(elements[idx])
      yOffset = elements[idx].y + elements[idx].height + LINE_PADDING
   end
   
   local rolePrefix

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER) then
      rolePrefix = "carrier"
   else
      rolePrefix = "shipper"
   end

   --api.referColleague({sid=SceneManager.getUserSID(),customerName="Bob Haskins",customerEmail="bob@test.com,dave@test.com",emailCount=1,customerType="three_pl",callback=apiCallback})
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = onClose
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
      composer.removeScene("SceneReferColleague")
      if (_G.messageQ) then
         parent:showMessage()
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   bg:removeSelf()
   bg = nil

    btnSubmit:removeSelf()
   btnSubmit = nil

   btnClose:removeSelf()
   btnClose = nil

   for i=1,#elements do
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