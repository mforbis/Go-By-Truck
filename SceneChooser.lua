local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local alert = require("alertBox")

local PADDING = 10
local SELECTOR_DEFAULT_WIDTH = 240
local SELECTOR_DEFAULT_HEIGHT = 40
local BUTTON_HEIGHT = 40
local BUTTON_XOFFSET = 5

local sceneGroup = nil
local bg = nil
local btnDone = nil
local title = nil
local titleBG = nil
local overlay = nil

local elements = nil
local index = 0

local data = nil

local currSelection

local callback = nil

local function onDriverClick()
   composer.hideOverlay( "fade", 400 )
   --show overlay asking for phone number
   SceneManager.goToDriverLoginScene()
end

local function onShipperClick()
   composer.hideOverlay( "fade", 400 )
   SceneManager.goToLoginScene()
end

local function onCarrierClick()
   composer.hideOverlay( "fade", 400 )
   SceneManager.goToLoginScene()
end

function scene:create( event )
   sceneGroup = self.view

   elements = {}

   if (event.params) then
      if (event.params.callback and type(event.params.callback) == "function") then
         callback = event.params.callback
      end
      if (event.params.data) then
         data = event.params.data
      end
   end

   if (data == nil) then
      data = {
         package={pkgType="Reels",pkgValue=1,pkgPickup=0,pkgDropoff=426},
         locations = {
            {addressGuid="423",alias="GBT",address="3524 E Nora St SPRINGFIELD, MO 65809",type=11,startDate="2014/09/01",endDate="2014/09/02",startTime="03:28 pm EST",stopTime="04:30 pm EST",podRequired=false},
            {addressGuid="438",alias="Moonbeam",address="3003 E Chestnut Expy SPRINGFIELD, MO 65802",type=11,startDate="2014/09/01",endDate="2014/09/02",startTime="03:28 pm EST",stopTime="04:30 pm EST",podRequired=false},
            {addressGuid="426",alias="TX Office",address="925 S. Main St. GRAPEVINE, TX 76051",type=12,startDate="2014/09/07",endDate="2014/09/07",startTime="",stopTime="",podRequired=false},
            {addressGuid="438",alias="Moonbeam",address="3003 E Chestnut Expy SPRINGFIELD, MO 65802",type=11,startDate="2014/09/01",endDate="2014/09/02",startTime="03:28 pm EST",stopTime="04:30 pm EST",podRequired=false},
         }
      }
   end

   overlay = display.newRect(sceneGroup,0, 0, 360, 570)
   overlay:setFillColor(0,0,0,0)
   overlay.x, overlay.y = display.contentCenterX, display.contentCenterY

   bg = display.newRect(sceneGroup,0,0,display.contentWidth - 20,400)
   bg:setFillColor(1,1,1)
   bg.strokeWidth = 1
   bg:setStrokeColor(unpack(GC.DARK_GRAY))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, bg.width, 40 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY2))
   titleBG.x, titleBG.y = display.contentCenterX, bg.stageBounds.yMin + titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("Choose Your Role"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   local elementWidth = bg.width - PADDING * 2
   local minX = bg.stageBounds.xMin + PADDING
   local yOffset = titleBG.stageBounds.yMax + SELECTOR_DEFAULT_HEIGHT * 0.5
   local btnWidth = 200

   btnDriver = widget.newButton {
      id = "driver",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label="Driver",
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = btnWidth,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onDriverClick
   }
   btnDriver.x, btnDriver.y = display.contentCenterX, titleBG.y + btnDriver.height + 15
   sceneGroup:insert(btnDriver)

   btnShipper = widget.newButton {
      id = "shipper",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label="Shipper",
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = btnWidth,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onShipperClick
   }
   btnShipper.x, btnShipper.y = display.contentCenterX, btnDriver.y + btnShipper.height + 15
   sceneGroup:insert(btnShipper)

   btnCarrier = widget.newButton {
      id = "carrier",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("carrier",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = btnWidth,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onCarrierClick
   }
   btnCarrier.x, btnCarrier.y = display.contentCenterX, btnShipper.y + btnCarrier.height + 15
   sceneGroup:insert(btnCarrier)
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = onDone
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("ScenePackaging")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   overlay:removeSelf()
   overlay = nil

   btnDriver:removeSelf()
   btnDriver = nil

   btnShipper:removeSelf()
   btnShipper = nil

   btnCarrier:removeSelf()
   btnCarrier = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   for i = 1, #elements do
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