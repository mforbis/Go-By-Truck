local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local alert = require("alertBox")
local ProgressDialog = require("progressDialog")

local sceneGroup = nil
local title = nil
local btnClose = nil
local webview = nil
local border = nil
local overlay = nil

local pd

local function hideProgressDialog()
   if (pd) then
      pd:dismiss()
      pd = nil
   end
end

local function showProgressDialog()
   pd = ProgressDialog:new({graphic="graphics/busy.png"})
end

local function hideWebView()
   webview.isVisible = false
   btnClose.isVisible = false
   border.isVisible = false
   overlay.isVisible = false
   title.isVisible = false
end

local function showWebView()
   webview.isVisible = true
   btnClose.isVisible = true
   border.isVisible = true
   overlay.isVisible = true
   title.isVisible = true
end

-- NOTE: May have to support check as well
local function onTransfer()
   -- https://www.gbthq.com:9443/carrier/banking/withdrawBank
   webview:request("https://www.gbthq.com:9443/carrier/banking/withdrawBank")
end

local function onClose()
   composer.hideOverlay()
end

local function onAlertComplete()
   onClose()
end

local function webViewCallback( event )
   hideProgressDialog()
   if event.errorCode then
      alert:show({title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString("server_error_message"),
         buttons={SceneManager.getRosettaString("ok"),
         callback = onAlertComplete}
      })
   else
      showWebView()
   end
end

local function onEventCallback(event)
end

function scene:create( event )
   sceneGroup = self.view

   overlay = display.newRect(sceneGroup,0, 0, display.contentWidth, display.contentHeight)
   overlay:setFillColor(0,0,0,0.4)
   overlay.x, overlay.y = display.contentCenterX, display.contentCenterY

   border = display.newRect(sceneGroup,0,0,display.contentWidth - 40, display.contentWidth - 40)
   border:setFillColor(unpack(GC.TITLE_BG_COLOR))
   border.x, border.y = display.contentCenterX, display.contentCenterY

   title = display.newText(sceneGroup, SceneManager.getRosettaString("transfer_funds"), 0, 0, GC.SCREEN_TITLE_FONT, 18)
   title.x, title.y = border.x, border.stageBounds.yMin + 17

   btnClose = display.newImageRect(sceneGroup,"graphics/close.png",30,30)
   btnClose:addEventListener("tap",onClose)
   btnClose.x, btnClose.y = border.stageBounds.xMax, border.stageBounds.yMin

   webview = native.newWebView( 0, 0, border.width - 2, border.height - 36 )
   webview.x, webview.y = border.x, border.stageBounds.yMin + webview.height * 0.5 + 35
   webview:addEventListener( "urlRequest", webViewCallback )

   sceneGroup:insert(webview)

   showProgressDialog()

   hideWebView()

   onTransfer()
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

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneTransfer")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   title:removeSelf()
   title = nil

   btnClose:removeSelf()
   btnClose = nil

   webview:removeSelf()
   webview = nil

   border:removeSelf()
   border = nil
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