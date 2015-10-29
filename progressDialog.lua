local ProgressDialog = {}

--[[
1.1 - 
* 09/04/2014 - Fixed a bug that would cause a crash if it started an animation after it was dismissed.

1.0 - Initial Version
]]--
function ProgressDialog:new(options)
	local 	options = options or {}

	local 	style = options.style or "rounded"
	local 	width = options.width or "fit"
	local 	cornerRadius = options.cornerRadius or 10
	local 	padding = options.padding or 10
	local 	margin = options.margin or 10
	local 	bgColor = options.bgColor or {0,0,0,92/255}
	local 	font = options.font or native.systemFontBold
	local 	fontSize = options.fontSize or 18
	local 	fontColor = options.fontColor or {1,1,1}
	local 	graphic = options.graphic
	local 	graphicWidth = options.graphicWidth or 50
	local 	graphicHeight = options.graphicHeight or 50

	local self = display.newGroup()

	self.overlay = display.newRect(0,0,display.contentWidth, display.contentHeight)
	self.overlay:setFillColor(0,0,0,0.5)
	self:insert(self.overlay, true)
	self.overlay.x,self.overlay.y = self.x, self.y

	self.stopAnimation = function()
		if (self.tweenBusy) then
			transition.cancel(self.tweenBusy)
			self.tweenBusy = nil
		end
	end

	self.startAnimation = function()
		self.stopAnimation()
		if (self.graphic) then
			self.graphic.rotation = 0
			self.tweenBusy = transition.to(self.graphic, {time = 1000, rotation = 360, onComplete = self.startAnimation})
		end
	end

	if (options.graphic) then
		self.graphic = display.newImageRect(self,graphic,graphicWidth,graphicHeight)
		self.graphic.x, self.graphic.y = options.graphicX or self.x, options.graphicY or self.y + 120

		self.startAnimation()
	else
		self.message = display.newText( options.message or "Loading", 0, 0, font, fontSize )
		self.message:setTextColor( unpack(fontColor))
		self:insert(self.message, true)
		self.message.x,self.message.y = self.x, self.y

		local bgWidth = self.message.contentWidth + padding * 2
		if (width == "full") then
			bgWidth = display.contentWidth - (margin * 2)
		end

		if (style == "rounded") then
			self.bg = display.newRoundedRect( 0, 0, bgWidth, self.message.contentHeight + padding * 2, cornerRadius )
		else
			self.bg = display.newRect( 0, 0, bgWidth, self.message.contentHeight + padding * 2)
		end

		self:insert( 1, self.bg, true )
		self.bg:setFillColor( unpack(bgColor))
		self.bg.x,self.bg.y = self.message.x, self.message.y
	end

	self.touchListener = function(self,event)
		local result = true
		
		if (event.phase == "ended") then
			
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	self.x, self.y = display.contentCenterX, display.contentCenterY

	function self:dismiss()
		self.overlay:removeSelf()
		self.overlay = nil
		
		if (self.message) then
			self.message:removeSelf()
			self.message = nil
			
			self.bg:removeSelf()
			self.bg = nil
		end

		if (self.graphic) then
			self.graphic:removeSelf()
			self.graphic = nil
		end

		self.stopAnimation()
	end

	return self
end

return ProgressDialog