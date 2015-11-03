local composer = require( "composer" )
local scene = composer.newScene()
local GC = require("AppConstants")
local SceneManager = require("SceneManager")

local bg = nil
local splash = nil

local tween = nil

local function animationDone()
   if (tween) then
      transition.cancel(tween)
      tween = nil
   end
end

function scene:create( event )
	local sceneGroup = self.view

   bg = display.newRect( 0, 0, 360, 570 )
   bg:setFillColor(0,0,0)
   bg.x, bg.y = display.contentCenterX, display.contentCenterY
   sceneGroup:insert(bg)

   local defaultExt = ""
   if (SceneManager.isIphone5()) then
      --defaultExt = "-568h"
   end

   splash = display.newImageRect( sceneGroup, "graphics/splash"..defaultExt..".png", 320, 110 )
   splash.x, splash.y = display.contentCenterX, display.contentCenterY
   splash.xScale, splash.yScale = 0.4, 0.4

   tween = transition.to( splash, {xScale = 1, yScale = 1, time = 300, onComplete = animationDone} )
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
      animationDone()
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      composer.removeScene("SceneSplash",false)
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   splash:removeSelf()
   splash = nil
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