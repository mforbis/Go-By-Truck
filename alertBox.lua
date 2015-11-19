local widget = require("widget-v1")
local newWidget = require("widget") -- For listview
local GC = require("AppConstants")
--[[
Bugs:

Working:

Releases:
1.5 -
* Fixed a bug that would cause rows to not have colors alternated when filtering
* Added filter type substring. Default: prefix
* Inserted a global variable to help with back button handlers (_G.alert (self).
* Partially fixed a bug where touch events don't always fire for a listview.
* Text now wraps properly when too long for list.
* sendCancel will send a callback call for cancel events [default = false].
* Added a filter to large listviews.

1.4 -
* (11/05/2014) Added listRows to options

1.3 -
* (9/23/2014) Fixed a bug that would cause the value to be overwritten if self.type was nil

1.2 - 
* (8/14/2014) Modified handling of individual ids, so list items can have names instead of the row index
* Added ability to filter non numbers when input type is number (currently doesn't allow ',', or '.')
* Added list type uses options, and still allows buttons (cancel)
* Added type for input values: default, number, decimal, phone, url, email
* Added maxlength to input
* Added cornerRadius to options
* Fixed a bug that prevented correct placement of elements when title was absent.
* Fixed bugs related to when no buttons are added (size, and dismissing)
* Fixed a bug that prevented the keyboard from hiding when dismissing

* Added fontSize to options
* Added width to options

1.1 -
* Fixed an issue whereby the input would sometimes show before the dialog if button calculations took too long

1.0 - Initial Version
]]--

local alertBox = {}

local PADDING = 10

local ORANGE = {239/255,96/255,40/255}--233/255,78/255,27/255--{242/255,139/255,36/255}
local ORANGE_OVER = {189/255,63/255,22/255}

local DEFAULT_WIDTH = 280
local DEFAULT_FONT = "Open Sans Light"
local DEFAULT_FONT_SIZE = 18
local BUTTON_ACTION_TEXT_COLOR = {1,1,1}
local BUTTON_ACTION_TEXT_COLOR_OVER = {1,1,1}
local BUTTON_ACTION_BACKGROUND_COLOR = ORANGE
local BUTTON_ACTION_BACKGROUND_COLOR_OVER = ORANGE_OVER
local BUTTON_ACTION_BORDER_COLOR = GC.BUTTON_ACTION_BORDER_COLOR
local BUTTON_ACTION_RADIUS_SIZE = 5
local BUTTON_ACTION_BORDER_WIDTH = 1
local BUTTON_CANCEL_TEXT_COLOR = {60/255,60/255,59/255}
local BUTTON_CANCEL_TEXT_COLOR_OVER = {1,1,1}
local BUTTON_CANCEL_BORDER_COLOR = {0.4,0.4,0.4}



local LISTVIEW_ROW_HEIGHT = 50
local LISTVIEW_MINIMUM_ROWS = 3 -- Anything less then lock scrolling and adjust height
local LISTVIEW_ROW_COLORS = {{230/255,230/255,230/255},{1,1,1}}
local LISTVIEW_OVER_COLOR = {233/255,78/255,27/255}
local LISTVIEW_TEXT_COLOR = {102/255,102/255,102/255}
local LISTVIEW_TEXT_COLOR_OVER = {1,1,1}
local LISTVIEW_SELECTOR_SIZE = 8
local LISTVIEW_SELECTOR_STROKE_SIZE = 2
local LISTVIEW_SELECTOR_COLOR = {102/255,102/255,102/255}
local LISTVIEW_SELECTED_SIZE = 6
local LISTVIEW_SELECTED_COLOR = {233/255,78/255,27/255}
local LISTVIEW_DIVIDER_HEIGHT = 1
local LISTVIEW_DIVIDER_COLOR = {172/255,172/255,172/255}

local FILTER_HEIGHT = 50
local FILTER_BORDER_COLOR = {172/255,172/255,172/255}
local BUTTON_CLOSE_GRAPHIC = "graphics/close.png"
local BUTTON_CLOSE_SIZE = 30

local DEFAULT_BUTTON_WIDTH = 180
local DEFAULT_BUTTON_HEIGHT = 35

local DEFAULT_BG_COLOR = {0.9,0.9,0.9}
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local DEFAULT_TITLE_BGCOLOR = {0.4,0.4,0.4}
local DEFAULT_TITLE_COLOR = {1,1,1}
local DEFAULT_MSG_COLOR = {0.35,0.35,0.35}

local DEFAULT_KEY_ADJUST = 50

local function removeNonNumbers(s)
	if (not tonumber(string.sub(s,string.len(s)))) then
		s = string.sub(s, 1, string.len(s) - 1)
	end

	return s
end

function alertBox:show(params)
	local self = display.newGroup()
	
	local strokeWidth = params.strokeWidth or 2
	local width = params.width or DEFAULT_WIDTH
	local font = params.font or DEFAULT_FONT
	local fontSize = params.fontSize or DEFAULT_FONT_SIZE
	local cornerRadius = params.cornerRadius or BUTTON_ACTION_RADIUS_SIZE

	local buttonAlign = params.buttonAlign or "vertical"
	local cancel = params.cancel

	-- ID for whole alert
	self.id = params.id

	self.ids = params.ids

	self.sendCancel = params.sendCancel or false

	self.overlay = display.newRect(self,0,0,display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y

	self.bg = display.newRoundedRect(self,0,0,width,480,5)
	self.bg:setFillColor(unpack(params.bgColor or DEFAULT_BG_COLOR))
	self.bg.strokeWidth = strokeWidth
	self.bg:setStrokeColor(unpack(params.strokeColor or DEFAULT_STROKE_COLOR))
	self.bg.x, self.bg.y = self.x, self.y

	local minY = self.bg.stageBounds.yMin + strokeWidth

	if (params.callback ~= nil and type(params.callback) == "function") then
		self.callback = params.callback
	end

	if (params.title) then
		self.titleBG = display.newRoundedRect( self, 0, 0, self.bg.width - strokeWidth, params.titleHeight or 40,5)
		self.titleBG:setFillColor(unpack(params.titleBGColor or DEFAULT_TITLE_BGCOLOR))
		self.titleBG.x, self.titleBG.y = self.x,self.bg.stageBounds.yMin + self.titleBG.height * 0.5 + strokeWidth * 0.5
		self.title = display.newText(self, params.title, 0,0,font, params.size or 18)
		self.title:setFillColor(unpack(params.color or DEFAULT_TITLE_COLOR))
		self.title.x, self.title.y =  self.titleBG.x, self.titleBG.y
		minY = self.titleBG.stageBounds.yMax
	end

	if (params.subTitle) then
		self.subTitle = display.newText({text = params.subTitle,width = self.bg.width - strokeWidth - PADDING * 2, x = 0, y = 0,font = font, fontSize = 16, align = params.subAlign or "center"})
		self.subTitle:setFillColor(unpack(params.messageColor or DEFAULT_MSG_COLOR))
		self.subTitle.x, self.subTitle.y = self.x, minY + self.subTitle.height * 0.5 + PADDING
		self:insert(self.subTitle)
		minY = self.subTitle.stageBounds.yMax
	end

	if (params.message) then
		self.msg = display.newText({text = params.message,width = self.bg.width - strokeWidth - PADDING * 2, x = 0, y = 0,font = font, fontSize = 14, align = params.messageAlign or "center"})
		self.msg:setFillColor(unpack(params.messageColor or DEFAULT_MSG_COLOR))
		self.msg.x, self.msg.y = self.x, minY + self.msg.height * 0.5 + PADDING
		self:insert(self.msg)
		minY = self.msg.stageBounds.yMax + PADDING
	end

	local function keyEventListener( event )
	   local phase = event.phase
	   local keyName = event.keyName
	   local handled = false
	   
	   if ( "back" == keyName and phase == "up" ) or 
	   ( "a" == keyName and phase == "down" ) then
			if (self) then
				self:dismiss()
				handled = true
			end
	   end

	   return handled
	end

	function self:dismiss()
		Runtime:removeEventListener( "key", keyEventListener )

		self.bg:removeSelf()
		self.bg = nil
		
		self.overlay:removeSelf()
		self.overlay = nil

		if (self.title) then
			self.titleBG:removeSelf()
			self.titleBG = nil
			self.title:removeSelf()
			self.title = nil
		end

		if (self.msg) then
			self.msg:removeSelf()
			self.msg = nil
		end

		if (self.input) then
			native.setKeyboardFocus( nil )
			self.input:removeSelf()
			self.input = nil
		end

		if (self.close) then
			self.close:removeSelf()
			self.close = nil
		end

		if (self.list) then
			self.list:removeSelf()
			self.list = nil

			self.divider:removeSelf()
			self.divider = nil
		end

		if (self.buttons) then
			for i=1,#self.buttons do
				self.buttons[1]:removeSelf()
				table.remove(self.buttons, 1)
			end
			self.buttons = nil
		end

		self:removeSelf()
		self = nil

		_G.alert = nil
		_G.alertBoxes = _G.alertBoxes - 1
	end

	local function handleCallback(event,value)
		if (self.callback) then
			local cbResult = self.callback(event,value)
		end
	end

	self.onEventCallback = function(event)
		if (not event.target or cancel ~= event.target.id or self.sendCancel) then
			local value = nil
			-- NOTE: Might not be the best way, but works for now
			if (self.list) then
				value = event.id
				-- Translate to true index, since we allow filtering now
				for i = 1, #params.list.options do
					if (self.options[value] == params.list.options[i]) then
						value = i
						break
					end
				end
			elseif (self.input) then
				value = self.input.text
			end

			event.id = self.id

			if (self.type and self.type == "number") then
				value = tonumber(value)
			end
			
			if (value == nil) then
				value = ""
			end

			if (self.sendCancel == true and event.target and cancel == event.target.id) then
				event.id = nil
				value = nil
			end

			handleCallback(event,value)
			
		end
		self:dismiss()
	end

	function self:forceClose()
		handleCallback(nil,nil)
		self:dismiss()
	end
	
	self.handleClose = function()
		self:dismiss()
	end

	if (params.close) then
		self.close = display.newImageRect( self, BUTTON_CLOSE_GRAPHIC, BUTTON_CLOSE_SIZE, BUTTON_CLOSE_SIZE )
		self.close.x, self.close.y = self.bg.stageBounds.xMax, self.bg.stageBounds.yMin
		self.close:addEventListener("tap",self.handleClose)
	end

	self.hasFilter = false

	if (params.list and type(params.list) == "table" and params.list.options and #params.list.options > 0) then
		self.options = params.list.options
		self.selected = params.list.selected or 0
		self.radio = true
		if (params.list.radio ~= nil) then
			self.radio = params.list.radio
		end
		
		self.onRowRender = function(event)
			local row = event.row

			local groupContentHeight = row.contentHeight
			local groupContentWidth = row.contentWidth

			local fillColor = LISTVIEW_SELECTOR_COLOR
			local minX = 0

			row.bg = display.newRect(0, 0, groupContentWidth, groupContentHeight)
			row.bg:setFillColor(unpack(LISTVIEW_OVER_COLOR))
			row.bg.x,row.bg.y = groupContentWidth * 0.5, groupContentHeight * 0.5
			row.bg.isVisible = false
			row:insert(row.bg)

			if (self.radio) then
				row.selector = display.newCircle( LISTVIEW_SELECTOR_SIZE * 0.5 + PADDING, groupContentHeight * 0.5, LISTVIEW_SELECTOR_SIZE )
				row:insert(row.selector)
				row.selector.strokeWidth = LISTVIEW_SELECTOR_STROKE_SIZE
				row.selector:setStrokeColor( unpack(fillColor) )
				row.selector:setFillColor(0,0,0,0)
				
				row.selected = display.newCircle( row.selector.x, row.selector.y, LISTVIEW_SELECTED_SIZE )
				row:insert(row.selected)
				row.selected:setFillColor(unpack(LISTVIEW_SELECTED_COLOR))
				row.selected.isVisible = (params.list.options[self.selected] == self.options[row.index])

				minX = row.selector.x + row.selector.width * 0.5
			end

			local textWidth = groupContentWidth - minX - PADDING
			
			row.label = display.newText(row,self.options[row.index], minX + PADDING,groupContentHeight*0.5,font, self.list.fontSize)
			
			if row.label.width > textWidth then
				row.label:removeSelf()
				row.label = display.newText(row,self.options[row.index], minX + PADDING,groupContentHeight*0.5,textWidth,groupContentHeight,font, self.list.fontSize)
			end

			row.label:setFillColor(unpack(LISTVIEW_TEXT_COLOR))
			row.label.anchorX = 0
		end

		self.onRowTouch = function( event )
			local row = event.target

			local rowSelected = false
			local selected = false

			if event.phase == "press" then
				rowSelected = true
		   	elseif event.phase == "release" or event.phase == "tap" then
		      	-- TODO: selected option
		      	selected = true
			elseif event.phase == "swipeLeft" then
			elseif event.phase == "swipeRight" then
			else
		    	-- Cancelled
		   	end
		   	
		   	row.bg.isVisible = rowSelected

		   	if (rowSelected) then
		   		row.label:setFillColor(unpack(LISTVIEW_TEXT_COLOR_OVER))
		   		if (self.radio) then
		   			--row.selected.isVisible = true
		   			row.selector:setStrokeColor(unpack(LISTVIEW_TEXT_COLOR_OVER))
		   		end
		   	else
		   		-- Reset all rows, since there is a bug in regards to touch events
		   		for i=1, self.list:getNumRows() do
		   			local currRow = self.list:getRowAtIndex(i)
		   			if (currRow) then
		   				currRow.label:setFillColor(unpack(LISTVIEW_TEXT_COLOR))
		   				if (self.radio) then
		   					currRow.selector:setStrokeColor(unpack(LISTVIEW_TEXT_COLOR))
		   				end
		   				currRow.bg.isVisible = false
		   			end
		   		end
		   	end

		   	if (selected) then
		   		local id = row.index
		   		if (self.ids and self.ids[row.index]) then
		   			id = self.ids[row.index]
		   		end

		   		self.onEventCallback({id=id})
		   	end
		end

		local rowHeight = params.rowHeight or LISTVIEW_ROW_HEIGHT
		local listRows = params.list.listRows or LISTVIEW_MINIMUM_ROWS

		-- Adjusting for scrolling illusion, since scrollbars are not showing
		local listHeightAdjust = 0
		local locked = #self.options <= listRows
		if (not locked) then
			listHeightAdjust = rowHeight * 0.5
		end

		if (#self.options < LISTVIEW_MINIMUM_ROWS) then
			listRows = #self.options
		end

		self.hasFilter = params.list.hasFilter == true and not locked
		self.filterType = params.list.filterType

		if (self.hasFilter) then
			self.filterBg = display.newRoundedRect(self,0, 0, self.bg.width - strokeWidth - PADDING, FILTER_HEIGHT - PADDING,10 )
			self.filterBg.x, self.filterBg.y = self.x,minY + self.filterBg.height * 0.5 + PADDING * 0.5
			self.filterBg.strokeWidth = 1
			self.filterBg:setStrokeColor(unpack(FILTER_BORDER_COLOR))

			self.filterIcon = display.newImageRect( self, "graphics/search.png", self.filterBg.height - PADDING, self.filterBg.height - PADDING )
			self.filterIcon.x, self.filterIcon.y = self.filterBg.stageBounds.xMax - self.filterIcon.width * 0.5 - PADDING * 0.5, self.filterBg.y
			self.filterIcon:setFillColor(unpack(FILTER_BORDER_COLOR))

			self.filterLabel = display.newText(self, "", 0,0,font, params.size or 14)
			self.filterLabel:setFillColor(unpack(params.color or DEFAULT_TITLE_BGCOLOR))
			self.filterLabel.x, self.filterLabel.y =  self.x, self.y

			minY = self.filterBg.stageBounds.yMax + PADDING * 0.5
		end

		self.list = newWidget.newTableView {
			top = minY,
			height = listRows * rowHeight + listHeightAdjust,
			width = self.bg.width - strokeWidth,
			hideBackground = true,
			onRowRender = self.onRowRender,
			onRowTouch = self.onRowTouch,
			noLines = params.list.noLines or true,
			isLocked = locked
		}
		self:insert(self.list)
		self.list.fontSize = params.list.fontSize or fontSize

		-- insert rows into list (tableView widget)
		for i=1,#self.options do
			self.list:insertRow{
				rowHeight = rowHeight,
				--rowColor = {default=LISTVIEW_ROW_COLORS[(i%2)+1],over=LISTVIEW_OVER_COLOR}
				rowColor = {default=LISTVIEW_ROW_COLORS[(i%2)+1],over=LISTVIEW_ROW_COLORS[(i%2)+1]}
			}
		end
		self.list.x = self.x
		minY = self.list.stageBounds.yMax

		self.divider = display.newRect( self.x, minY, self.list.width, LISTVIEW_DIVIDER_HEIGHT )
		self.divider.anchorY = 0
		self.divider:setFillColor(unpack(LISTVIEW_DIVIDER_COLOR))
		self:insert(self.divider)
		minY = self.divider.stageBounds.yMax

		if (self.selected > listRows) then
			self.list:scrollToIndex(self.selected,0)
		end
	end

	if (params.input or self.hasFilter) then
		self.inputListener = function ( event )
		    if event.phase == "began" then
		    elseif event.phase == "ended" then
		    	native.setKeyboardFocus( nil )
		    elseif event.phase == "submitted" then
		    	native.setKeyboardFocus( nil )
		    elseif event.phase == "editing" then
		    	-- TODO: May have to add an option to allow certain characters (',','.')
		    	if (self.input.type == "filter") then
		    		self.list:deleteAllRows()
		    		local filterLength = string.len(self.input.text)
		    		local textSearch

		    		self.options = {}
		    		local row = 1
		    		for i=1,#params.list.options do
		    			if (filterLength > 0) then
		    				--print (string.sub(string.lower(self.options[i]),1,filterLength)..", "..string.lower(self.input.text))
			    			if (self.filterType == "substring") then
			    				textSearch = string.find(string.lower(params.list.options[i]), string.lower(self.input.text))
			    			else
			    				-- Default to prefix searching
			    				textSearch = string.sub(string.lower(params.list.options[i]),1,filterLength) == string.lower(self.input.text)
			    			end
		    			end
		    			
		    			if ((filterLength == 0) or (filterLength > 0 and textSearch)) then
							table.insert(self.options,params.list.options[i])
							self.list:insertRow{
								rowHeight = rowHeight,
								rowColor = {default=LISTVIEW_ROW_COLORS[(row%2)+1],over=LISTVIEW_OVER_COLOR}
							}
							row = row + 1
						end
					end

					self.filterLabel.text = "No results match \""..self.input.text.."\""
					self.filterLabel.isVisible = #self.options == 0
		    	elseif (self.input.type == "number") then
		    		self.input.text = removeNonNumbers(self.input.text)
		    	end

		    	if (self.input.maxlength and string.len(self.input.text) > self.input.maxlength) then
		    		self.input.text = string.sub( self.input.text, 1, self.input.maxlength )
		    	end
		    end
		end

		local inputWidth = self.bg.width - strokeWidth - PADDING * 2
		local inputX, inputY = self.x, nil

		if (self.hasFilter) then
			-- Manually insert values for a filter
			params.input = {type = "filter", maxlength=20,height = self.filterBg.height - PADDING * 0.5}
			inputWidth = self.filterBg.width - self.filterIcon.width - PADDING * 1.5
			inputY = self.filterBg.y
			inputX = self.filterBg.stageBounds.xMin + PADDING * 0.5 + inputWidth * 0.5
		end

		self.input = native.newTextField(0, 0, inputWidth, params.input.height or DEFAULT_BUTTON_HEIGHT)

		if (inputY == nil) then
			inputY = minY + self.input.height * 0.5 + PADDING
		end

		self.keyAdjust = params.input.keyAdjust or true
		self.input.type = params.input.type or "default"
		self.input.inputType = self.input.type
		self.input.maxlength = params.input.maxlength
		self.input:addEventListener("userInput", self.inputListener)
		self.input.text = params.input.text or ""
		self.input.x, self.input.y = inputX, inputY
		self:insert(self.input)
		self.input.isVisible = false

		if (not self.hasFilter) then
			minY = self.input.stageBounds.yMax
		end
	end

	if (params.buttons and type(params.buttons) == "table" and #params.buttons > 0) then
		local offY = minY + DEFAULT_BUTTON_HEIGHT * 0.5 + PADDING
		
		local offX = self.x
		local buttonWidth = params.buttonWidth or DEFAULT_BUTTON_WIDTH
		local buttonHeight = params.buttonHeight or DEFAULT_BUTTON_HEIGHT

		if (buttonAlign == "horizontal") then
			buttonWidth = (self.bg.width - strokeWidth - (PADDING * (#params.buttons + 1))) / #params.buttons
			offX = self.bg.stageBounds.xMin + strokeWidth * 0.5 + PADDING + buttonWidth * 0.5
		end

		self.buttons = {}

		for i=1,#params.buttons do
			-- Individual id for each button
			local defaultColor = BUTTON_ACTION_BACKGROUND_COLOR
			local overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER
			local strokeColor = BUTTON_ACTION_BORDER_COLOR
			local labelColor = { default=BUTTON_ACTION_TEXT_COLOR, over=BUTTON_ACTION_TEXT_COLOR_OVER }

			local id = i

			if (self.ids) then
				id = self.ids[i]
			end

			if (cancel) then
				if (cancel == i) then
					defaultColor = nil
					overColor = nil
					strokeColor = BUTTON_CANCEL_BORDER_COLOR
					labelColor = { default=BUTTON_CANCEL_TEXT_COLOR, over=BUTTON_CANCEL_TEXT_COLOR_OVER }
				end
			end

			self.buttons[i] = widget.newButton{
				id = id,
				defaultColor = defaultColor,
				overColor = overColor,
				font = font,
				fontSize = fontSize,
				label=params.buttons[i],
				labelColor = labelColor,
				width = buttonWidth,
				height = buttonHeight,
				cornerRadius = cornerRadius,
				strokeColor = strokeColor,
				strokeWidth = BUTTON_ACTION_BORDER_WIDTH,
				onRelease = self.onEventCallback
		   	}
		   	self.buttons[i].x, self.buttons[i].y = offX, offY
		   	self:insert(self.buttons[i])

			if (buttonAlign == "vertical") then
				offY = offY + buttonHeight + PADDING
			else
				offX = offX + buttonWidth + PADDING
			end
		end
		minY = self.buttons[#params.buttons].stageBounds.yMax
	end

	local gap = (self.bg.stageBounds.yMax - minY) - strokeWidth - PADDING
	
	-- TODO: Fix this because there has to be a cleaner method of doing this
	if (gap > PADDING) then
		local kAdjust = 0
		if (self.keyAdjust) then
			kAdjust = DEFAULT_KEY_ADJUST
		end

		self.bg.height = self.bg.height - gap
		self.bg.y = self.y - kAdjust
		if (self.title) then
			self.titleBG.y = self.bg.stageBounds.yMin + self.titleBG.height * 0.5
			self.title.y = self.titleBG.y
		end

		if (self.subTitle) then
			self.subTitle.y = self.subTitle.y + gap * 0.5 - kAdjust
		end
		
		if (self.close) then
			self.close.x, self.close.y = self.bg.stageBounds.xMax, self.bg.stageBounds.yMin
		end

		if (self.msg) then
			self.msg.y = self.msg.y + gap * 0.5 - kAdjust
		end

		if (self.input) then
			self.input.y = self.input.y + gap * 0.5 - kAdjust
		end

		if (self.list) then
			self.list.y = self.list.y + gap * 0.5 - kAdjust
			self.divider.y = self.divider.y + gap * 0.5 - kAdjust
		end

		if (self.filterBg) then
			self.filterBg.y = self.filterBg.y + gap * 0.5 - kAdjust
			self.filterIcon.y = self.filterBg.y
			self.filterLabel.y = self.list.y
		end

		if (self.buttons) then
			for i=1,#self.buttons do
				self.buttons[i].y = self.buttons[i].y + gap * 0.5 - kAdjust
			end
		end
	end

	-- Sometimes button calculations can take time, so we wait to show any previous elements until now (input)
	if (self.input) then
		self.input.isVisible = true
		if (not self.hasFilter) then
			native.setKeyboardFocus( self.input )
		end
	end

	self.touchListener = function(s,event)
		local result = true
		--print ("id: "..self.id)
		--print ("phase: "..event.phase)
		if (event.phase == "ended") then
			--result = self.onRelease(e)

			if (self.list) then
				self.list:reloadData()
			end
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	self.x, self.y = params.x or display.contentCenterX, params.y or display.contentCenterY

	_G.alert = self
	_G.alertBoxes = _G.alertBoxes + 1

	--add the key callback
	Runtime:addEventListener( "key", keyEventListener )
	return self
end

return alertBox