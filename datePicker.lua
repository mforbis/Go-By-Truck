local widget = require("widget-v1")

local DEFAULT_FONT = "Oswald"

local PADDING = 5

-- TODO: Base future calls on calendar.lua

local DEFAULT_BG_COLOR = {0.9,0.9,0.9}
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local DEFAULT_HEADER_COLOR = {0.8,0.8,0.8}
local DEFAULT_HEADER_BORDER_COLOR = {0.4,0.4,0.4}
local DEFAULT_HEADER_STROKE_WIDTH = 1
local DEFAULT_HEADER_HEIGHT = 40
local DEFAULT_TITLE_BGCOLOR = {0.4,0.4,0.4}
local DEFAULT_TITLE_COLOR = {1,1,1}
local DEFAULT_TITLE_HEIGHT = 40
local DEFAULT_RADIUS_SIZE = 4
local DEFAULT_STROKE_WIDTH = 1

local DAYS_TEXT_COLOR = {0.4,0.4,0.4}
local BUTTON_ACTION_TEXT_COLOR = {1,1,1}
local BUTTON_ACTION_TEXT_COLOR_OVER = {0.8,0.8,0.8}
local BUTTON_ACTION_BACKGROUND_COLOR = {233/255,78/255,27/255}
local BUTTON_ACTION_BACKGROUND_COLOR_OVER = {189/255,63/255,22/255}
local BUTTON_ACTION_BORDER_COLOR = {189/255,63/255,22/255}
local BUTTON_ACTION_RADIUS_SIZE = 4
local BUTTON_ACTION_SIZE = 34

local DATE_NORMAL_BG_COLOR = {0.8,0.8,0.8}
local DATE_NORMAL_STROKE_COLOR = {0.4,0.4,0.4}
local DATE_NORMAL_TEXT_COLOR = {0.4,0.4,0.4}
local DATE_NORMAL_TEXT_COLOR_OVER = {0.4,0.4,0.4}
local DATE_TODAY_BG_COLOR = {252/255,250/255,241/255}
local DATE_TODAY_STROKE_COLOR = {252/255,239/255,161/255}
local DATE_TODAY_TEXT_COLOR = {0,0,0}
local DATE_TODAY_TEXT_COLOR_OVER = {0,0,0}
local DATE_DISABLED_BG_COLOR = {249/255,249/255,249/255}
local DATE_DISABLED_STROKE_COLOR = {240/255,240/255,240/255}
local DATE_DISABLED_TEXT_COLOR = {195/255,195/255,195/255}
local DATE_DISABLED_TEXT_COLOR_OVER = {195/255,195/255,195/255}

local CELL_BORDER_SIZE = 1
local CELL_GAP = 1

local DAYS_IN_WEEK = 7
local DAYS = {"SU","MO","TU","WE","TH","FR","SA"}

-- Assumes format yyyy/mm/dd
local function makeTimeStamp(dateString)
    if (dateString == nil) then return nil; end
    local pattern = "(%d+)%/(%d+)%/(%d+)"
    local year, month, day = dateString:match(pattern)

    if (year and month and day) then
        return os.time({year = year, month = month, day = day})
    end

    return nil
end

local datePicker = {}

function datePicker:new(options)
	local self = display.newGroup()

	local today = os.date("*t",os.time())
	local selectPast = true

	if options and not options.selectPast == true or options and not options.selectPast or options and options.selectPast == false then
		selectPast = false
	end

	local width = options.width or 296
	local height = options.height or 400
	local borderSize = options.borderSize or DEFAULT_RADIUS_SIZE
	local strokeWidth = options.strokeWidth or DEFAULT_STROKE_WIDTH
	local font = options.font or DEFAULT_FONT

	local callback = nil

	if options.callback and type(options.callback) == "function" then
		callback = options.callback
	end

	local function isToday(date)
   		return (today.month == date.month and today.day == date.day and today.year == date.year)
   	end

	self.overlay = display.newRect(self,0,0,display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y

	self.bg = display.newRoundedRect(self,0,0,width,height,borderSize)
	self.bg:setFillColor(unpack(options.bgColor or DEFAULT_BG_COLOR))
	self.bg.strokeWidth = strokeWidth
	self.bg:setStrokeColor(unpack(options.strokeColor or DEFAULT_STROKE_COLOR))
	self.bg.x, self.bg.y = self.x, self.y

	self.header = display.newRoundedRect( 0, 0, self.bg.width - PADDING * 2, DEFAULT_HEADER_HEIGHT, borderSize )
	self.header:setFillColor(unpack(DEFAULT_HEADER_COLOR))
	self.header.strokeWidth = DEFAULT_HEADER_STROKE_WIDTH
	self.header:setStrokeColor(unpack(DEFAULT_HEADER_BORDER_COLOR))
	self.header.x, self.header.y = self.x, self.bg.stageBounds.yMin + self.header.height * 0.5 + strokeWidth + PADDING
	self:insert(self.header)

	self.titleBG = display.newRect(self, 0, 0, self.header.width - PADDING * 4 - BUTTON_ACTION_SIZE * 2, DEFAULT_TITLE_HEIGHT)
	self.titleBG:setFillColor(unpack(DEFAULT_TITLE_BGCOLOR))
	self.titleBG.x, self.titleBG.y = self.x, self.header.y

	self.title = display.newText({text="September 2014",font=font,fontSize=24})
	self.title.x, self.title.y = self.titleBG.x, self.titleBG.y
	self:insert(self.title)

   	local cellSize = (self.header.width / DAYS_IN_WEEK)
   	
   	self.elements = {}
   	local index = #self.elements + 1
   	local xOff, yOff = self.header.stageBounds.xMin + cellSize * 0.5, self.header.stageBounds.yMax + cellSize * 0.5
   	for i=1,DAYS_IN_WEEK do
   		self.elements[index] = display.newText({text=DAYS[i],font=font,fontSize = 16,x=xOff,y=yOff,width=cellSize,align="center",height=cellSize})
   		self.elements[index]:setFillColor(unpack(DAYS_TEXT_COLOR))
   		self:insert(self.elements[index])
   		xOff = xOff + cellSize
   		index = index + 1
   	end

   	-- Borders affect width. Think divs
   	cellSize = (self.header.width - (CELL_BORDER_SIZE * DAYS_IN_WEEK * 2) - (CELL_GAP * (DAYS_IN_WEEK - 1))) / DAYS_IN_WEEK

   	self.calendar = display.newRect( 0, 0, self.header.width, cellSize * 5 + (CELL_BORDER_SIZE * 5 * 2) + (CELL_GAP * 4))
   	self.calendar.x, self.calendar.y = self.x, self.elements[1].stageBounds.yMax + self.calendar.height * 0.5
   	self:insert(self.calendar)

   	self.days = {}

   	function self:removeDays()
   		for i=1,#self.days do
   			self.days[1]:removeSelf()
   			table.remove(self.days,1)
   		end
   		--print ("length: "..#self.days)
   	end

   	local function sameMonth(month)
   		local currMonth = os.date("*t",os.time()).month

   		return currMonth == month
   	end

   	function self:update()
   		self:removeDays()

		local time = self.firstTimeStamp
		local date = os.date("*t",time)
		local currMonth = date.month
		local day = 1
		
   		local minX = self.header.stageBounds.xMin + cellSize * 0.5 + CELL_GAP
		local xOff, yOff = minX + ((date.wday - 1) * (cellSize + CELL_BORDER_SIZE * 2 + CELL_GAP)),self.calendar.stageBounds.yMin + cellSize * 0.5 + CELL_GAP
		
		if (not selectPast and sameMonth(date.month)) then
   			self.previous.alpha = 0.5
   			self.previous:disable()
   		end

		while date.month == currMonth do
			local bgColor = DATE_NORMAL_BG_COLOR
			local strokeColor = DATE_NORMAL_STROKE_COLOR
			local labelColor = { default=DATE_NORMAL_TEXT_COLOR, over=DATE_NORMAL_TEXT_COLOR_OVER }

			if (isToday(date)) then
				bgColor = DATE_TODAY_BG_COLOR
				strokeColor = DATE_TODAY_STROKE_COLOR
				labelColor = {default=DATE_TODAY_TEXT_COLOR, over=DATE_TODAY_TEXT_COLOR_OVER}
			end

			local labelAlign = options.align or "center"
			local xOffset = 0

			if (labelAlign == "left") then
				xOffset = 5
			elseif (labelAlign == "right") then
				xOffset = -5
			end

			self.days[day] = widget.newButton {
				id = day,
				defaultColor = bgColor,
				overColor = {1,1,1},
				labelColor = labelColor,
				label = day,
				labelAlign=labelAlign,xOffset = xOffset,
				width = cellSize,
				height = cellSize,
				cornerRadius = 0,
				strokeColor = strokeColor,
				strokeWidth = 1,
				onRelease = self.onEventCallback
		   	}
		   	self.days[day].x, self.days[day].y = xOff,yOff
		   	self:insert(self.days[day])
			
			xOff = xOff + cellSize + CELL_BORDER_SIZE * 2 + CELL_GAP
			if (date.wday % DAYS_IN_WEEK == 0) then
				xOff = minX
				yOff = yOff + cellSize + CELL_BORDER_SIZE * 2 + CELL_GAP
			end
			
			day = day + 1
			time = time + 86400
			date = os.date("*t",time)
		end 		
   	end

   	-- Ex: 09/02/2014
	local function formatNumber(num)
	   return string.format("%02d",tostring(num))
	end

	local function buildProperDate(date)
	   return formatNumber(date.month).."/"..formatNumber(date.day).."/"..date.year
	end

   	function self:setTimeStamp(stamp)
   		print ("stamp: "..stamp)
   		self.currTimeStamp = stamp

   		self.date = os.date("*t",stamp)
   		print (self.date.month,self.date.day,self.date.year)
   		self.firstTimeStamp = stamp - ((self.date.day - 1) * 86400)
   		self.firstDay = os.date("*t",self.firstTimeStamp)
   	end

   	--local currTimeStamp = os.time()
	--local currDate = os.date("*t",currTimeStamp)
	--local firstTimeStamp = currTimeStamp - ((currDate.day - 1) * 86400)
	--local firstDay = os.date("*t",firstTimeStamp)

	function self:dismiss()
		self.bg:removeSelf()
		self.bg = nil
		
		self.overlay:removeSelf()
		self.overlay = nil

		self.header:removeSelf()
		self.header = nil

		self.titleBG:removeSelf()
		self.titleBG = nil

		self.title:removeSelf()
		self.title = nil

		self.previous:removeSelf()
		self.previous = nil

		self.next:removeSelf()
		self.next = nil

		self.btnCancel:removeSelf()
		self.btnCancel = nil

		self:removeDays()

		for i = 1, #self.elements do
			self.elements[1]:removeSelf()
			table.remove(self.elements,1)
		end
		self.elements = nil

		self.calendar:removeSelf()
		self.calendar = nil

		_G.customOverlay = nil
	end

	self.onEventCallback = function(event)
		if (event.target.id == "cancel") then
			self:dismiss()
		elseif (event.target.id == "next") then
			self.date.month = self.date.month + 1
			self:update()
		elseif (event.target.id == "clear") then
			if (callback) then callback({id=id,time = ""}) end
			self:dismiss()
		elseif (event.target.id == "done") then
			if (callback) then callback({id=id,time = getElementById("lblTime").text}) end
			self:dismiss()
		end
	end

	self.previous = widget.newButton{
		id = "previous",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		labelColor = { default=BUTTON_ACTION_TEXT_COLOR, over=BUTTON_ACTION_TEXT_COLOR_OVER },
		icon = {default="graphics/leftArrow.png",width=30,height=30,matchTextColor=true},
      	width = BUTTON_ACTION_SIZE,
		height = BUTTON_ACTION_SIZE,
		cornerRadius = BUTTON_ACTION_RADIUS_SIZE,
		strokeColor = BUTTON_ACTION_BORDER_COLOR,
		strokeWidth = BUTTON_ACTION_BORDER_WIDTH,
		onRelease = self.onEventCallback
   	}
   	self.previous.x, self.previous.y = self.header.stageBounds.xMin + self.previous.width * 0.5 + PADDING, self.header.y
   	self:insert(self.previous)
   	
   	self.next = widget.newButton{
		id = "next",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		labelColor = { default=BUTTON_ACTION_TEXT_COLOR, over=BUTTON_ACTION_TEXT_COLOR_OVER },
		icon = {default="graphics/rightArrow.png",width=30,height=30,matchTextColor=true,hideWhenDisabled=false},
      	width = BUTTON_ACTION_SIZE,
		height = BUTTON_ACTION_SIZE,
		cornerRadius = BUTTON_ACTION_RADIUS_SIZE,
		strokeColor = BUTTON_ACTION_BORDER_COLOR,
		strokeWidth = BUTTON_ACTION_BORDER_WIDTH,
		onRelease = self.onEventCallback
   	}
   	self.next.x, self.next.y = self.header.stageBounds.xMax - self.previous.width * 0.5 - PADDING, self.header.y
   	self:insert(self.next)

	self.btnCancel = widget.newButton {
		id = "cancel",
		defaultColor = nil,
		overColor = nil,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("cancel"),
		labelColor = { default={60/255,60/255,59/255}, over=BUTTON_TEXT_COLOR_OVER },
		width = BUTTON_WIDTH,
		height = BUTTON_HEIGHT,
		cornerRadius = 4,
		strokeColor = {60/255,60/255,59/255},
		strokeWidth = 1,
		onRelease = self.onEventCallback
	}
	self.btnCancel.x, self.btnCancel.y = self.x, self.bg.y + self.bg.height * 0.5 - self.btnCancel.height * 0.5 - PADDING * 2
	self:insert(self.btnCancel)

	-- TODO: Maybe change this to some kind of date param instead
	self:setTimeStamp(makeTimeStamp(options.date) or os.time())

	self:update()

	self.touchListener = function(s,event)
		local result = true
		--print ("id: "..self.id)
		--print ("phase: "..event.phase)
		if (event.phase == "ended") then
			--result = self.onRelease(e)
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	self.x, self.y = options.x or display.contentCenterX, options.y or display.contentCenterY

	local function hide()
		self:dismiss()
	end

	local function showComplete()
		_G.customOverlay = hide
	end

	return self
end

return datePicker