local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local ProgressDialog = require("progressDialog")
local utils = require("utils")
local api = require("api")

local TIMEOUT_MS = 60000
local WEBPAGE_FILENAME = "webpage.html"
local ANDROID_DEFAULT_WEBVIEW_X = 2000

local sceneGroup = nil
local bg = nil
local btnBack = nil
local btnHome = nil
local logo = nil
local titleBG = nil
local webView = nil
local lblMessage = nil

local currScene
local lblTitle
local params
local url
local page
local subPage

local currPage

local isOverlay

local loadingPage
local actionTimer = nil

local callback = nil

local hideRole
local backTitle

local trackWebHistory
local rootPage
local currentPage

local history = nil

local isAndroid = system.getInfo("platformName") == "Android"

local messageQ

local function showMessage(messageQ)
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         local scene = page..(subPage or "")
         
         api.sendAPIError({scene=scene,reason="Invalid JSON"})
      end

      alert:show({
       title = SceneManager.getRosettaString("error"),
       message = SceneManager.getRosettaString(messageQ),
       buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function hoursSinceLastLogin(timeStamp)
   return math.floor((os.time() - timeStamp) / (60 * 60 * 1000))
end

local function daysSinceLastLogin(timeStamp)
   return math.floor((os.time() - timeStamp) / (24 * 60 * 60 * 1000))
end

local function stopPD()
   if (pd) then
      pd:dismiss()
      pd = nil
   end
end

local function stopTimeout()
   if (actionTimer) then
      timer.cancel(actionTimer)
      actionTimer = nil
   end
end

local function handleTimeout()
   lblMessage.text = SceneManager.getRosettaString("server_timeout")
   lblMessage.isVisible = true
   stopWebView()
end

local function startTimeout()
   stopTimeout()
   actionTimer = timer.performWithDelay(TIMEOUT_MS, handleTimeout)
end

local function stopWebView()
   loadingPage = false
   stopPD()
   webview:stop()
end

local function writeHTMLFile(html)
   fileio.write(html,WEBPAGE_FILENAME)
end

local function handleCallback(event)
   --Log("response: "..tostring(event.response))
   if (event.response) then
      writeHTMLFile(event.response)
      webview:request(WEBPAGE_FILENAME,system.DocumentsDirectory)
   end
end

local function sendNetworkRequest(url)
   network.request(url, "GET", handleCallback )
end

--https://www.gbthq.com:8443/carrier/requestAccessorials?webview=true&jsessionid=88B4CFD2CC314F035134308777F7AFFC&loadIdGuid=424

local function loadWebView(url)
   if (isAndroid) then
      webview.x = ANDROID_DEFAULT_WEBVIEW_X --display.contentWidth + webview.width + 10
   end

   loadingPage = true
   lblMessage.isVisible = false
   webview.isVisible = false
   pd = ProgressDialog:new({graphic="graphics/busy.png"})
   
   Log("webview Scene (url): "..tostring(url))
   webview:request(url)
   --sendNetworkRequest(url)
end

local function webViewCallback( event )
   Log("webViewCallback:")
   Log("type: "..tostring(event.type))
   Log("errorCode: "..tostring(event.errorCode))
   Log("url: "..tostring(event.url))
   Log("-------------")

   if (event.errorCode) then
      --lblMessage.text = SceneManager.getRosettaString("server_error")
      --stopWebView()
      -- TODO: Fix situations on iOS where errorMessage = 'NSURLerrorDomain error -999'
      -- We can ignore, but haven't seen to insure code will work 100%
   elseif (event.type == "other") then
      
   elseif (event.type == "loaded") then
      stopWebView()
      webview.isVisible = true
      if (isAndroid) then
         webview.x = display.contentCenterX
      end
      currentPage = event.url or ""
      if (trackWebHistory and history == nil) then
         history = currentPage
      end
   elseif (event.type == "link") then
      
   elseif (event.type == "form") then
      Log("would follow: "..event.url)

      -- Once they try to submit a form, let's just go back to the previous scene
      if (event.type == "form") then
         trackWebHistory = false
      end
      --webview:stop()
      --local url = event.url.."?"..SceneManager.getPageSessionDetails()
      --Log("New: "..url)
      --loadWebView(url)
   end
end

local function notRoot()
   return string.find(currentPage,rootPage) == nil
end

local function onHome()
   if (loadingPage) then
      stopWebView()
   end

   SceneManager.goToDashboard()
end

local function onBack(event)
   if (loadingPage) then
      stopWebView()
   end
   
   if (trackWebHistory and notRoot() and history) then
      webview:request(history)
      history = nil
      --webview:back()
   elseif (isOverlay) then
      composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,GC.SCENE_TRANSITION_TIME_MS)
   else
      SceneManager.goToDashboard()
   end
end

local function onEventCallback(event)
   if (event.target.id == "blank") then
   end
end

local function load()
   loadWebView(SceneManager.SceneManager.getFullWebview(page..subPage,params,hideRole))
   -- AJMB -- caught missed variable setting for _G.sceneExit which keeps the scene from exiting elegantly to the SceneDashboard.
   print("****** START type(_G.sceneExit) = "..tostring(type(_G.sceneExit))) -- checking for value prior
      if (isOverlay) then
         _G.overlay = onBack
      else
         _G.sceneExit = onBack
      end
   print("****** COMPLETE type(_G.sceneExit) = "..tostring(type(_G.sceneExit))) -- checking for value post
end

local function loginCallback(response)
   messageQ = nil

   if (response == nil or response.user == nil) then
      messageQ = "invalid_server_response"
   elseif (response.user.statusId == GC.API_ERROR) then
         messageQ = response.error_msg.errorMessage or "server_error"
   elseif (response.user.statusId == GC.API_USER_APPROVED) then
      if (response.user.userGuid ~= nil and response.user.masterRole ~= nil) then
         if (response.user.jsessionid and response.user.jsessionid ~= "") then
            -- Save last login time, so we have a reference as to when it will expire in the future
            SceneManager.setLastLogin(os.time())
            SceneManager.setSessionId(response.user.jsessionid)

            load()
         else
            -- Get last saved sessionId
            SceneManager.readSessionId()
         end
      else
         messageQ = "invalid_server_response"
      end
   else
      messageQ = "user_not_approved"
   end

   showMessage()
end

local function handleLogin()
   api.login({id=SceneManager.getUserID(),password=SceneManager.getUserPass(),callback=loginCallback})
end

local function sessionCallback(response)
   local isValid = true

   messageQ = nil

   if (response == nil) then
      messageQ = "invalid_server_response"
   elseif (not utils.stringToBool(response.validsession)) then
      isValid = false
   end

   showMessage()

   if (not isValid) then
      handleLogin()
   else
      load()
   end
end

local function checkSession()
   if (SceneManager.readSessionId() == nil) then
      handleLogin()
   else
      api.checkSessionId({sessionId=SceneManager.readSessionId(),callback=sessionCallback})
   end
end

function scene:create( event )
   sceneGroup = self.view
   print(" ******* START type(_G.sceneExit) = "..tostring(type(_G.sceneExit)))

   lblTitle = ""
   history = nil

   isOverlay = false
   hideRole = false
   backTitle = "close"
   trackWebHistory = false
   rootPage = ""

   page = ""
   subPage = ""

   if (event.params) then
      if (event.params.onComplete and type(event.params.onComplete) == "function") then
         callback = event.params.onComplete
      end
      if (event.params.scene) then
         currScene = event.params.scene
         
         isOverlay = event.params.isOverlay or false

         params = event.params.extra

         lblTitle = currScene or ""

         if (currScene == "my_shipments") then
            page = "loadManager"
            local roleType = SceneManager.getUserRoleType()

            if (roleType == GC.USER_ROLE_TYPE_CARRIER) then
               subPage = "/matched"
            elseif (roleType == GC.USER_ROLE_TYPE_SHIPPER) then
               subPage = "/loadActionItems"
            end
         elseif (currScene == "re-quote") then
            page = "createQuote"
         elseif (currScene == "shipper_counter") then
            page = "viewShipperCounter"
         elseif (currScene == "release_amount") then
            page = "releasePayment"
         elseif (currScene == "request_accessorials") then
            page = "requestAccessorials"
         elseif (currScene == "view_accessorials") then
            page = "requestHistory"
         elseif (currScene == "carrier_requested") then
            page = "carrierRequestedAccessorials"
         elseif (currScene == "view_quotes") then
            page = "viewLoadQuotes"
         elseif (currScene == "accept_load") then
            page = "acceptLoad"
         elseif (currScene == "trailer_addedit") then
            page = "trailerAddEdit"
         elseif (currScene == "help") then
            page = currScene
            hideRole = true
         elseif (currScene == "post_shipment") then
		     print(" /////////////////////// post_shipment  here")

            if (params and params.loadIdGuid) then
               page = "post"
               hideRole = true
            else
               page = "postChoice"
               rootPage = page
               trackWebHistory = true
            end
            backTitle = "cancel"
         elseif (currScene == "quote_shipment_find") then
            page = "quotePopup"
            lblTitle = "quote_shipment"
            backTitle = "cancel"
         elseif (currScene == "shipment_details") then
            page = "loadDetails"
         elseif (currScene == "find_freight") then
            page = "search"
         elseif (currScene == "my_quotes") then
            page = "quoteManager"
            subPage = "/actionItems"
         elseif (currScene == "gbt_bank") then
            page = "banking"
            subPage = "/cashActual"
         elseif (currScene == "sign_pod") then
            page = "mobile/"
            subPage = "sendPOD"
            hideRole = true
         end
      end
      if (isOverlay) then
         _G.overlay = onBack
      else
         _G.sceneExit = onBack
      end
   print("****** COMPLETE type(_G.sceneExit) = "..tostring(type(_G.sceneExit)))
   end

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.HEADER_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   logo = display.newImageRect( sceneGroup, "graphics/logo.png", GC.HEADER_LOGO_WIDTH, GC.HEADER_LOGO_HEIGHT )
   logo.x, logo.y = titleBG.x, titleBG.y

   -- TODO: This will most likely change
   --[[
   if (isOverlay) then
      btnBack = widget.newButton{
         id = "close",
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 16,
         label=SceneManager.getRosettaString(backTitle,1),
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 60,
         height = GC.BUTTON_ACTION_HEIGHT,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onBack
      }
      btnBack.x, btnBack.y = btnBack.width * 0.5 + 5 , titleBG.y
   else
      btnBack = widget.newButton{
         id = "back",
         default = "graphics/back.png",
         width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
         overColor = {0.5,0.5,0.5,1},
         onRelease = onBack
      }
      btnBack.x, btnBack.y = btnBack.width * 0.5 + 5, titleBG.y
   end
   ]]--

   btnHome = widget.newButton{
      id = "home",
      default = "graphics/home.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onHome
   }
   btnHome.x, btnHome.y = btnHome.width * 0.5 + 5, titleBG.y
   sceneGroup:insert(btnHome)

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onBack
   }
   btnBack.x, btnBack.y = display.contentWidth - btnBack.width * 0.5 - 5, titleBG.y
   sceneGroup:insert(btnBack)

   local startX = 0

   -- Android devices will show the webview before we can hide it properly, so we create it off the screen
   if (isAndroid) then
      startX = ANDROID_DEFAULT_WEBVIEW_X
   end

   webview = native.newWebView(startX, 0, display.contentWidth, display.contentHeight - titleBG.height)
   webview:addEventListener( "urlRequest", webViewCallback )
   webview.x, webview.y = display.contentCenterX, titleBG.height + webview.height * 0.5
   webview.isVisible = false
   sceneGroup:insert(webview)

   lblMessage = display.newText(sceneGroup,"",0,0,GC.APP_FONT, 16)
   lblMessage.isVisible = false
   lblMessage:setFillColor(unpack(GC.DARK_GRAY))
   lblMessage.x, lblMessage.y = webview.x, webview.y

   -- Database will be scrubbed after 36 hours, so let's only check if we are getting close to
   -- eliminate API calls.
   if (SceneManager.readSessionId() == nil or hoursSinceLastLogin(SceneManager.getLastLogin()) > 30) then
      checkSession()
   else
      load()
   end
   
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase
   print("type(_G.sceneExit) = "..tostring(type(_G.sceneExit)))

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      if (isOverlay) then
         _G.overlay = onBack
      else
         _G.sceneExit = onBack
      end
   end
   print("type(_G.sceneExit) = "..tostring(type(_G.sceneExit)))
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      webview.isVisible = false
      if (isOverlay) then
         _G.overlay = nil
      else
         _G.sceneExit = nil
      end
   elseif ( phase == "did" ) then
      if (callback) then
         callback()
      end
      composer.removeScene("SceneWebview")
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

   logo:removeSelf()
   logo = nil

   lblMessage:removeSelf()
   lblMessage = nil

   webview:removeSelf()
   webview = nil
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