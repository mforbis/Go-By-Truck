module(..., package.seeall)

-- Label class

function newLabel( params )
	local labelText
	local size, font, textColor, align
	
	if ( params.bounds ) then
		local bounds = params.bounds
		local left = bounds[1]
		local top = bounds[2]
		local width = bounds[3]
		local height = bounds[4]
	
		if ( params.size and type(params.size) == "number" ) then size=params.size else size=20 end
		if ( params.font ) then font=params.font else font=native.systemFontBold end
		if ( params.textColor ) then textColor=params.textColor else textColor={ 255, 255, 255, 255 } end
		if ( params.offset and type(params.offset) == "number" ) then offset=params.offset else offset = 0 end
		if ( params.align ) then align = params.align else align = "center" end

		labelText = display.newText( params.text or " ", 0, 0, font, size )
		labelText:setTextColor( textColor[1], textColor[2], textColor[3], textColor[4] )

		if ( align == "left" ) then
			labelText.x = left + labelText.contentWidth * 0.5
		elseif ( align == "right" ) then
			labelText.x = (left + width) - labelText.contentWidth * 0.5
		else
			labelText.x = ((2 * left) + width) * 0.5
		end
		labelText.y = top + labelText.contentHeight * 0.5

		-- Public methods
		function labelText:setText( newText )
			if ( newText ) then
				self.text = newText
				if ( "left" == align ) then
					self.x = left + self.width / 2 
				elseif ( "right" == align ) then
					self.x = (left + width) - self.width / 2
				else
					self.x = ((2 * left) + width) / 2
				end
			end
		end
		
		function labelText:setTextColor( textColor )
			if ( textColor and type(textColor) == "table" ) then
				self:setTextColor( textColor[1], textColor[2], textColor[3], textColor[4] )
			end
		end
	end

	-- Return instance
	return labelText

end

-- Helper function for newButton utility function below

function newButtonHandler( self, event )

	local result = true

	local default = self[1]
	local over = self[2]
	
	-- General "onEvent" function overrides onPress and onRelease, if present
	local onEvent = self._onEvent
	
	local onPress = self._onPress
	local onRelease = self._onRelease

	local buttonEvent = {}
	if (self._id) then
		buttonEvent.id = self._id
	end

	local phase = event.phase
	if "began" == phase then
		if over then 
			default.isVisible = false
			over.isVisible = true
		end

		if onEvent then
			buttonEvent.phase = "press"
			result = onEvent( buttonEvent )
		elseif onPress then
			result = onPress( event )
		end

		-- Subsequent touch events will target button even if they are outside the stageBounds of button
		display.getCurrentStage():setFocus( self )
		self.isFocus = true

	elseif self.isFocus then
		local bounds = self.stageBounds
		local x,y = event.x,event.y
		local isWithinBounds = 
			bounds.xMin <= x and bounds.xMax >= x and bounds.yMin <= y and bounds.yMax >= y

		if "moved" == phase then
			if over then
				-- The rollover image should only be visible while the finger is within button's stageBounds
				default.isVisible = not isWithinBounds
				over.isVisible = isWithinBounds
			end

		elseif "ended" == phase or "cancelled" == phase then 
			if over then 
				default.isVisible = true
				over.isVisible = false
			end

			-- Only consider this a "click" if the user lifts their finger inside button's stageBounds
			if isWithinBounds then
				if onEvent then
					buttonEvent.phase = "release"
					result = onEvent( buttonEvent )
				elseif onRelease then
					if self.uid then
						event.uid = self.uid
					end
					if self.params then
						event.params = self.params
					end

					result = onRelease( event )
				end
			end

			-- Allow touch events to be sent normally to the objects they "hit"
			display.getCurrentStage():setFocus( nil )
			self.isFocus = false
		end
	end

	return result
end
