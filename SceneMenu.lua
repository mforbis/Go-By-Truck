local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")

local bg = nil
local btnBlank = nil

local function onEventCallback(event)
	if (event.target.id == "close") then
	end
end

function scene:create( event )
	local sceneGroup = self.view
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
      -- Called when the scene is on screen (but is about to go off screen).
      -- Insert code here to "pause" the scene.
      -- Example: stop timers, stop animation, stop audio, etc.
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      composer.removeScene("SceneMenu",false)
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil
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