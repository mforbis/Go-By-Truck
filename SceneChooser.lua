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
   SceneManager.goToDriverLoginScene()
   --show overlay asking for phone number
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

   bg = display.newImageRect(sceneGroup,"graphics/bg.png",display.contentWidth,display.contentHeight)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   imgLogo = display.newImageRect("graphics/logo_tag.png",256, 88 )
   imgLogo.x, imgLogo.y = display.contentCenterX,  display.contentHeight *.2
   sceneGroup:insert(imgLogo)

   local elementWidth = display.contentWidth - PADDING * 2
   local minX = display.contentWidth + PADDING
   local yOffset = SELECTOR_DEFAULT_HEIGHT * 0.5
   local btnWidth = 75
   local btnHeight = 97
   local btnSpace = 20

   local text1 = [[Go By Truck is the first full service system designed and build specifically
    for the shipping industry. Our founders spent years in the industry with one mission: ]]

   local text2 = [[To design and build a sustainable free market system that will change the face
    of the shipping industry.]]
   local text3 = [[Please select your role:]]
   local options = {
      text = text1,
      x = display.contentCenterX,
      width = imgLogo.width + 20,
      fontSize = 14,
      align = "center",
      font = GC.APP_FONT
   }

   textarea1 = display.newText(options)
   textarea1.y=imgLogo.y + imgLogo.height + 20
   sceneGroup:insert(textarea1)

   textarea2 = display.newText(options)
   textarea2.text=text2
   textarea2.y=textarea1.y + textarea1.height
   sceneGroup:insert(textarea2)

   local options = {
      text = text1,
      x = display.contentCenterX,
      width = imgLogo.width + 20,
      fontSize = 20,
      align = "center",
      font = GC.APP_FONT
   }

   textarea3 = display.newText(options)
   textarea3.y=textarea2.y + textarea2.height 
   textarea3.text = text3
   sceneGroup:insert(textarea3)

   btnDriver = display.newImageRect("graphics/btnDriver.png",btnWidth,btnHeight)
   btnDriver.x, btnDriver.y = display.contentCenterX/3 + btnSpace, display.contentHeight  *.9 - 10
   btnDriver:addEventListener("touch", onDriverClick)
   sceneGroup:insert(btnDriver)

   btnCarrier = display.newImageRect("graphics/btnCarrier.png",btnWidth,btnHeight)
   btnCarrier.x, btnCarrier.y = btnDriver.x + btnWidth + btnSpace, btnDriver.y
   btnCarrier:addEventListener("touch", onCarrierClick)
   sceneGroup:insert(btnCarrier)

   btnShipper = display.newImageRect("graphics/btnShipper.png",btnWidth,btnHeight)
   btnShipper.x, btnShipper.y = btnCarrier.x + btnWidth + btnSpace, btnCarrier.y
   btnShipper:addEventListener("touch", onShipperClick)
   sceneGroup:insert(btnShipper)

  
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

   imgLogo:removeSelf()
   imgLogo = nil

   textarea1:removeSelf()
   textarea1 = nil
   textarea2:removeSelf()
   textarea2 = nil
   textarea3:removeSelf()
   textarea3 = nil

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