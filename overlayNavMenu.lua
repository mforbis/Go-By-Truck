local newWidget = require("widget")
local widget = require("widget-v1")
local GC = require("AppConstants")

local navMenu = {}

local PADDING = 10

local DEFAULT_WIDTH = display.contentWidth - PADDING * 4
local DEFAULT_FONT = "Open Sans Light"
local DEFAULT_FONT_SIZE = 20
local LISTVIEW_ROW_HEIGHT = 45
local LISTVIEW_MINIMUM_ROWS = 3 -- Anything less then lock scrolling and adjust height
local LISTVIEW_ROW_COLORS = {GC.DARK_GRAY2,GC.DARK_GRAY2}
local LISTVIEW_OVER_COLOR = {233/255,78/255,27/255}
local LISTVIEW_TEXT_COLOR = GC.COLOR_GRAY
local LISTVIEW_TEXT_COLOR_OVER = GC.COLOR_GRAY
local LISTVIEW_SELECTOR_SIZE = 8
local LISTVIEW_SELECTOR_STROKE_SIZE = 2
local LISTVIEW_SELECTOR_COLOR = {102/255,102/255,102/255}
local LISTVIEW_SELECTED_SIZE = 6
local LISTVIEW_SELECTED_COLOR = {233/255,78/255,27/255}
local LISTVIEW_DIVIDER_HEIGHT = 1
local LISTVIEW_DIVIDER_COLOR = {172/255,172/255,172/255}

local DEFAULT_BG_COLOR = GC.DARK_GRAY2
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local DEFAULT_TITLE_BGCOLOR = {0.4,0.4,0.4}
local DEFAULT_TITLE_COLOR = {1,1,1}

local ANIMATION_TIME_MS = 150

function navMenu:show(params)
	local self = display.newGroup()
	
	local strokeWidth = params.strokeWidth or 2
	local width = params.width or DEFAULT_WIDTH
	local font = params.font or DEFAULT_FONT
	local fontSize = params.fontSize or DEFAULT_FONT_SIZE
	local cornerRadius = params.cornerRadius or BUTTON_ACTION_RADIUS_SIZE

	self.id = params.id

	self.ids = params.ids

	self.options = params.options
	self.selected = params.selected or 0
	self.radio = true
	
	self.sendCancel = false

	self.callback = nil

	if (params.callback ~= nil and type(params.callback) == "function") then
		self.callback = params.callback
	end

	local maxX = self.x - PADDING * 2 - 1
	local minX = -width - PADDING * 2

	self.overlay = display.newImageRect(self,"graphics/1x1.png",display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay.x, self.overlay.y = self.x, self.y

	local function showDone()
		self.menu.isVisible = true
	end

	self.show = function()
		self.tween = transition.to(self.list,{x = maxX, time = ANIMATION_TIME_MS, onComplete = showDone})
		self.tween2 = transition.to(self.shadow,{alpha = 0.2, time = ANIMATION_TIME_MS})
	end

	local function hideDone()
		self:dismiss()
		_G.toolsMenu = nil
	end

	self.hide = function()
		self.menu.isVisible = false
		self.tween = transition.to(self.list,{x = minX, time = ANIMATION_TIME_MS, onComplete = hideDone})
		self.tween2 = transition.to(self.shadow,{alpha = 0, time = ANIMATION_TIME_MS})
	end

	local function handleCallback(event,value)
		if (self.callback) then
			local cbResult = self.callback(event,value)
		end
	end

	self.onEventCallback = function(event)
		if (not event.target or cancel ~= event.target.id or self.sendCancel) then
			local value = nil
			
			value = event.id or ""
			
			event.id = self.id

			handleCallback(event,value)
		end
		self.hide()
	end

	-- TODO: This should show by default, but hide the overlay until shown
	-- then do the animation. This requires the object to be created only once per scene needed
	self.menu = widget.newButton{
      id = "menu",
      defaultColor = GC.DASHBOARD_BAR_BUTTON_DEFAULT_COLOR,
      overColor = GC.DASHBOARD_BAR_BUTTON_OVER_COLOR,
      labelColor = {default = GC.MEDIUM_GRAY, over = GC.DARK_GRAY},
      icon = {default="graphics/navicon.png",width=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,height=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,matchTextColor=true},
      width = GC.DASHBOARD_BAR_BUTTON_WIDTH,
      height = GC.DASHBOARD_BAR_BUTTON_HEIGHT,
      cornerRadius = 0,
      strokeWidth = 0,
      onRelease = self.hide
	}
	_G.toolsMenu = self
	--self.menu.x, self.menu.y = self.overlay.stageBounds.xMin + self.menu.width * 0.5 + PADDING, self.overlay.stageBounds.yMin + self.menu.height * 0.5 + PADDING 
	self.menu.x, self.menu.y = self.overlay.stageBounds.xMin + GC.DASHBOARD_BAR_BUTTON_PADDING + self.menu.width * 0.5, self.overlay.stageBounds.yMin + GC.HEADER_HEIGHT * 0.5
	--self.menu.isVisible = false
	self:insert(self.menu)

	self.radio = false

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
			row.selected.isVisible = (params.options[self.selected] == self.options[row.index])

			minX = row.selector.x + row.selector.width * 0.5
		end

		local textWidth = groupContentWidth - minX - PADDING
		
		row.label = display.newText(row,self.options[row.index], minX + PADDING,groupContentHeight*0.5,font, fontSize)
		
		if row.label.width > textWidth then
			row.label:removeSelf()
			row.label = display.newText(row,self.options[row.index], minX + PADDING,groupContentHeight*0.5,textWidth,groupContentHeight,font, self.list.fontSize)
		end

		row.label:setFillColor(unpack(LISTVIEW_TEXT_COLOR))
		row.label.anchorX = 0

		--if (#self.options > 1 and row.index < #self.options) then
			row.divider = display.newRect(row,0,0,row.width,1)
			row.divider:setFillColor(unpack(GC.DARK_GRAY))
			row.divider.x, row.divider.y = groupContentWidth * 0.5, groupContentHeight - 1
		--end
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
	   	
	   	if (row.bg) then
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
	end

	local rowHeight = params.rowHeight or LISTVIEW_ROW_HEIGHT
	local listRows = params.listRows or LISTVIEW_MINIMUM_ROWS

	-- Adjusting for scrolling illusion, since scrollbars are not showing
	local listHeightAdjust = 0
	local listHeight = display.contentHeight - GC.HEADER_HEIGHT
	local locked = listHeight > (rowHeight * #self.options)
	
	self.shadow = display.newRect(0,0,display.contentWidth,listHeight)
	self:insert(self.shadow)

	self.shadow:setFillColor(0,0,0)
	self.shadow.alpha = 0
	self.shadow.x, self.shadow.y = self.x, self.overlay.stageBounds.yMin + GC.HEADER_HEIGHT + listHeight * 0.5

	if (#self.options < LISTVIEW_MINIMUM_ROWS) then
		listRows = #self.options
	end

	--self.bg = display.newRect(self,0,0,width,display.contentHeight - GC.HEADER_HEIGHT)
	--self.bg:setFillColor(unpack(params.bgColor or DEFAULT_BG_COLOR))
	--self.bg.strokeWidth = strokeWidth
	--self.bg:setStrokeColor(unpack(params.strokeColor or DEFAULT_STROKE_COLOR))
	--self.bg.x, self.bg.y = minX, self.overlay.stageBounds.yMin + self.bg.height * 0.5 + GC.HEADER_HEIGHT
	--local minY = self.bg.stageBounds.yMin

	
	self.list = newWidget.newTableView {
		top = self.overlay.stageBounds.yMin + GC.HEADER_HEIGHT,
		height = listHeight,
		width = width - strokeWidth,
		backgroundColor = params.bgColor or DEFAULT_BG_COLOR,
		onRowRender = self.onRowRender,
		onRowTouch = self.onRowTouch,
		noLines = params.noLines or true,
		isLocked = locked
	}
	self:insert(self.list)
	self.list.fontSize = params.fontSize or fontSize

	-- insert rows into list (tableView widget)
	for i=1,#self.options do
		self.list:insertRow{
			rowHeight = rowHeight,
			--rowColor = {default=LISTVIEW_ROW_COLORS[(i%2)+1],over=LISTVIEW_OVER_COLOR}
			rowColor = {default=LISTVIEW_ROW_COLORS[(i%2)+1],over=LISTVIEW_ROW_COLORS[(i%2)+1]}
		}
	end
	self.list.x = minX

	function self:dismiss()
		self.overlay:removeSelf()
		self.overlay = nil

		self.menu:removeSelf()
		self.menu = nil

		self.list:removeSelf()
		self.list = nil

		self.shadow:removeSelf()
		self.shadow = nil

		self:removeSelf()
		self = nil
	end

	self.touchListener = function(s,event)
		local result = true
		--print ("id: "..self.id)
		--print ("phase: "..event.phase)
		if (event.phase == "ended" and event.y > GC.HEADER_HEIGHT) then
			--result = self.onRelease(e)

			self.hide()
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	self.x, self.y = params.x or display.contentCenterX, params.y or display.contentCenterY

	self.show()

	return self
end

return navMenu