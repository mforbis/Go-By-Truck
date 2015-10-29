local composer = require( "composer" )
local scene = composer.newScene()

-- Toast Message Definitions
local statusMessageStyle = "rounded" -- Or can be "normal"
local statusMessageRoundedSize = 10 -- How many pixels to round by
local statusMessagePaddingSize = 10
local statusMessageMarginSize = 10 -- On full size how many pixels to come back in on each side
local statusMessageWidthType = "fit" -- if not "full" then it just pads with the above size
local statusMessageBackgroundColor = { 0,0,0,92 } -- R,G,B,A
local statusMessageFontType = native.systemFontBold
local statusMessageFontSize = 18
local statusMessageFontColor = { 255, 255, 255, 255} -- R,G,B,A

local BUSY_SIZE = 50
local BUSY_X, BUSY_Y = display.contentCenterX, display.contentHeight - 120

local overlay, message, bg = nil,nil,nil
local messageText = nil
local busy = nil
local tweenBusy = nil
local bgSize = nil

local function stopAnimation()
	if (tweenBusy) then
		transition.cancel(tweenBusy)
		tweenBusy = nil
	end
end

local function startAnimation()
	stopAnimation()
	busy.rotation = 0
	tweenBusy = transition.to(busy, {time = 1000, rotation = 360, onComplete = startAnimation})
end

-- Called when the scene's view does not exist:
function scene:create( event )
	local screenGroup = self.view
	
	local params = event.params
	local messageText = params.message
	
	overlay = display.newRect(0,0,display.contentWidth, display.contentHeight)
	overlay:setFillColor(0,0,0,0.5)
	screenGroup:insert(overlay, true)
	overlay.x,overlay.y = display.contentCenterX,display.contentCenterY
	
	if (messageText) then
		message = display.newText( messageText, 0, 0, statusMessageFontType, statusMessageFontSize )
		message:setTextColor( statusMessageFontColor[1], statusMessageFontColor[2], statusMessageFontColor[3], statusMessageFontColor[4] )
		screenGroup:insert(message, true)
		message.x,message.y = display.contentCenterX,display.contentCenterY

		-- Insert rounded rect behind textObject
		if (statusMessageStyle == "rounded") then
			if (statusMessageWidthType == "full") then w = display.contentWidth - (statusMessageMarginSize * 2) else w = message.contentWidth + statusMessagePaddingSize*2 end
			bg = display.newRoundedRect( 0, 0, w, message.contentHeight + 2*statusMessagePaddingSize, statusMessageRoundedSize )
			bg:setFillColor( statusMessageBackgroundColor[1], statusMessageBackgroundColor[2], statusMessageBackgroundColor[3], statusMessageBackgroundColor[4] )
			screenGroup:insert( 1, bg, true )
		else
			if (statusMessageWidthType == "full") then w = display.contentWidth - (statusMessageMarginSize * 2) else w = message.contentWidth + 2*statusMessagePaddingSize end
			bg = display.newRect( 0, 0, w, message.contentHeight + 2*statusMessagePaddingSize)
			bg:setFillColor( statusMessageBackgroundColor[1], statusMessageBackgroundColor[2], statusMessageBackgroundColor[3], statusMessageBackgroundColor[4] )
			screenGroup:insert( 1, bg, true )
		end
		bg.x,bg.y = message.x, message.y
	else
		-- Default to busy animation
		busy = display.newImageRect(screenGroup,"graphics/busy.png",BUSY_SIZE,BUSY_SIZE)
		busy.x, busy.y = BUSY_X, BUSY_Y
		startAnimation()
	end
end

-- Called immediately after scene has moved onscreen:
function scene:show( event )
	
end

function scene:hide( event )
local sceneGroup = self.view
   local phase = event.phase
   if ( phase == "will" ) then
      
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      composer.removeScene("toast",false)
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
	overlay:removeSelf()
	overlay = nil
	
	if (message) then
		message:removeSelf()
		message = nil
		bg:removeSelf()
		bg = nil
	end

	if (busy) then
		busy:removeSelf()
		busy = nil
	end
	stopAnimation()
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