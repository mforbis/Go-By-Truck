local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local utils = require("utils")
local alert = require("alertBox")
local api = require("api")
local status = require("status")

local PADDING = 10
local BORDER_WIDTH = 240
local BORDER_HEIGHT = 360
local BORDER_STROKE_WIDTH = 2
local MessageY = display.contentHeight - 90

local sceneGroup = nil
local overlayGroup = nil
local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local graphic = nil

local btnCapture, btnSubmit = nil, nil

local hasPhoto

local photo = nil

local shipment = nil

local messageQ = nil

local function removePhoto()
   if (photo ~= nil) then
      photo:removeSelf()
      photo = nil
      hasPhoto = false
   end
end

local function removeOverlays()
   sceneGroup:remove(overlayGroup)
end

local function addOverlays()
   sceneGroup:insert(overlayGroup)
end

local function updateButtonState()
   if (hasPhoto) then
      btnSubmit:enable()
   else
      btnSubmit:disable()
   end
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="ClaimPhoto",reason="Invalid JSON"})
      end

      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function apiCallback(response)
   messageQ = nil

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = "server_error" --response.error_msg.errorMessage
   elseif (response.status == "true" or response.status == true) then
      removePhoto()
      updateButtonState() 

      alert:show({
         message = SceneManager.getRosettaString("upload_successful"),
         buttons={SceneManager.getRosettaString("ok")}
      })
   else
      messageQ = "upload_error"
   end

   showMessage()
end

local function onSubmit()
   -- upload image via API call
   -- if successful then either remove current image, or bitch if they hit send again and
   -- haven't captured a new one, since the last upload
   -- NOTE: For now the app is deleting it if the upload was successful.
   print("PRESSING SEND HERE")
   GC.globalSID = SceneManager.getUserSID()
   GC.globalGUID = shipment.loadIdGuid
	--api.sendClaimPhoto({sid=SceneManager.getUserSID(),loadIdGuid=shipment.loadIdGuid,callback=apiCallback}) -- commented out to test simple base encoding against Moonbeam server
	api.sendClaimPhoto({sid=SceneManager.getUserSID(),loadIdGuid=shipment.loadIdGuid}) -- working code with substituted network.request callback.
end

local function onHome()
   SceneManager.goToDashboard()
end

local function onClose()
   composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,GC.SCENE_TRANSITION_TIME_MS)
end

local sessionComplete = function(event)   
   if event.completed then
      collectgarbage( "collect" )
      
      -- Camera shot was successfully taken.
      -- Display at full resolution by passing in true.
      --photo = display.newImage(photoFileName, system.DocumentsDirectory)
      removePhoto()
      removeOverlays()
      
      hasPhoto = true
      
      photo = event.target

      photo.x, photo.y = display.contentCenterX, display.contentCenterY
      
      local photoWidth = photo.width
      local photoHeight = photo.height
      
      -- Make image smaller, so it takes less bandwith (might cause error to go away)
      local scaleValue = (display.contentWidth / photoWidth) * 0.5
      
      local device = utils.getDeviceMetrics()
   
      local factor = device.coronaHeight / math.floor((device.coronaWidth / device.pixelWidth) * device.pixelHeight)
      
      local scaleValueX = scaleValue
      local scaleValueY = scaleValue * factor
      
      photo.xScale = scaleValueX
      photo.yScale = scaleValueY
      photo.x, photo.y = display.contentCenterX, display.contentCenterY
	  
	  GC.globalSID = SceneManager.getUserSID()
	  GC.globalGUID = shipment.loadIdGuid
	  globalImageName = "image.png"
      GC.IMAGE_FILENAME = "sid="..GC.globalSID.."%26".."globalIdGuid="..GC.globalGUID.."%26".."t="..GC.IMAGE_TYPE_CLAIM_PHOTO.."%26"..globalImageName
	  print("GC.IMAGE_FILENAME = "..tostring(GC.IMAGE_FILENAME))
      display.save(photo, GC.IMAGE_FILENAME, system.DocumentsDirectory)
      
      --print ("width: "..photoWidth..", height: "..photoHeight)
      --print ("xScale: "..photo.xScale..", yScale: "..photo.yScale)

      -- scale back up, so it looks good on the screen
      photo.xScale = scaleValueX * 2
      photo.yScale = scaleValueY * 2

      --_G.photoWidth = photo.width * scaleValueX
      --_G.photoHeight = photo.height * scaleValueY
      
      --_G.photoXScale = photo.xScale
      --_G.photoYScale = photo.yScale
      
      --print ("w = "..photo.width * scaleValueX..", h = "..photo.height * scaleValueY)
      
      sceneGroup:insert(photo)
      addOverlays()

      updateButtonState()
   else
       -- Delay to allow filesystem to catch up.
      -- May be the cause of hangups on some devices.
      --delayTimer = timer.performWithDelay( 1000, changeScene)
   end
end

local function showCamera()
   --media.show( media.Camera, sessionComplete)
	if media.hasSource( media.Camera ) then
		media.capturePhoto( { listener=sessionComplete } )
	else
		native.showAlert( "Corona", "This device does not have a camera.", { "OK" } )
	end
end

local function alertOnComplete( event,value )
   local i = event.target.id
   
   if (i == 2) then
      showCamera()
   end
end

local function onCapture()
   if (hasPhoto) then
      alert:show({title = SceneManager.getRosettaString("capture"),
      message=SceneManager.getRosettaString("photo_overwrite_message"),buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("capture")},buttonHeight=30,
      cancel = 1,callback=alertOnComplete})
   else
      showCamera()
   end
end

function scene:create( event )
   sceneGroup = self.view

   if (event.params and event.params.shipment) then
      shipment = event.params.shipment
   else
      shipment = {loadIdGuid = "397",addressGUID="438"}
   end

   hasPhoto = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   overlayGroup = display.newGroup()
   
   titleBG = display.newRect( overlayGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(overlayGroup, SceneManager.getRosettaString("claim_photos"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnHome = widget.newButton{
      id = "back",
      default = "graphics/home.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onHome
   }
   btnHome.x, btnHome.y = btnHome.width * 0.5 + 5, titleBG.y
   overlayGroup:insert(btnHome)

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onClose
   }
   btnBack.x, btnBack.y = display.contentWidth - btnBack.width * 0.5 - 5, titleBG.y
   overlayGroup:insert(btnBack)

   graphic = display.newImageRect( sceneGroup, "graphics/polaroids.png", 200, 179 )
   graphic.x, graphic.y = display.contentCenterX, display.contentCenterY
   sceneGroup:insert(graphic)

   btnCapture = widget.newButton{
      id = "capture",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("capture",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 100,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onCapture
   }
   btnCapture.x, btnCapture.y = display.contentCenterX - btnCapture.width * 0.5 - PADDING, display.contentHeight - btnCapture.height * 0.5 - PADDING
   overlayGroup:insert(btnCapture)

   btnSubmit= widget.newButton{
      id = "submit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("send",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 100,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onSubmit
   }
   btnSubmit.x, btnSubmit.y = display.contentCenterX + btnSubmit.width * 0.5 + PADDING, display.contentHeight - btnSubmit.height * 0.5 - PADDING
   overlayGroup:insert(btnSubmit)

   addOverlays()

   updateButtonState()
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
      status.removeStatusMessage()
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneClaimPhoto")
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

   title:removeSelf()
   title = nil

   btnCapture:removeSelf()
   btnCapture = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   graphic:removeSelf()
   graphic = nil
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
