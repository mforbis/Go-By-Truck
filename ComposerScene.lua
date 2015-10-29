local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")

local sceneGroup = nil
local bg = nil
local btnBack = nil
local title = nil
local titleBG = nil

local function onEventCallback(event)
   if (event.target.id == "blank") then
   end
end

function scene:create( event )
   sceneGroup = self.view

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("my_shipments_title"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnBack.x, btnBack.y = btnBack.width * 0.5 + 5, titleBG.y
   sceneGroup:insert(btnBack)
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      -- Called when the scene is now on screen.
      -- Insert code here to make the scene come alive.
      -- Example: start timers, begin animation, play audio, etc.
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
    
   elseif ( phase == "did" ) then
      composer.removeScene("")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnBack:removeSelf()
   btnBack = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil
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