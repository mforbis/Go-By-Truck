module(..., package.seeall)

-- Status Message Definitions
statusMessageStyle = "rounded" -- Or can be "normal"
statusMessageRoundedSize = 12 -- How many pixels to round by
statusMessagePaddingSize = 10
statusMessageMarginSize = 10 -- On full size how many pixels to come back in on each side
statusMessageWidthType = "fit" -- if not "full" then it just pads with the above size
statusMessageBackgroundColor = { 0,0,0,0.78 } -- R,G,B,A
statusMessageFontType = "Oswald"
statusMessageFontSize = 14
statusMessageFontColor = { 255, 255, 255, 1200} -- R,G,B,A

----------------------------------------------
--Status Message for facebook posting alert 
statusMessage = nil
messageTimer = nil

local function cancelMsgTimer()
	if (messageTimer) then
		timer.cancel (messageTimer)
		messageTimer = nil
	end
end

local function msgCallback()
	cancelMsgTimer()
	transition.to( statusMessage, {delay=0,time=500, alpha = 0} )
end

function removeStatusMessage()
	if (statusMessage) then 
		statusMessage:removeSelf() 
		statusMessage = nil
	end
end

function showStatusMessage( message, x, y, toastLength )
	cancelMsgTimer()
	
	removeStatusMessage()
	local statusText = display.newText( message, 0, 0, statusMessageFontType, statusMessageFontSize )
	statusText:setFillColor( statusMessageFontColor[1], statusMessageFontColor[2], statusMessageFontColor[3], statusMessageFontColor[4] )

	-- A trick to get text to be centered
	local group = display.newGroup()
	group:insert( statusText, true )
 
	-- Insert rounded rect behind textObject
	if (statusMessageStyle == "rounded") then
		if (statusMessageWidthType == "full") then w = display.contentWidth - (statusMessageMarginSize * 2) else w = statusText.contentWidth + statusMessagePaddingSize*2 end
		local roundedRect = display.newRoundedRect( 0, 0, w, statusText.contentHeight + 2*statusMessagePaddingSize, statusMessageRoundedSize )
		roundedRect:setFillColor( statusMessageBackgroundColor[1], statusMessageBackgroundColor[2], statusMessageBackgroundColor[3], statusMessageBackgroundColor[4] )
		group:insert( 1, roundedRect, true )
	else
		if (statusMessageWidthType == "full") then w = display.contentWidth - (statusMessageMarginSize * 2) else w = statusText.contentWidth + 2*statusMessagePaddingSize end
		local normalRect = display.newRect( 0, 0, w, statusText.contentHeight + 2 * statusMessagePaddingSize)
		normalRect:setFillColor( statusMessageBackgroundColor[1], statusMessageBackgroundColor[2], statusMessageBackgroundColor[3], statusMessageBackgroundColor[4] )
		group:insert( 1, normalRect, true )
	end
	
	group.statusText = statusText
	
	group.x = x or display.contentCenterX
	group.y = y or display.contentHeight - group.height * 0.5 - 10
	

	if (toastLength > 0) then
		messageTimer = timer.performWithDelay( toastLength, msgCallback )
	end

	statusMessage = group
end
----------------------------------------------