local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local menuButton = require("menuButton")
local alert = require("alertBox")
local bgServices = require("bgServices")
local db = require("db")
local status = require("status")

local sceneGroup = nil

local bg = nil
local header = nil
local logo = nil
local bar = nil
local buttons = nil
local primaryButtons = nil
local referralBG, referral = nil, nil
local locationStatus = nil

local buttonPadding = nil

--local MessageX, MessageY = display.contentCenterX, display.contentHeight - 110

local BADGE_SIZE = 15
local BADGE_COLOR = {1,1,1}
local BADGE_LABEL_COLOR = GC.ORANGE

local badgeBG, badge = nil, nil

local PRIMARY_SIZE = 145
local PRIMARY_ICON_SIZE = 50

local BUTTON_WIDTH = 50
local icons = {"user","navicon","question"}
local names = {"user","tools","help"}

local messageQ = nil

local tool_options = {
   {role = GC.USER_ROLE_TYPE_CARRIER, options = {"my_shipments","my_quotes","my_trailers",--[["request_accessorials",]]"my_feedback"}},  
   {role = GC.USER_ROLE_TYPE_SHIPPER, options = {"my_shipments","my_quotes",--[["accessorials",]]"my_feedback"}}   
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

local menuSelected = nil

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
   updateLocationStatus()
end

local function driverLocationOnComplete( event )
   local i = event.target.id
   
   if (i == 2) then
      toggleLocationState()
   end
end

local function promptDriverLocation()
   alert:show({title = SceneManager.getRosettaString("cannot_view_location"),buttonAlign="horizontal",
      message = SceneManager.getRosettaString("turn_on_location_question"),
      buttons={SceneManager.getRosettaString("no"),
      SceneManager.getRosettaString("yes")},
      callback=driverLocationOnComplete})
end

local function optionOnComplete( event,value )
   local i = event.target.id
   
   if (i == "my_trailers") then
      SceneManager.goToMyTrailers()
   elseif (i == "my_quotes") then
      SceneManager.goToMyQuotes()
      --SceneManager.goTo("my_quotes",nil,false,nil)
   elseif (i == "my_shipments") then
      SceneManager.goToMyShipments()
      --SceneManager.goTo("my_shipments",nil,false,nil)
   elseif (i == "my_feedback") then
      SceneManager.goToMyFeedback()
   elseif (i == "gbt_bank") then
      --SceneManager.goToMyBanking()
      SceneManager.goTo("gbt_bank",nil,false,nil)
   elseif (i == "post_shipment") then
      onPost()
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
   elseif (i == "view_location") then
      if (SceneManager.getLocationState()) then
         if (_G.currPoint.lat == 0 or _G.currPoint.lon == 0) then
            alert:show({title = SceneManager.getRosettaString("no_location"),
               message = SceneManager.getRosettaString("no_location_message"),
               buttons={SceneManager.getRosettaString("ok")}})
         else
            SceneManager.showMap({type=GC.DRIVER_LOCATION,data={name=SceneManager.getUserFullname(),latitude=_G.currPoint.lat,longitude=_G.currPoint.lon}})
         end
      else
         promptDriverLocation()
      end
   end
end

local function userOptionsOnComplete( event )
   local i = event.target.id
   if (i == 1) then
      SceneManager.showReferGBT()
   elseif i == 2 then
      _G.removeTag(SceneManager.getUserSID())
      SceneManager.setUserSID("")
      SceneManager.setSessionId(nil)
      SceneManager.goToLoginScene()
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
      buttons={SceneManager.getRosettaString("refer_gbt"),
      SceneManager.getRosettaString("log_out"),
      SceneManager.getRosettaString("cancel")},cancel=3,
      callback=userOptionsOnComplete})
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

local function toolsComplete(event,value)
   local index = getRoleIndex(tool_options)
   optionOnComplete({target = {id = tool_options[index].options[value]}})
end

local function showOptions(option_table)
   local index = getRoleIndex(option_table)
   
   local buttons = {}
   
   for i = 1, #option_table[index].options do
      buttons[i] = SceneManager.getRosettaString(option_table[index].options[i])
   end
   
   alert:show({title = SceneManager.getRosettaString("please_select"),
      list = {options = buttons,radio = false},
      buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
      callback=toolsComplete})
end

local function getBadgeCount()
   -- TODO: read local database of messages sent to user and return
   -- only new ones as a count
   return db.getMessageCount(SceneManager.getUserSID())
end

local function updateMessageBadge()
   local count = getBadgeCount()
   local label = count
   
   if (count > 9) then
      label = "9+"
   end

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

local function onEventCallback(event)
   if (event.target.id == "user") then
      showUserOptions()
   elseif (event.target.id == "tools") then
      showOptions(tool_options)
   elseif (event.target.id == "help") then
      SceneManager.goTo("help",nil,true,nil)
	end
end

local function createButtons()
   buttons = {}
   
   local x = GC.DASHBOARD_BAR_HEIGHT * 0.5
   local idx = 1

   for i=1, #icons do
      if (i == 2 and SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_DRIVER) then
         -- Skip over for now
      else
         buttons[idx] = widget.newButton{
            id = names[i],
            defaultColor = GC.DASHBOARD_BAR_BUTTON_DEFAULT_COLOR,
            overColor = GC.DASHBOARD_BAR_BUTTON_OVER_COLOR,
            icon = {default="graphics/"..icons[i]..".png",width=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,height=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE},
            width = GC.DASHBOARD_BAR_HEIGHT,
            height = GC.DASHBOARD_BAR_HEIGHT,
            cornerRadius = 0,
            strokeWidth = 0,
            border = {color={68/255,76/255,85/255},type="right"},
            onRelease = onEventCallback
         }

         buttons[idx].x, buttons[idx].y = x, bar.y
         x = x + GC.DASHBOARD_BAR_HEIGHT
         sceneGroup:insert(buttons[idx])
         idx = idx + 1
      end
   end

   -- 1st is always message center
   buttonPadding = 10 --(display.contentWidth - PRIMARY_SIZE * 2) / 3
   local startX = PRIMARY_SIZE * 0.5 + (display.contentWidth - PRIMARY_SIZE * 2 - buttonPadding) * 0.5
   local yOffset = bar.stageBounds.yMax + PRIMARY_SIZE * 0.5 + buttonPadding
   local xOffset = startX

   primaryButtons = {}

   primaryButtons[1] = widget.newButton{
      id = "message_center",
      defaultColor = GC.ORANGE,
      overColor = GC.ORANGE_OVER,
      label = SceneManager.getRosettaString("message_center"),
      labelAlign = "bottom",
      labelColor = {default = {1,1,1}, over = {1,1,1}},
      font = GC.APP_FONT,
      fontSize = 16,
      icon = {default="graphics/mail.png",width=PRIMARY_ICON_SIZE,height=PRIMARY_ICON_SIZE},
      width = PRIMARY_SIZE,
      height = PRIMARY_SIZE,
      cornerRadius = 0,
      strokeWidth = 2,
      strokeColor = GC.ORANGE_OVER,
      onRelease = optionOnComplete
   }
   primaryButtons[1].x, primaryButtons[1].y = xOffset,yOffset
   sceneGroup:insert(primaryButtons[1])

   xOffset = xOffset + PRIMARY_SIZE + buttonPadding

   local index = getRoleIndex(primary_functions)

   for i = 1,#primary_functions[index].functions do
      -- Clerk and Dispatch can't see banking (not authorized)
      if (primary_functions[index].functions[i].label == "gbt_bank" and (SceneManager.getUserRole() == GC.API_ROLE_DISPATCH or SceneManager.getUserRole() == GC.API_ROLE_CLERK)) then
         -- Skip this button for now
      else
         primaryButtons[i + 1] = widget.newButton{
            id = primary_functions[index].functions[i].label,
            defaultColor = GC.ORANGE,
            overColor = GC.ORANGE_OVER,
            label = SceneManager.getRosettaString(primary_functions[index].functions[i].label),
            labelAlign = "bottom",
            labelColor = {default = {1,1,1}, over = {1,1,1}},
            font = GC.APP_FONT,
            fontSize = 16,
            icon = {default="graphics/"..primary_functions[index].functions[i].icon,width=PRIMARY_ICON_SIZE,height=PRIMARY_ICON_SIZE},
            width = PRIMARY_SIZE,
            height = PRIMARY_SIZE,
            cornerRadius = 0,
            strokeWidth = 2,
            strokeColor = GC.ORANGE_OVER,
            onRelease = optionOnComplete
         }
         primaryButtons[i + 1].x, primaryButtons[i + 1].y = xOffset,yOffset
         sceneGroup:insert(primaryButtons[i + 1])

         xOffset = xOffset + PRIMARY_SIZE + buttonPadding
         
         if ((i + 1) % 2 == 0) then
            xOffset = startX
            yOffset = yOffset + PRIMARY_SIZE + buttonPadding
         end
      end
   end

   if (#primaryButtons == 3) then
      primaryButtons[3].x = display.contentCenterX
   end

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_DRIVER) then
      updateLocationStatus()
   end
end

function scene:create( event )
	sceneGroup = self.view

   menuSelected = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   header = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.HEADER_HEIGHT )
   header:setFillColor(unpack(GC.HEADER_COLOR))
   header.x, header.y = display.contentCenterX, header.height * 0.5

   logo = display.newImageRect( sceneGroup, "graphics/logo.png", GC.HEADER_LOGO_WIDTH, GC.HEADER_LOGO_HEIGHT )
   logo.x, logo.y = header.x, header.y
   
   bar = display.newRect( sceneGroup,0, 0, display.contentWidth, GC.DASHBOARD_BAR_HEIGHT )
   bar:setFillColor({type = "gradient",color1 = GC.DASHBOARD_TOP_COLOR,color2 = GC.DASHBOARD_BOTTOM_COLOR,direction = "down"})
   bar.x, bar.y = display.contentCenterX, header.stageBounds.yMax + bar.height * 0.5

   createButtons()

   -- mobile website only shows code when not a driver
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
      updateMessageBadge()
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
   updateMessageBadge()
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   bar:removeSelf()
   bar = nil

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

   for i=1,#primaryButtons do
      primaryButtons[1]:removeSelf()
      table.remove(primaryButtons, 1)
   end
   primaryButtons = nil

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