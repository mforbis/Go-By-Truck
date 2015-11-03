local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local bgServices = require("bgServices")
local db = require("db")
local status = require("status")
local toggle = require("toggle")
local navMenu = require("overlayNavMenu")
local api = require("api")

local sceneGroup = nil
local msgCount = ""

local PADDING = 10

local bg = nil
local header = nil
local logo = nil
local buttons = nil
local referralBG, referral = nil, nil
local locationStatus = nil

local showLocation = nil

local scrollView = nil

local buttonPadding = nil

local sceneTimer

--local MessageX, MessageY = display.contentCenterX, display.contentHeight - 110

local BADGE_SIZE = 28
local BADGE_COLOR = {1,1,1}
local BADGE_LABEL_COLOR = GC.ORANGE

local badgeBG, badge = nil, nil
local badges = nil
local updatingBadges = nil

local PRIMARY_SIZE = 145
local PRIMARY_ICON_SIZE = 50

local messageQ = nil

local tool_options = {
   {role = GC.USER_ROLE_TYPE_CARRIER, options = {"find_freight","gbt_bank","my_shipments","my_quotes","my_trailers"}},  
   {role = GC.USER_ROLE_TYPE_SHIPPER, options = {"post_shipment","locate_shipment","my_shipments","my_quotes","gbt_bank"}},
   {role = GC.USER_ROLE_TYPE_DRIVER, options = {"my_loads","view_location"}}
}

-- Carriers: locate drivers, find freight, gbt bank
-- Shippers: post shipment, locate shipments, gbt bank
-- Drivers: locate (on/off), my loads, view location
local primary_functions = {
   {role = GC.USER_ROLE_TYPE_CARRIER,
      functions = {
         {label = "locate_drivers", icon="locate_drivers.png"},
         {label = "find_freight", icon="find_freight.png"},
         {label = "gbt_bank", icon="dollar.png"}
      }
   },
   {role = GC.USER_ROLE_TYPE_SHIPPER,
      functions = {
         {label = "post_shipment", icon="post_shipment.png"},
         {label = "locate_shipment", icon="locate_shipment.png"},
         {label = "gbt_bank", icon="dollar.png"}
      }
   },
   {role = GC.USER_ROLE_TYPE_DRIVER,
      functions = {
         {label = "send_location", icon="location.png"},
         {label = "my_loads", icon="truck.png"},
         {label = "view_location", icon="view_location.png"}
      }
   }
}

local elements = nil

local menuSelected = nil


local function getElementById(id)
   local index = nil

   if (id and type(elements) == "table") then
      for i = 1, #elements do
         if (elements[i].id == id) then
            return elements[i]
         end
      end
   end

   return nil
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function onPost()
   --SceneManager.goToPostShipment()
   SceneManager.goTo("post_shipment",nil,false,nil)
end

local function updateLocationStatus()
   local label = "off"
   local color = GC.MEDIUM_GRAY
   local overColor = GC.DARK_GRAY
   local borderColor = GC.DARK_GRAY
   
   if (SceneManager.getLocationState()) then
      label = "on"
      color = GC.ORANGE
      overColor = GC.ORANGE_OVER
      borderColor = GC.ORANGE_OVER
      bgServices.startLocationService()
   else
      bgServices.stopLocationService()
   end
   
   primaryButtons[2]:setDefaultColor(color)
   primaryButtons[2]:setOverColor(overColor)
   primaryButtons[2]:setStrokeColor(borderColor)

   primaryButtons[4]:setDefaultColor(color)
   primaryButtons[4]:setOverColor(overColor)
   primaryButtons[4]:setStrokeColor(borderColor)

   label = SceneManager.getRosettaString(label,1)

   if (location) then
      location.text = label
   else
      location = display.newText({text=label,font = GC.APP_FONT,fontSize = 22})
      location:setFillColor(1,1,1)
      location.x, location.y = primaryButtons[2].x,primaryButtons[2].stageBounds.yMin + location.height * 0.5 + 5
      sceneGroup:insert(location)
   end
end

local function toggleLocationState()
   SceneManager.toggleLocationState()
   getElementById("send_location").setState(SceneManager.getLocationState())

   if (SceneManager.getLocationState()) then
      bgServices.startLocationService()
   else
      bgServices.stopLocationService()
   end
end

local function showDriverMap()
   if (_G.currPoint.lat == 0 or _G.currPoint.lon == 0) then
      alert:show({title = SceneManager.getRosettaString("no_location"),
         message = SceneManager.getRosettaString("no_location_message"),
         buttons={SceneManager.getRosettaString("ok")}
      })
   else
      SceneManager.showMap({type=GC.DRIVER_LOCATION,data={name=SceneManager.getUserFullname(),latitude=_G.currPoint.lat,longitude=_G.currPoint.lon}})
   end
end

local function driverLocationOnComplete( event )
   local i = event.target.id
   
   if (i == 2) then
      toggleLocationState()
      if (showLocation) then
         sceneTimer = timer.performWithDelay(150, showDriverMap)
      end
   end
end

local function promptDriverLocation()
   alert:show({title = SceneManager.getRosettaString("cannot_view_location"),buttonAlign="horizontal",
      message = SceneManager.getRosettaString("turn_on_location_question"),
      buttons={SceneManager.getRosettaString("no"),
      SceneManager.getRosettaString("yes")},
      callback=driverLocationOnComplete})
end

local function handleLogout()
   _G.removeTag(SceneManager.getUserSID())
   SceneManager.setUserSID("")
   SceneManager.setSessionId(nil)
   SceneManager.goToLoginScene()
end

local function getRoleIndex(table)
   local userRole = SceneManager.getUserRoleType()

   for i = 1, #table do
      if table[i].role == userRole then
         return i
      end
   end
   return -1
end

local optionOnComplete = nil

local function toolsComplete(event,value)
   optionOnComplete({phase = "release", target = {id = value}})
end

local function showOptions(option_table)
   local index = getRoleIndex(option_table)
   GC.TOOLS_OVERLAY = true
   local buttons = {}
   local options = {}
   local badges = {}

   for i = 1, #option_table[index].options do
      buttons[i] = SceneManager.getRosettaString(option_table[index].options[i])
      options[i] = option_table[index].options[i]
      badges[i] = ""
   end

   local groups = {"Find Freight","My Quotes","Message Center", "Refer GBT","Log Out"}
   
   local userRole = SceneManager.getUserRoleType()
   
   table.insert(buttons,SceneManager.getRosettaString("message_center"))
   table.insert(options,"message_center")
   table.insert(badges,db.getMessageCount(SceneManager.getUserSID()))

   if (userRole ~= GC.USER_ROLE_TYPE_DRIVER) then
      table.insert(buttons,SceneManager.getRosettaString("feedback"))
      table.insert(options,"feedback")
      table.insert(badges,"")
   end

   table.insert(buttons,SceneManager.getRosettaString("refer_gbt"))
   table.insert(options,"refer_gbt")
    table.insert(badges,"")

   if (userRole == GC.USER_ROLE_TYPE_CARRIER) then
      table.insert(buttons,SceneManager.getRosettaString("locate_drivers"))
      table.insert(options,"locate_drivers")
      table.insert(badges,"")
   end

   table.insert(buttons,SceneManager.getRosettaString("log_out"))
   table.insert(options,"log_out")
   table.insert(badges,"")
	
   navMenu:show({
      options = buttons,
      ids = options,
      badges = badges,
      callback=toolsComplete,
      groups = groups
   })
end

optionOnComplete = function( event,value )
   local i = event.target.id
   
   if (event.phase == "release") then
      if (i == "my_trailers") then
         SceneManager.goToMyTrailers()
      elseif (i == "my_quotes") then
         SceneManager.goToMyQuotes()
         --SceneManager.goTo("my_quotes",nil,false,nil)
      elseif (i == "my_shipments") then
         SceneManager.goToMyShipments()
         --SceneManager.goTo("my_shipments",nil,false,nil)
      elseif (i == "feedback") then
         SceneManager.goToMyFeedback()
      elseif (i == "gbt_bank") then
         --SceneManager.goToMyBanking()
         -- Only these masterRoles can access bank. Not sure why client doesn't want to hide button instead
         local canAccess = false

         local role = SceneManager.getUserRole()
   
         if (role == GC.API_ROLE_MASTER_CARRIER_ADMIN or role == GC.API_ROLE_CARRIER_ADMIN or 
            role == GC.API_ROLE_SHIPPER_ADMIN or role == GC.API_ROLE_MASTER_SHIPPER_ADMIN) then
            canAccess = true
         end

         if (canAccess) then
            SceneManager.goTo("gbt_bank",nil,false,nil)
         end
      elseif (i == "post_shipment") then
         onPost()
      elseif (i == "log_out") then
         handleLogout()
      elseif (i == "locate_shipment") then
         SceneManager.goToLocateShipment()
      elseif (i == "message_center") then
         SceneManager.goToMessageCenter()
      elseif (i == "locate_drivers") then
         SceneManager.goToLocateDrivers()
      elseif (i == "my_loads") then
         SceneManager.goToMyShipments()
      elseif (i == "send_location") then
         toggleLocationState()
      elseif (i == "find_freight") then
         --composer.removeScene("SceneFindFreight")
         --SceneManager.goToFindFreight()
         SceneManager.goTo("find_freight",nil,false,nil)
      elseif (i == "refer_colleague" or i == "refer_gbt") then
         SceneManager.showReferGBT()
         elseif (event.target.id == "tools") then
         showOptions(tool_options)
      elseif (event.target.id == "help") then
         SceneManager.goTo("help",nil,true,nil)
      elseif (i == "view_location") then
         showLocation = false
         if (SceneManager.getLocationState()) then
            showDriverMap()
         else
            showLocation = true
            promptDriverLocation()
         end
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

local function userOptionsOnComplete( event )
   local i = event.target.id
   if (i == 1) then
      SceneManager.showReferGBT()
   elseif i == 2 then
      handleLogout()
   end
end

local function showUserOptions()
   local nameRole = nil
   local first = SceneManager.getUserFirstname() or ""
   local last = SceneManager.getUserLastname() or ""
   local role = SceneManager.getUserRoleType() or ""

   if (first ~= "" and last ~= "" and role ~= "") then
      role = string.upper(string.sub(role,1,1))..string.sub(role,2)

      nameRole = first.." "..last.." ("..role..")"
   end

   alert:show({title = SceneManager.getRosettaString("please_select"),
      message = nameRole,
      buttons={
         --SceneManager.getRosettaString("refer_gbt"),
         SceneManager.getRosettaString("log_out"),
         SceneManager.getRosettaString("cancel")
      },cancel=2,
      callback=userOptionsOnComplete})
end

local function getBadgeCount()
   -- TODO: read local database of messages sent to user and return
   -- only new ones as a count
   return db.getMessageCount(SceneManager.getUserSID())
end

local function getBadgeLabel(count)
   if (tonumber(count)) then
      return count
   end

   return ""
end

local messageCounts = {}

local function updateBadge(badge)
   local count
   
   if (badge.id == "messages") then
      count = messageCounts.totalCount
   elseif (badge.id == "quote_activity") then
      count = messageCounts[GC.MESSAGE_TYPE_QUOTE]
   elseif (badge.id == "shipment_activity") then
      count = messageCounts[GC.MESSAGE_TYPE_SHIPMENT]
   elseif (badge.id == "payments" or badge.id == "gbt_bank") then
      count = messageCounts[GC.MESSAGE_TYPE_BANKING]
   end
   
   count = count or 0

   badge.label.text = getBadgeLabel(count)
   
   if (count >= 0 or badge.type ~= nil) then
      badge.label.isVisible = true
      badge.background.isVisible = true
      badge.arrow.isVisible = false
   else
      badge.label.isVisible = false
      badge.background.isVisible = false
      badge.arrow.isVisible = true
   end
end

local function messageOnComplete( event )
   if "clicked" == event.action then
      local i = event.index
        
      if (i == 1) then
         SceneManager.goToMessageCenter()
      else
         _G.push = nil
      end
   end
end

local function notificationsCallback(response)
   messageCounts[GC.MESSAGE_TYPE_ACCESSORIAL] = 0
   messageCounts[GC.MESSAGE_TYPE_FEEDBACK] = 0
   messageCounts[GC.MESSAGE_TYPE_BANKING] = 0
   messageCounts[GC.MESSAGE_TYPE_SHIPMENT] = 0
   messageCounts[GC.MESSAGE_TYPE_QUOTE] = 0
   messageCounts.totalCount = 0

   if (response == nil or response.status == nil) then
      -- Error
   elseif (response.status == "true" and response.notifications) then
      for i = 1, #response.notifications do
         if (tonumber(response.notifications[i].read) == GC.MESSAGE_TYPE_UNREAD) then
            messageCounts.totalCount = messageCounts.totalCount + 1
            if (messageCounts[response.notifications[i].type]) then
               messageCounts[response.notifications[i].type] = messageCounts[response.notifications[i].type] + 1
            end
         end
      end
   end

   if (badges) then
      for i = 1, #badges do
         updateBadge(badges[i])
      end
   end

   updatingBadges = false

   if (_G.push and _G.push.id and _G.push.sid and tonumber(_G.push.sid) == tonumber(SceneManager.getUserSID())) then
   --   local message = db.getMessage(_G.pushId)
   --
   --   if (message) then
   --      native.showAlert("GBT", message.text, { "Message Center", "Dismiss" }, messageOnComplete)
   --   end
   -- NOTE: Above is deprecated stuff from local database. Not ready to rip out yet
      native.showAlert("GBT", _G.push.alert, { "Message Center", "Dismiss" }, messageOnComplete)
   end
end

local function updateBadges()
   if (updatingBadges ~= true) then
      updatingBadges = true
      api.getNotificationsByUser({sid=SceneManager.getUserSID(),callback=notificationsCallback})
   end
end

local function updateMessageBadge()
   local count = getBadgeCount()
   local label = count
   
   --if (count > 9) then
   --   label = "9+"
   --end

   if (count > 0) then
      if (badge) then
         badge.text = label
      else
         badgeBG = display.newCircle( 0, 0, BADGE_SIZE )
         badgeBG.strokeWidth = 2
         badgeBG:setStrokeColor(unpack(GC.ORANGE_OVER))
         badgeBG:setFillColor(unpack(BADGE_COLOR))
         badgeBG.x = primaryButtons[1].stageBounds.xMax - BADGE_SIZE - 4
         badgeBG.y = primaryButtons[1].stageBounds.yMin + BADGE_SIZE + 4
         sceneGroup:insert(badgeBG)

         badge = display.newText( {text=label,font = GC.APP_FONT,fontSize = 18} )
         badge:setFillColor(unpack(BADGE_LABEL_COLOR))
         badge.x, badge.y = badgeBG.x, badgeBG.y
         sceneGroup:insert(badge)
      end
   else
      if (badge) then
         badgeBG:removeSelf()
         badgeBG = nil

         badge:removeSelf()
         badge = nil
      end
   end
end

local function removeBadge(idx)
end

local function removeBadge(idx)
end

local function addBadge(count,id,type,x,y)
   local label = getBadgeLabel(count)
   
   if (badges == nil) then
      badges = {}
   end
   
   local idx = #badges + 1

   badges[idx] = display.newGroup()
   badges[idx].id = id
   
   if (type == "square") then
      badges[idx].background = display.newRect(0,0,BADGE_SIZE,BADGE_SIZE)
   else
      badges[idx].background = display.newImageRect("graphics/circle.png", BADGE_SIZE, BADGE_SIZE)
   end

   badges[idx].type = type

   badges[idx].background.x, badges[idx].background.y = x, y
   badges[idx].background:setFillColor(unpack(GC.ORANGE))
   badges[idx]:insert(badges[idx].background)

   badges[idx].label = display.newText( {text=label,font = GC.APP_FONT,fontSize = 16} )
   badges[idx].label:setFillColor(1,1,1)
   badges[idx].label.x, badges[idx].label.y = x,y
   badges[idx]:insert(badges[idx].label)

   badges[idx].arrow = display.newImageRect("graphics/arrow_right.png", BADGE_SIZE, BADGE_SIZE)
   badges[idx].arrow.x, badges[idx].arrow.y = x, y
   badges[idx].arrow:setFillColor(unpack(GC.MEDIUM_GRAY))
   badges[idx]:insert(badges[idx].arrow)

   scrollView:insert(badges[idx])

   updateBadge(badges[idx])
end

local function onEventCallback(event)
   if (event.target.id == "user") then
      showUserOptions()
   elseif (event.target.id == "tools") then
      showOptions(tool_options)
   elseif (event.target.id == "help") then
      SceneManager.goTo("help",nil,true,nil)
	end
end

local function addHeaderButton(id,icon,position)
   if (buttons == nil) then
      buttons = {}
   end

   local bPadding = GC.DASHBOARD_BAR_BUTTON_PADDING
   local positions = {}
   positions[1] = GC.DASHBOARD_BAR_BUTTON_WIDTH * 0.5 + bPadding
   positions[2] = positions[1] + GC.DASHBOARD_BAR_BUTTON_WIDTH + bPadding
   positions[4] = header.stageBounds.xMax - GC.DASHBOARD_BAR_BUTTON_WIDTH * 0.5 - bPadding
   positions[3] = positions[4] - GC.DASHBOARD_BAR_BUTTON_WIDTH - bPadding
   
   local idx = #buttons + 1

   local x = positions[position]
   
   buttons[idx] = widget.newButton{
      id = id,
      defaultColor = GC.DASHBOARD_BAR_BUTTON_DEFAULT_COLOR,
      overColor = GC.DASHBOARD_BAR_BUTTON_OVER_COLOR,
      labelColor = {default = GC.MEDIUM_GRAY, over = GC.DARK_GRAY},
      icon = {default="graphics/"..icon..".png",width=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,height=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,matchTextColor=true},
      width = GC.DASHBOARD_BAR_BUTTON_WIDTH,
      height = GC.DASHBOARD_BAR_BUTTON_HEIGHT,
      cornerRadius = 0,
      strokeWidth = 0,
      --border = {color={68/255,76/255,85/255},type="right"},
      onRelease = optionOnComplete
   }
   buttons[idx].x, buttons[idx].y = x, header.y

   sceneGroup:insert(buttons[idx])
end

local function addHeaderButtons()
   local position = 1

   addHeaderButton("tools","navicon",1)
   
   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER) then
       addHeaderButton("find_freight","search",2)
   end

   addHeaderButton("help","question",4)
end

local function adjustSectionHeight(id,el,padding)
   local h
   local yAdjust
   local padding = tonumber(padding) or PADDING

   local section = getElementById(id)
   local element = el or (elements[#elements])

   if (section) then
      h = ((element.stageBounds.yMax + padding) - section.stageBounds.yMin)
   
      yAdjust = (h - section.height) * 0.5
      section.height = h
      section.y = section.y + yAdjust
   end
end

local function getNextElement()
   if (elements == nil) then
      elements = {}
   end

   return #elements + 1
end

local function setCurrentScrollPosition(position)
   if (type(position) == "string") then
      local element = getElementById(position)
      if (element) then
         scrollView.lineY = (element.y + element.height * 0.5)
      end
   else
      scrollView.lineY = position or (elements[#elements].y + elements[#elements].height * 0.5)
   end
end

local function getCurrentScrollPosition()
   if (scrollView.lineY == nil) then
      scrollView.lineY = 0
   end

   return scrollView.lineY
end
local linkedinTest
local linkedinSet
local linkedinApp
local BUTTON_SIZE = 40
local SOCIAL_BUTTONS = {"facebook","twitter","linkedin","gplus","youtube","pinterest"}
local SOCIAL_LINKS = {"https://www.facebook.com/groups/gobytruck","https://www.twitter.com/gobytruck",
--"https://www.linkedin.com/company/go-by-truck-inc","https://plus.google.com/u/0/b/109536660629616214465/109536660629616214465/posts",
--"https://www.linkedin.com/company/go-by-truck-inc","https://plus.google.com/u/0/109536660629616214465/posts",
(linkedinApp),"https://plus.google.com/u/0/109536660629616214465/posts",
"https://www.youtube.com/user/GoByTruckInc","https://www.pinterest.com/gobytruck/"}

linkedinTest = display.newImage("android.app.icon://com.linkedin.android")
Log("linkedinTest = "..tostring(linkedinTest))
if linkedinTest then
   --linkedinApp = "linkedin://profile?id=[go-by-truck-inc]"
   linkedinSet = 1
   linkedinTest:removeSelf()
   linkedinTest=nil
elseif linkedinTest == nil then
   --linkedinApp = "https://www.linkedin.com/company/go-by-truck-inc"
   linkedinSet = 2
   Log("linkedinApp = "..tostring(linkedinApp))
end

local function onCompleteNatAlert( event )
   if event.action == "clicked" then
        local i = event.index
        if i == 1 then
			--linkedinApp = "linkedin://profile/go-by-truck-inc"
			linkedinApp = "linkedin://profile/49295122"
			system.openURL(linkedinApp)
        elseif i == 2 then
			linkedinApp = "https://www.linkedin.com/company/go-by-truck-inc"
			system.openURL(linkedinApp)
        end
    end
end

	local function setIdent()
			local alert = native.showAlert( "Go By Truck", "Would you like to open the LinkedIn app, or go to the webpage?", { "App", "Webpage" }, onCompleteNatAlert )
			--local alert = native.showAlert( "Go By Truck", "Would you like to open the LinkedIn app, or go to the webpage?", { "OK", "Learn More" }, onComplete )
	end
	
	--timer.performWithDelay(1000, setIdent, 1)


local function socialCallback(event)
   if (event.phase == "release") then
		print("SOCIAL_LINKS["..event.target.index.."] = "..tostring(SOCIAL_LINKS[event.target.index]))
		--print("SOCIAL_BUTTONS["..event.target.index.."] = "..tostring(SOCIAL_BUTTONS[event.target.index]))
      --if (event.target.index and SOCIAL_LINKS[event.target.index]) then
      if (event.target.index) then
         system.openURL(SOCIAL_LINKS[event.target.index]) 
		 print("SOCIAL_LINKS[event.target.index] = "..tostring(SOCIAL_LINKS[event.target.index]))
		 print("event.target.index = "..event.target.index)
		 if event.target.index == 3 then
		 print("SOCIAL_BUTTONS["..event.target.index.."] = "..tostring(SOCIAL_BUTTONS[event.target.index]))
			if linkedinSet == 1 then
				--linkedinApp = "linkedin://profile?id=[go-by-truck-inc]"
				--system.openURL(linkedinApp)
				setIdent()
			elseif linkedinSet == 2 then
				linkedinApp = "https://www.linkedin.com/company/go-by-truck-inc"
				system.openURL(linkedinApp)
				print("linkedinApp = "..tostring(linkedinApp))
			end
		end
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

local function scaleImageByWidth(sWidth,w,h)
   return sWidth, (h / w) * sWidth
end

local function addSocialContent()
   local idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("drop_line"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = scrollView.stageBounds.xMin + scrollView.width * 0.5, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   local buttonPadding = (scrollView.innerWidth - (#SOCIAL_BUTTONS * BUTTON_SIZE)) / (#SOCIAL_BUTTONS - 1)
   
   local y = getCurrentScrollPosition() + BUTTON_SIZE * 0.5 + PADDING
   local x = PADDING + BUTTON_SIZE * 0.5

   for i = 1, #SOCIAL_BUTTONS do
      idx = getNextElement()

      elements[idx] = widget.newButton{
         id = SOCIAL_BUTTONS[i],
         default = "graphics/"..SOCIAL_BUTTONS[i]..".png",
         defaultColor = GC.MEDIUM_GRAY,
         overColor = GC.DARK_GRAY,
         width = BUTTON_SIZE,
         height = BUTTON_SIZE,
         cornerRadius = 0,
         strokeWidth = 0,
         onEvent = socialCallback
      }
      scrollView:insert(elements[idx])
      elements[idx].index = i
      elements[idx].x, elements[idx].y = x, y

      x = x + BUTTON_SIZE + buttonPadding
   end

   setCurrentScrollPosition()
end

local function addReferralSection()
   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "referral_code"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("referral_code"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getReferralCode() or SceneManager.getRosettaString("not_available"),font = "Oswald", fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = scrollView.maxX - elements[idx].width * 0.5 - PADDING, elements[idx-1].y
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "refer_colleague",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 22,
      icon = {default="graphics/person.png",width=30,height=30,matchTextColor=true,align="right"},
      label=SceneManager.getRosettaString("refer_colleague"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = scrollView.innerWidth,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   adjustSectionHeight("referral_code",nil,0)

   setCurrentScrollPosition("referral_code")
end

local function addShipperContent()
   local idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "your_alerts"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("your_alerts"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "feedback",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,xOffset = -8,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 16,
      icon = {default="graphics/arrow_up.png",width=14,height=14,matchTextColor=true,align="right"},
      label=SceneManager.getRosettaString("feedback"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 110,
      height = 32,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.maxX - elements[idx].width * 0.5 - PADDING, elements[idx-1].y
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,1)
   elements[idx].id = "alert_divider"
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   local dividerY = elements[idx].y

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "my_quotes",
      default = "graphics/chart.png",
      defaultColor = GC.DARK_GRAY,
      font = GC.APP_FONT,
      overColor = GC.DARK_GRAY3,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("quote_activity"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize, getCurrentScrollPosition() + elements[idx].height * 0.5

   addBadge(0,"quote_activity",nil,scrollView.midX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "my_shipments",
      default = "graphics/truck.png",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.DARK_GRAY3,
      font = GC.APP_FONT,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("shipment_activity"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMax - scrollView.quarterSize, elements[idx-1].y

   addBadge(0,"shipment_activity",nil,scrollView.maxX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,1)
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   local dividerY = elements[idx].y

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "message_center",
      default = "graphics/mail.png",
      defaultColor = GC.DARK_GRAY,
      font = GC.APP_FONT,
      overColor = GC.DARK_GRAY3,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("messages"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize, getCurrentScrollPosition() + elements[idx].height * 0.5

   addBadge(0,"messages",nil,scrollView.midX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "gbt_bank",
      default = "graphics/bank.png",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.DARK_GRAY3,
      font = GC.APP_FONT,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("my_banking"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMax - scrollView.quarterSize, elements[idx-1].y

   addBadge(0,"gbt_bank",nil,scrollView.maxX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   adjustSectionHeight("your_alerts")

   setCurrentScrollPosition("your_alerts")

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,1,getCurrentScrollPosition() - getElementById("alert_divider").y)
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() - elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "post_shipment",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 22,
      label=SceneManager.getRosettaString("post_shipment"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = scrollView.innerWidth,
      height = 50,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "location"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("locate_shipment"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   local w,h = scaleImageByWidth(scrollView.innerWidth,300,118)

   elements[idx] = widget.newButton{
      id = "locate_shipment",
      default = "graphics/location_map.png",
      overColor = GC.MEDIUM_GRAY,--yOffset = -h * 0.5 - PADDING,
      font = GC.BUTTON_FONT,
      fontSize = 22,
      --label=SceneManager.getRosettaString("locate_shipment"),
      --labelColor = { default=GC.DARK_GRAY, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = w,
      height = h,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   adjustSectionHeight("location",nil,0)

   setCurrentScrollPosition("location")
end

local function addCarrierContent()
   local idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "your_alerts"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("your_alerts"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   local buttonSmallSize = 32

	--[[
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "message_center",
      default = "graphics/1x1.png",xOffset = 15,
      overColor = {1,1,1},
      font = GC.BUTTON_FONT,
      fontSize = 20,
      --icon = {default="graphics/arrow_up.png",width=20,height=20,color=GC.ORANGE,align="right"},
      label=SceneManager.getRosettaString("messages"),
      labelColor = { default=GC.DARK_GRAY, over=GC.DARK_GRAY },
      width = 130,
      height = buttonSmallSize,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.minX + elements[idx].width * 0.5 + PADDING, elements[idx-1].y
   scrollView:insert(elements[idx])

   addBadge(0,"messages","square",scrollView.minX + BADGE_SIZE * 0.5 + PADDING, elements[idx-1].y)
   
   adjustSectionHeight("header")

   setCurrentScrollPosition("header")
   ]]

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "your_alerts"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("your_alerts"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "feedback",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,xOffset = -8,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 16,
      icon = {default="graphics/arrow_up.png",width=14,height=14,matchTextColor=true,align="right"},
      label=SceneManager.getRosettaString("feedback"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 110,
      height = 32,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.maxX - elements[idx].width * 0.5 - PADDING * 0.5, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,1)
   elements[idx].id = "alert_divider"
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   local dividerY = elements[idx].y

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "my_quotes",
      default = "graphics/chart.png",
      defaultColor = GC.DARK_GRAY,
      font = GC.APP_FONT,
      overColor = GC.DARK_GRAY3,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("quote_activity"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize, getCurrentScrollPosition() + elements[idx].height * 0.5

   addBadge(0,"quote_activity",nil,scrollView.midX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "my_shipments",
      default = "graphics/truck.png",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.DARK_GRAY3,
      font = GC.APP_FONT,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("shipment_activity"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMax - scrollView.quarterSize, elements[idx-1].y

   addBadge(0,"shipment_activity",nil,scrollView.maxX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,1)
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   local dividerY = elements[idx].y

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "message_center",
      default = "graphics/mail.png",
      defaultColor = GC.DARK_GRAY,
      font = GC.APP_FONT,
      overColor = GC.DARK_GRAY3,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("messages"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize, getCurrentScrollPosition() + elements[idx].height * 0.5

   addBadge(0,"messages",nil,scrollView.midX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "gbt_bank",
      default = "graphics/bank.png",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.DARK_GRAY3,
      font = GC.APP_FONT,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("my_banking"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMax - scrollView.quarterSize, elements[idx-1].y

   addBadge(0,"gbt_bank",nil,scrollView.maxX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   adjustSectionHeight("your_alerts")

   setCurrentScrollPosition("your_alerts")

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,1,getCurrentScrollPosition() - getElementById("alert_divider").y)
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() - elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "find_freight",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 22,
      label=SceneManager.getRosettaString("find_freight"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = scrollView.innerWidth,
      height = 50,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "location"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("locate_drivers"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

   idx = getNextElement()

   local w,h = scaleImageByWidth(scrollView.innerWidth,300,118)

   elements[idx] = widget.newButton{
      id = "locate_drivers",
      default = "graphics/location_map.png",
      overColor = GC.MEDIUM_GRAY,--yOffset = -h * 0.5 - PADDING,
      font = GC.BUTTON_FONT,
      fontSize = 22,
      --label=SceneManager.getRosettaString("locate_shipment"),
      --labelColor = { default=GC.DARK_GRAY, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = w,
      height = h,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = optionOnComplete
   }
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   adjustSectionHeight("location",nil,0)

   setCurrentScrollPosition("location")
end

local function addDriverContent()
   local idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "your_alerts"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("your_alerts"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   setCurrentScrollPosition()

    local function createSubmitButton() 
	local buttonSubmit = display.newRect(0,0,83,64)
	buttonSubmit.x, buttonSubmit.y = (getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize)+150, getCurrentScrollPosition() + elements[idx].height * 0.5 - PADDING * 2
	buttonSubmit:setFillColor(1,0,1)
	scrollView:insert(buttonSubmit)
	local function touchToSubmit(event)
		if event.phase == "ended" then
		--if event.phase == "release" then
			print(" calling photo send here")

			sceneClaimPhoto.onSubmit()
			return true
		end
	end
	buttonSubmit:addEventListener("touch",touchToSubmit)
 end
   
   --createSubmitButton()

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,1)
   elements[idx].id = "alert_divider"
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   local dividerY = elements[idx].y

   setCurrentScrollPosition()

   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "message_center",
      default = "graphics/mail.png",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.DARK_GRAY3,
      font = GC.APP_FONT,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("messages"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMin + scrollView.quarterSize, getCurrentScrollPosition() + elements[idx].height * 0.5

   addBadge(0,"messages",nil,scrollView.midX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   idx = getNextElement()

   elements[idx] = widget.newButton{
      id = "my_loads",
      default = "graphics/truck.png",
      defaultColor = GC.DARK_GRAY,
      font = GC.APP_FONT,
      overColor = GC.DARK_GRAY3,
      labelColor = {default = GC.DARK_GRAY, over = GC.DARK_GRAY},
      yOffset = 25,
      label = SceneManager.getRosettaString("my_loads"),
      width = 32,
      height = 32,
      cornerRadius = 0,
      strokeWidth = 0,
      onEvent = optionOnComplete
   }
   scrollView:insert(elements[idx])

   elements[idx].x, elements[idx].y = getElementById("your_alerts").stageBounds.xMax - scrollView.quarterSize, elements[idx-1].y

   addBadge(0,"my_loads",nil,scrollView.maxX - BADGE_SIZE * 0.5 - PADDING * 0.5, dividerY + BADGE_SIZE * 0.5 + PADDING * 0.5)
   
   adjustSectionHeight("your_alerts")

   setCurrentScrollPosition("your_alerts")

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,1,getCurrentScrollPosition() - getElementById("alert_divider").y)
   elements[idx]:setFillColor(unpack(GC.LIGHT_GRAY2))
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() - elements[idx].height * 0.5
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newRect(0,0,scrollView.innerWidth,100)
   elements[idx].id = "location"
   elements[idx]:setFillColor(1,1,1)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = display.newText( {text=SceneManager.getRosettaString("send_location"),font = GC.APP_FONT, fontSize = 20} )
   elements[idx]:setFillColor(unpack(GC.DARK_GRAY))
   elements[idx].x, elements[idx].y = elements[idx-1].stageBounds.xMin + elements[idx].width * 0.5 + PADDING, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING * 2
   scrollView:insert(elements[idx])

   idx = getNextElement()

   elements[idx] = toggle.new({
      id="send_location", x = 0, y = 0,on = "graphics/toggleOn.png", onWidth = 83, onHeight = 32,
      off = "graphics/toggleOff.png", offWidth = 83, offHeight = 32,
      state = SceneManager.getLocationState(), callback = toggleLocationState
   })
   scrollView:insert(elements[idx])
   elements[idx].x, elements[idx].y = scrollView.maxX - elements[idx].width * 0.5 - PADDING, elements[idx-1].y
   
   setCurrentScrollPosition()

   idx = getNextElement()

   local w,h = scaleImageByWidth(scrollView.innerWidth,300,118)

   elements[idx] = display.newImageRect("graphics/location_map.png", w, h)
   elements[idx].x, elements[idx].y = scrollView.x, getCurrentScrollPosition() + elements[idx].height * 0.5 + PADDING
   scrollView:insert(elements[idx])

   adjustSectionHeight("location",nil,0)

   setCurrentScrollPosition("location")
   

end

local function addContent()

   scrollView = widgetNew.newScrollView
   {
      left     = 0,
      top      = 0,
      width    = display.contentWidth,
      height   = display.contentHeight - header.height,
      listener = scrollListener,
      --hideBackground = true,
      backgroundColor = GC.LIGHT_GRAY2,
      bottomPadding  = PADDING * 2,
      horizontalScrollDisabled   = true
   }
   scrollView.anchorY = 0
   scrollView.lineY = 0
   scrollView.innerWidth = scrollView.width - PADDING * 2
   
   scrollView.x, scrollView.y = display.contentCenterX, header.stageBounds.yMax
   scrollView.quarterSize = scrollView.innerWidth / 4
   scrollView.minX = scrollView.stageBounds.xMin + PADDING
   scrollView.midX = scrollView.x
   scrollView.maxX = scrollView.width - PADDING
   sceneGroup:insert(scrollView)
   
   local role = SceneManager.getUserRoleType()

   if (role == GC.USER_ROLE_TYPE_DRIVER) then
      addDriverContent()
   elseif (role == GC.USER_ROLE_TYPE_CARRIER) then
      addCarrierContent()
   elseif (role == GC.USER_ROLE_TYPE_SHIPPER) then
      addShipperContent()
   end

   addReferralSection()

   -- Social Bar
   addSocialContent()

end

function scene:create( event )
	sceneGroup = self.view

   menuSelected = false
   showLocation = false
   updatingBadges = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.LIGHT_GRAY2))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   header = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.HEADER_HEIGHT )
   header:setFillColor(unpack(GC.HEADER_COLOR))
   header.x, header.y = display.contentCenterX, header.height * 0.5

   logo = display.newImageRect( sceneGroup, "graphics/logo.png", GC.HEADER_LOGO_WIDTH, GC.HEADER_LOGO_HEIGHT )
   logo.x, logo.y = header.x, header.y
   
   addHeaderButtons()

   addContent()

   -- mobile website only shows code when not a driver
   -- TODO: This should always be shown now (03/02 mockup shows it for a driver)
   --[[
   if (SceneManager.getUserRoleType() ~= GC.USER_ROLE_TYPE_DRIVER) then
      referralBG = display.newRoundedRect( 0, 0, display.contentWidth - buttonPadding * 2, 50, 7 )
      referralBG:setFillColor(0.8,0.8,0.8)
      referralBG.x, referralBG.y = display.contentCenterX, display.contentHeight - referralBG.height * 0.5 - buttonPadding
      sceneGroup:insert(referralBG)

      referral = display.newText( {text=SceneManager.getRosettaString("referral_code").."\n"..tostring(SceneManager.getReferralCode() or SceneManager.getRosettaString("not_available")),font = GC.APP_FONT, fontSize = 14, width = referralBG.width,align="center"} )
      referral:setFillColor(unpack(GC.DARK_GRAY))
      referral.x, referral.y = referralBG.x, referralBG.y
      sceneGroup:insert(referral)
   end
   ]]--
   --Create a large text string
   --local lotsOfText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur imperdiet consectetur euismod. Phasellus non ipsum vel eros vestibulum consequat. Integer convallis quam id urna tristique eu viverra risus eleifend.\n\nAenean suscipit placerat venenatis. Pellentesque faucibus venenatis eleifend. Nam lorem felis, rhoncus vel rutrum quis, tincidunt in sapien. Proin eu elit tortor. Nam ut mauris pellentesque justo vulputate convallis eu vitae metus. Praesent mauris eros, hendrerit ac convallis vel, cursus quis sem. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque fermentum, dui in vehicula dapibus, lorem nisi placerat turpis, quis gravida elit lectus eget nibh. Mauris molestie auctor facilisis.\n\nCurabitur lorem mi, molestie eget tincidunt quis, blandit a libero. Cras a lorem sed purus gravida rhoncus. Cras vel risus dolor, at accumsan nisi. Morbi sit amet sem purus, ut tempor mauris.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur imperdiet consectetur euismod. Phasellus non ipsum vel eros vestibulum consequat. Integer convallis quam id urna tristique eu viverra risus eleifend.\n\nAenean suscipit placerat venenatis. Pellentesque faucibus venenatis eleifend. Nam lorem felis, rhoncus vel rutrum quis, tincidunt in sapien. Proin eu elit tortor. Nam ut mauris pellentesque justo vulputate convallis eu vitae metus. Praesent mauris eros, hendrerit ac convallis vel, cursus quis sem. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque fermentum, dui in vehicula dapibus, lorem nisi placerat turpis, quis gravida elit lectus eget nibh. Mauris molestie auctor facilisis.\n\nCurabitur lorem mi, molestie eget tincidunt quis, blandit a libero. Cras a lorem sed purus gravida rhoncus. Cras vel risus dolor, at accumsan nisi. Morbi sit amet sem purus, ut tempor mauris. "

   --Create a text object containing the large text string and insert it into the scrollView
   --local lotsOfTextObject = display.newText( lotsOfText, display.contentCenterX, 0, 300, 0, native.systemFont, 14)
   --lotsOfTextObject:setFillColor( 0 ) 
   --lotsOfTextObject.anchorY = 0.0      -- Top
   --------------------------------lotsOfTextObject:setReferencePoint( display.TopCenterReferencePoint )
   --lotsOfTextObject.y = titleText.y + titleText.contentHeight + 10

   --scrollView:insert( lotsOfTextObject )
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
   elseif ( phase == "did" ) then
      updateBadges()
      _G.appExit = true
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      _G.appExit = false
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      composer.removeScene("SceneDashboard",false)
   end
end

function scene:update()
   updateBadges()
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )

   if (sceneTimer) then
      timer.cancel(sceneTimer)
      sceneTimer = nil
   end

   bg:removeSelf()
   bg = nil

   header:removeSelf()
   header = nil

   logo:removeSelf()
   logo = nil

   if (location) then
      location:removeSelf()
      location = nil
   end

   for i=1,#buttons do
      buttons[1]:removeSelf()
      table.remove(buttons, 1)
   end
   buttons = nil

   if (badge) then
      badgeBG:removeSelf()
      badgeBG = nil

      badge:removeSelf()
      badge = nil
   end

   if (referral) then
      referralBG:removeSelf()
      referralBG = nil

      referral:removeSelf()
      referral = nil
   end

   scrollView:removeSelf()
   scrollView = nil

   if (elements) then
      for i = 1, #elements do
         elements[1]:removeSelf()
         table.remove(elements,1)
      end
   end
   elements = nil

   if (badges) then
      for i = 1, #badges do
         badges[1]:removeSelf()
         table.remove(badges,1)
      end
   end
   badges = nil
end

function scene:showMessage()
   if (_G.messageQ) then
      alert:show({message = SceneManager.getRosettaString(_G.messageQ),
         buttons={SceneManager.getRosettaString("ok")}})
      _G.messageQ = nil
   end
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
