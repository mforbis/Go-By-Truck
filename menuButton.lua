local menuButton = {}

local DEFAULT_IMAGE_SIZE = 50

function menuButton:new(params)
	local self = display.newGroup()
	
	local id = params.id or "menu_button"

	if (params.bg) then
		self.bg = display.newImageRect(self,params.bg,params.width or DEFAULT_IMAGE_SIZE,params.height or DEFAULT_IMAGE_SIZE)
	else
		self.bg = display.newRect(self,0,0,params.width or DEFAULT_IMAGE_SIZE, params.height or DEFAULT_IMAGE_SIZE)
	end
	self.bg.x, self.bg.y = self.x, self.y

	if (params.icon) then
		self.icon = display.newImageRect(self,params.icon.default, params.icon.width or DEFAULT_IMAGE_SIZE, params.icon.height or DEFAULT_IMAGE_SIZE)
		self.icon.x, self.icon.y = self.x, self.y
	end

	self.touchListener = function(self,e)
		local result = true

		if (event.phase == "ended" and self.onRelease) then
			result = self.onRelease(e)
		end
		return result
	end
	
	self.touch = self.touchListener
	self:addEventListener("touch")

	function self:free()
		self.bg:removeSelf()
		self.bg = nil

		if (self.icon) then
			self.icon:removeSelf()
			self.icon = nil
		end

		self:removeSelf()
		self = nil
	end

	self.x, self.y = params.x or display.contentCenterX, params.y or display.contentCenterY

	return self
end

return menuButton