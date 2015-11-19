local composer = require( "composer" )
local scene = composer.newScene()
local widget = require("widget-v1")
local SceneManager = require("SceneManager")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local bgServices = require("bgServices")
local alert = require("alertBox")
local utils = require("utils")

-- TODO: Need to handle being sent back here if logged out from the server later in the app
-- app will return here
local MessageX = display.contentCenterX
local MessageY = 360

local HIDDEN_PASSWORD_TEXT = "SOMEVALUETOSHOW"

local INPUT_WIDTH = 280
local INPUT_HEIGHT = 30
local BOX_SIZE = 20

local showingAlert = false
local bg = nil

local title = nil
local btnLogin = nil
local lblAutomaticLogin = nil
local check, checkbox = nil, nil

local showingOverlay = false
local tweenSplash = nil

local bgUser, bgPass = nil, nil
local tfUser, tfPass = nil, nil

local hasAutomaticLogin = nil

local showingToast = nil

local isLoggingIn = nil
local hasLoggedIn = nil
local messageQ = nil

local API_TIMEOUT_MS = 10000
local apiTimer = nil

local userName
local password

local forcingLogin
local hasFocus

local function alertDismiss(event)
   showingAlert = false
   tfPass.isVisible = true
   tfUser.isVisible = true
end

local function handleInput(self)
   if (self.id == "user") then
      userName = self.text
   else
      password = self.text
   end
end

local function showStatus(text_id)
      status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      --showStatus(messageQ)

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="Login",reason="Invalid JSON"})
      end

      tfPass.isVisible = false
      tfUser.isVisible = false
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")},sendCancel = true,
         callback=alertDismiss
      })
      messageQ = nil
   end
end

local function switchToRoleScene()
   local roleType = nil

   local role = SceneManager.getUserRole()
   
   if (role == GC.API_ROLE_DRIVER) then
      roleType = GC.USER_ROLE_TYPE_DRIVER
   elseif (role == GC.API_ROLE_MASTER_CARRIER_ADMIN or role == GC.API_ROLE_CARRIER_ADMIN or role == GC.API_ROLE_DISPATCH) then
      roleType = GC.USER_ROLE_TYPE_CARRIER
   elseif (role == GC.API_ROLE_SHIPPER_ADMIN or role == GC.API_ROLE_MASTER_SHIPPER_ADMIN or role == GC.API_ROLE_CLERK or role == GC.API_ROLE_SHIPPER_ACCOUNTING) then
      roleType = GC.USER_ROLE_TYPE_SHIPPER
   end
   
   -- Reset any list globals
   _G.shipmentTypeState = nil
   _G.quoteFilterOption = nil
   
   if (roleType) then
      SceneManager.setUserRoleType(roleType)

      -- If user is now not a driver then turn off location tracking
      if (roleType ~= GC.USER_ROLE_TYPE_DRIVER) then
         SceneManager.setLocationState(false)
      end
      --print ("locationState: "..tostring(SceneManager.getLocationState()))
      if (SceneManager.getLocationState()) then
         bgServices.startLocationService()
      else
         bgServices.stopLocationService()
      end

      SceneManager.handleUserLogin()

      SceneManager.goToDashboard()
   else
      showStatus("invalid_role")
      hasLoggedIn = false
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
   --messageQ = "server_timeout"
   --showMessage()
   api.handleTimeout()
end

local function startTimeout()
   stopTimeout()
   apiTimer = timer.performWithDelay(API_TIMEOUT_MS, handleTimeout)
end

local function stopSplash()
   tfUser.isVisible = not showingAlert
   tfPass.isVisible = not showingAlert
   timer.cancel(tweenSplash)
   tweenSplash = nil
   showingOverlay = false
   composer.hideOverlay()
   if (isLoggingIn) then
      showToast()
   elseif (hasLoggedIn) then
      switchToRoleScene()
   else
      showMessage()
   end
end

local function showSplash()
   tfUser.isVisible = false
   tfPass.isVisible = false
   showingOverlay = true
   SceneManager.showSplash()
   SceneManager.setAppLoad(false)
   tweenSplash = timer.performWithDelay(GC.SHOW_SPLASH_MS, stopSplash)
end

local function apiCallback(response)
   isLoggingIn = false
   hideToast()
   stopTimeout()

   if (response == nil or response.user == nil) then
      messageQ = "invalid_server_response"
   elseif (response.user.statusId == GC.API_ERROR) then
         if (SceneManager.getUserSID() ~= "") then
            tfPass.text = ""
         end
         SceneManager.setUserSID("")
         messageQ = response.error_msg.errorMessage or "server_error"
   elseif (response.user.statusId == GC.API_USER_APPROVED) then
      if (response.user.userGuid ~= nil and response.user.masterRole ~= nil) then
         SceneManager.setUserSID(response.user.userGuid)
         -- Set Pushbots tag
         _G.addTag(SceneManager.getUserSID())
         SceneManager.setUserRole(response.user.masterRole)
         SceneManager.setReferralCode(response.user.referralCode)
         SceneManager.setUserFirstname(response.user.firstName)
         SceneManager.setUserLastname(response.user.lastName)
         
         -- TODO: This needs to change, if we have a sid then first should check for valid jsessionid
         -- If not then force regular login.

         -- When using SID as login, there isn't any jsessionid sent back
         if (response.user.jsessionid and response.user.jsessionid ~= "") then
            -- Save last login time, so we have a reference as to when it will expire in the future
            SceneManager.setLastLogin(os.time())
            SceneManager.setSessionId(response.user.jsessionid)
         else
            -- Get last saved sessionId
            SceneManager.readSessionId()
         end

         local canRequestAccessorials = response.user.canRequestAccessorials

         if (canRequestAccessorials ~= nil) then
            SceneManager.setAccessorialState(utils.stringToBool(canRequestAccessorials))
         end
      
         hasLoggedIn = true
         if (not showingOverlay) then
            switchToRoleScene()
         end
      else
         messageQ = "invalid_server_response"
      end
   else
      messageQ = "user_not_approved"
   end

   if (not showingOverlay) then
      showMessage()
   end
end

local function fieldsSet()
   if (userName == "" or password == "") then
      showingAlert = true
      tfPass.isVisible = false
      tfUser.isVisible = false
      alert:show({title = SceneManager.getRosettaString("fields_not_set_title"),
         message = SceneManager.getRosettaString("fields_not_set_message"),sendCancel = true,
         buttons={SceneManager.getRosettaString("ok")},
         callback=alertDismiss})
      return false
   end

   return true
end

local function handleLogin(show)
   native.setKeyboardFocus( nil )
   hasFocus = nil
   
   local temp = tfUser.text
   temp = tfPass.text
   
   if (fieldsSet()) then
      isLoggingIn = true
      hasLoggedIn = false
      messageQ = nil

      -- Do not read in text field value if forcing login
      -- Android will not have the value we need.
      if (not forcingLogin) then
         SceneManager.setUserID(tfUser.text)
         SceneManager.setUserPass(password)
      end

      if (not showingOverlay) then
         showToast()
      end

      startTimeout()

      if (SceneManager.getUserSID() ~= "") then
         api.login({sid=SceneManager.getUserSID(),showPD=false,callback=apiCallback})
      else
         api.login({id=tfUser.text,password=password,showPD=false,callback=apiCallback})
      end
   end
end

local function inputListener( event )
   if (hasFocus == nil) then
      hasFocus = event.target
   end
   
   if event.phase == "began" then
   elseif event.phase == "ended" then
      
   elseif event.phase == "submitted" then
      native.setKeyboardFocus( nil )
      if (event.target.id == "password") then
         handleLogin()
      else
         native.setKeyboardFocus(tfPass)
      end
   elseif event.phase == "editing" then
      handleInput(event.target)
   end

   hasFocus = event.target
end

local function clearSID()
   SceneManager.setUserSID("") -- Clear to force use of user/pass values
end

local function onEventCallback(event)
	if (event.target.id == "login") then
      clearSID()
      handleLogin()
   elseif (event.target.id == "signup") then
      system.openURL( GC.MAIN_URL .. "/register" )
	end
end

local function toggleAutomatic(event)
   hasAutomaticLogin = not hasAutomaticLogin

   SceneManager.setAutomaticLogin(hasAutomaticLogin)
   check.isVisible = hasAutomaticLogin
end

local function sessionCallback(response)
   if (response == nil) then
      messageQ = "invalid_server_response"
   elseif (not utils.stringToBool(response.validsession)) then
      Log("Reset Session")
      -- Force use of user/pass to get new session (SID login doesn't return sessionId)
      clearSID()
   end

   showMessage()

   handleLogin() -- Login in the background while displaying possible splash
end

local function checkSession()
   local sessionId = SceneManager.readSessionId()

   if (sessionId and sessionId ~= "") then
      api.checkSessionId({sessionId=sessionId,showPD=false,callback=sessionCallback})
   else
      clearSID()
   end
end

function scene:create( event )
	local sceneGroup = self.view

   forcingLogin = false
   showingOverlay = false
   isLoggingIn = false
   hasLoggedIn = false

   hasAutomaticLogin = SceneManager.hasAutomaticLogin()

   userName = SceneManager.getUserID()
   password = ""

   bg = display.newImageRect(sceneGroup,"graphics/bg_truck.png",display.contentWidth,display.contentHeight)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   logotag = display.newImageRect(sceneGroup,"graphics/logo_tag.png",256, 88 )
   logotag.x, logotag.y = display.contentCenterX,  80
   function logotag:touch( event )
      if event.phase == "ended" or event.phase == "cancelled" then
         SceneManager.setAppLoad(true)
         SceneManager.goToHomeScene()
      end
   end
   logotag:addEventListener( "touch", logotag )
   sceneGroup:insert(logotag)

   function bg:touch( event )
      if event.phase == "ended" or event.phase == "cancelled" then
         native.setKeyboardFocus( nil )
      end
   end
   
   bg:addEventListener( "touch", bg )

   bgUser = display.newRoundedRect( sceneGroup,0, 0, INPUT_WIDTH, INPUT_HEIGHT + 10,GC.INPUT_ROUNDED_CORNER )
   bgUser:setFillColor(unpack(GC.INPUT_FIELD_BG_COLOR))
   bgUser.strokeWidth = GC.INPUT_FIELD_BORDER_WIDTH
   bgUser:setStrokeColor(unpack(GC.INPUT_FIELD_BORDER_COLOR))
   bgUser.x, bgUser.y = display.contentCenterX, logotag.x + 50

   tfUser = native.newTextField(0, 0, INPUT_WIDTH - 10, INPUT_HEIGHT)
   tfUser:setReturnKey( "next" )
   tfUser.id = "user"
   tfUser.inputType = "default"
   tfUser.align = "left"
   tfUser.size = GC.INPUT_FIELD_TEXT_SIZE
   tfUser:setTextColor(unpack(GC.INPUT_FIELD_TEXT_COLOR))
   tfUser:addEventListener( "userInput", inputListener )
   tfUser.hasBackground = false
   tfUser.text = userName
   tfUser.placeholder = "User Name"
   sceneGroup:insert(tfUser)
   tfUser.x, tfUser.y = bgUser.x, bgUser.y

   bgPass = display.newRoundedRect( sceneGroup,0, 0, INPUT_WIDTH, INPUT_HEIGHT + 10,GC.INPUT_ROUNDED_CORNER )
   bgPass:setFillColor(unpack(GC.INPUT_FIELD_BG_COLOR))
   bgPass.strokeWidth = GC.INPUT_FIELD_BORDER_WIDTH
   bgPass:setStrokeColor(unpack(GC.INPUT_FIELD_BORDER_COLOR))
   bgPass.x, bgPass.y = display.contentCenterX, bgUser.stageBounds.yMax + INPUT_HEIGHT + 15

   
   tfPass = native.newTextField(0, 0, INPUT_WIDTH - 10, INPUT_HEIGHT)
   tfPass:setReturnKey( "go" )
   tfPass.id = "password"
   tfPass.inputType = "default"
   tfPass.isSecure = true
   tfPass.align = "left"
   tfPass.size = GC.INPUT_FIELD_TEXT_SIZE
   tfPass:addEventListener( "userInput", inputListener )
   tfPass:setTextColor(unpack(GC.INPUT_FIELD_TEXT_COLOR))
   tfPass.hasBackground = false
   tfPass.placeholder = "Password"
   sceneGroup:insert(tfPass)
   tfPass.x, tfPass.y = bgPass.x, bgPass.y
   
   btnSignup = widget.newButton{
      id = "signup",
      defaultColor = GC.GREY_BUTTON,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = GC.BUTTON_FONT_SIZE,
      label=SceneManager.getRosettaString("signup"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = INPUT_WIDTH * 0.5 - 5,
      height = INPUT_FIELD_TEXT_SIZE,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.GREY_BUTTON_BORDER,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnSignup.x, btnSignup.y =  bgPass.stageBounds.xMin + btnSignup.width * 0.5, bgPass.stageBounds.yMax + btnSignup.height + 50
   sceneGroup:insert(btnSignup)


   btnLogin = widget.newButton{
      id = "login",
      defaultColor = GC.ORANGE2,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = GC.BUTTON_FONT_SIZE,
      label=SceneManager.getRosettaString("login"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = INPUT_WIDTH * 0.5 - 5,
      height = INPUT_FIELD_TEXT_SIZE,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnLogin.x, btnLogin.y =  btnSignup.x + btnSignup.width + 10, btnSignup.y

   

   sceneGroup:insert(btnLogin)

   checkbox = display.newRoundedRect( sceneGroup, 0, 0, BOX_SIZE, BOX_SIZE,0 )
   checkbox.strokeWidth = 1
   checkbox:setStrokeColor(unpack(GC.INPUT_FIELD_BORDER_COLOR))
   checkbox:setFillColor(unpack(GC.INPUT_FIELD_BG_COLOR))
   checkbox.alpha = .5
   checkbox.x, checkbox.y = bgPass.stageBounds.xMin + checkbox.width * 0.5, btnLogin.stageBounds.yMax + checkbox.height * 0.5 + 10
   checkbox:addEventListener("tap", toggleAutomatic)

   check = display.newImageRect(sceneGroup, "graphics/check_white.png", BOX_SIZE - 4, BOX_SIZE - 4)
   check:setFillColor(unpack(GC.ORANGE))
   check.x, check.y = checkbox.x, checkbox.y
   check.isVisible = hasAutomaticLogin

   lblAutomaticLogin = display.newText(sceneGroup, SceneManager.getRosettaString("automatic_login"), 0, 0, GC.APP_FONT, 20)
   lblAutomaticLogin:setFillColor(unpack(GC.HINT_TEXT_COLOR))
   lblAutomaticLogin.anchorX = 0
   lblAutomaticLogin.x, lblAutomaticLogin.y = checkbox.stageBounds.xMax + 10, checkbox.y

   if (SceneManager.isAppLoad()) then
      showSplash()
      
      if (hasAutomaticLogin and SceneManager.getUserSID() ~= "") then
         forcingLogin = true
         --password = HIDDEN_PASSWORD_TEXT
         password = SceneManager.getUserPass() -- We now need this, so fake value won't work
         tfPass.text = password
         -- Is our session still valid?
         checkSession()
      end
   end

   -- turn off location in case we just logged out
   bgServices.stopLocationService()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.appExit = true
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()

      tfUser:removeSelf()
      tfUser = nil

      tfPass:removeSelf()
      tfPass = nil
      _G.appExit = false
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      if (not showingOverlay or not showingToast) then
         composer.removeScene("SceneLogin",false)
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   bgUser:removeSelf()
   bgUser = nil

   bgPass:removeSelf()
   bgPass = nil

   check:removeSelf()
   check = nil

   checkbox:removeSelf()
   checkbox = nil

   lblAutomaticLogin:removeSelf()
   lblAutomaticLogin = nil

   logotag:removeSelf()
   logotag = nil

   btnLogin:removeSelf()
   btnLogin = nil
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