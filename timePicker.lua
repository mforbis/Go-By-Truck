local widget = require("widget-v1")
local utils = require("utils")
local GC = require("AppConstants")
local SceneManager = require("SceneManager")
local alert = require("alertBox")
local slider = require("slider")

local PADDING = 10
local SPACE = 5
local DEFAULT_SLIDER_WIDTH = 140

local DEFAULT_BG_COLOR = {0.9,0.9,0.9}
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 35
local ADJUST_BUTTON_SIZE = 30
local BUTTON_ACTION_BACKGROUND_COLOR = nil
local BUTTON_ACTION_BACKGROUND_COLOR_OVER = nil
local BUTTON_TEXT_COLOR = {60/255,60/255,59/255}
local BUTTON_TEXT_COLOR_OVER = {1,1,1}
local BUTTON_BORDER_COLOR = {60/255,60/255,59/255}
local BUTTON_XOFFSET = 5

local timePicker = {}

function timePicker:show(params)
	local self = display.newGroup()

	local TIME_ZONE_LABELS = {"Eastern","Central","Mountain","Pacific"}
	local TIME_ZONE_VALUES = {"EST","CST","MST","PST"}

	if (params.time == "") then params.time = nil end
	local time = utils.splitTime(params.time or "12:00 am CST")
	local id = params.id or ""

	local callback = nil

	if params.callback and type(params.callback) == "function" then
		callback = params.callback
	end

	self.elements = {}
	local index = nil

	self.overlay = display.newRect(self,0,0,display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y

	self.bg = display.newRect(self,0,0,display.contentWidth - PADDING * 2,280)
	self.bg:setFillColor(1,1,1)
	self.bg.strokeWidth = strokeWidth
	self.bg:setStrokeColor(unpack(DEFAULT_STROKE_COLOR))
	self.bg.x, self.bg.y = self.x, self.y

	self.titleBG = display.newRect( self, 0, 0, self.bg.width, 35 )
   	self.titleBG:setFillColor(unpack(GC.DARK_GRAY2))
   	self.titleBG.x, self.titleBG.y = self.x, self.bg.stageBounds.yMin + self.titleBG.height * 0.5

   	self.title = display.newText(self, SceneManager.getRosettaString("choose_time"), 0, 0, GC.SCREEN_TITLE_FONT, 18)
	self.title.x, self.title.y = self.titleBG.x, self.titleBG.y

	local function getElementIndexById(id)
	   	for i = 1, #self.elements do
	    	if (self.elements[i].id == id) then
	        	return i
	      	end
	   	end
	   	return -1
	end

	local function getElementById(id)
   		return self.elements[getElementIndexById(id)]
	end

	local function updateTimeLabel()
		getElementById("lblTime").text = utils.formatTime(time)
	end
	
	local function hourToSlider()
		local slider = time.hour
		if (tostring(slider) == "12") then slider = 0 end

		if (time.amPm == "pm") then
			slider = slider + 12
		end

		return tonumber(slider)
	end

	local function sliderToHour(slider)
		if (slider < 12) then
			time.amPm = "am"
			time.hour = slider
		else
			time.amPm = "pm"
			time.hour = slider - 12
		end

		if (tostring(time.hour) == "0") then time.hour = 12 end

		updateTimeLabel()
	end

	local function updateSlider(event)
		if (event.id == "hour") then
			sliderToHour(event.value)
		elseif (event.id == "minute") then
			time.minute = event.value
		end
		updateTimeLabel()
	end

	local function onHourMinus()
		local currHour = self.sliderHour:getValue()
		if (currHour > 0) then
			self.sliderHour:setValue(currHour-1)
		end
	end

	local function onHourPlus()
		local currHour = self.sliderHour:getValue()
		if (currHour < 23) then
			self.sliderHour:setValue(currHour+1)
		end
	end

	local function onMinuteMinus()
		local currMinute = self.sliderMinute:getValue()
		if (currMinute > 0) then
			self.sliderMinute:setValue(currMinute-1)
		end
	end

	local function onMinutePlus()
		local currMinute = self.sliderMinute:getValue()
		if (currMinute < 59) then
			self.sliderMinute:setValue(currMinute+1)
		end
	end

	function nextElement()
		index = #self.elements + 1
	end

	local function selectorSetLabel(selector)
		local label = selector.labels[1]

		if (selector.value ~= nil) then
		  	for i=1,#selector.options do
				if (tostring(selector.value) == tostring(selector.options[i])) then
		        	label = selector.labels[i]
		        	break
		     	end
		  	end
		end

		selector:setLabel(label)
	end

	local function selectorSetValue(selector,value)
		selector.value = selector.options[value]
		selectorSetLabel(selector)

		if (selector.id == "timeZone") then
			time.tz = selector.value
			updateTimeLabel()
		end
		--print ("selector: id = "..selector.id..", value: "..tostring(selector.value))
	end

	local function selectionOnComplete(event,value)
   		if (currSelection) then
      		selectorSetValue(currSelection,value)
   		end
	end

	local function selectorGetOptionIndex(value,options)
		local index = 0

		for i=1,#options do
	  		if (tostring(value) == tostring(options[i])) then
	    		index = i
	  		end
		end
		return index
	end

	local function selectorGetLabels(labels)
		local options = {}

		for i=1,#labels do
	  		table.insert( options, labels[i] )
		end

		return options
	end

	local function showSelections(event)
	  	if (event.phase == "release") then
			if (event.target.id) then
				currSelection = event.target
				alert:show({title = SceneManager.getRosettaString(event.target.title or "select_option"),id=event.target.id,
				list = {options = selectorGetLabels(event.target.labels),selected = selectorGetOptionIndex(event.target.value,event.target.options),fontSize=event.target.fontSize or 16},
				buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
				callback=selectionOnComplete})
			end
	  	end
	end

	local function addSelector(params)
		local size = params.size or 18

		nextElement()

		self.elements[index] = widget.newButton {
			id = params.id,
			overColor = LIGHT_GRAY2,
			font = FONT,
			fontSize = size,
			label="",labelAlign="left",xOffset = BUTTON_XOFFSET,
			labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
			width = params.width or SELECTOR_DEFAULT_WIDTH,
			height = params.height or SELECTOR_DEFAULT_HEIGHT,
			icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
			labelColor = { default=GC.DARK_GRAY, over=GC.DARK_GRAY }, fontSize = 14, font = FONT,
			cornerRadius = 4, strokeColor = GC.MEDIUM_GRAY,
			strokeWidth = 1, onEvent = showSelections
		}

		self.elements[index].value = params.value
		self.elements[index].options = params.options
		self.elements[index].labels = params.labels
		self.elements[index].fontSize = params.fontSize

		self.elements[index].x, self.elements[index].y = params.x, params.y + self.elements[index].height * 0.5
		selectorSetLabel(self.elements[index])

		if (params.enabled == false) then
	  		self.elements[index]:disable()
		end

		self:insert(self.elements[index])
	end

	local function addTextElement(params)
		nextElement()
		local yAdjust = 0
		local align = params.align or "left"

		if params.multiline then
		  	self.elements[index] = display.newText( {text = params.text, x=0,y=0,width = bg.width - PADDING * 2,font=params.font or APP_FONT, fontSize = params.size or 14, align=align} )
		  	yAdjust = elements[index].height * 0.5
		  	-- If from an option, try to align it with the box
		  	if (params.yOffset) then
		    	yAdjust = yAdjust - params.yOffset
		  	end
		else
			self.elements[index] = display.newText({text = params.text,x=0,y=0,font=APP_FONT,fontSize = params.size or 14, align=align})
		end

		self:insert(self.elements[index])

	   	if (align == "left") then
	      	self.elements[index].anchorX = 0
	   	elseif (align == "right") then
			self.elements[index].anchorX = 1
	   	end
	   	self.elements[index].x, self.elements[index].y = params.x,params.y + yAdjust
	   	self.elements[index]:setFillColor(0,0,0)
	end

	local function onNow()
		local current = utils.luaTimeToTable(os.date("%X"))
		current.hour = tonumber(current.hour)
		
		if (current.hour > 12) then
			time.hour = current.hour - 12
			current.amPm = "pm"
		else
			current.amPm = "am"
			time.hour = current.hour
		end

		time.hour = current.hour
		time.minute = current.minute

		self.sliderHour:setValue(current.hour)
		self.sliderMinute:setValue(time.minute)

		time.amPm = current.amPm
		updateTimeLabel()
	end

	local minX = self.x - self.bg.width * 0.5 + PADDING
	local x2 = minX + 70
	local yOffset = self.titleBG.y + self.titleBG.height * 0.5 + PADDING * 2

	addTextElement({text=SceneManager.getRosettaString("time"),x=minX,y=yOffset,align="left",color=GC.DARK_GRAY})
	addTextElement({text=utils.formatTime(time),x=x2,y=yOffset,align="left",color=GC.DARK_GRAY})
	self.elements[index].id = "lblTime"

	yOffset = self.elements[index].stageBounds.yMax + PADDING * 3

	addTextElement({text=SceneManager.getRosettaString("hour"),x=minX,y=yOffset,align="left",color=GC.DARK_GRAY})
	
	self.sliderHour = slider.newSlider({ 
		track = "graphics/slider/track.png",
		thumbDefault = "graphics/slider/thumb.png",
		thumbOver = "graphics/slider/thumbDrag.png",
		id = "hour",
		onChange	= updateSlider,
		trackDefaultSizeW = DEFAULT_SLIDER_WIDTH,
		trackDefaultSizeH = 20,
		thumbDefaultSizeW = 30,
		thumbDefaultSizeH = 30,
		value=hourToSlider(),
		minValue = 0,
		maxValue = 23,
		isInteger = true,
		snapToInteger = false,
		showTickMarks = true
	})
	
	self.sliderHour.x = x2 + DEFAULT_SLIDER_WIDTH * 0.5 - 10
	self.sliderHour.y = yOffset
	self:insert(self.sliderHour)

	nextElement()

	self.elements[index] = widget.newButton{
		id = "hour+",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label="+",
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = ADJUST_BUTTON_SIZE,
		height = ADJUST_BUTTON_SIZE,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = onHourPlus
	}
	self.elements[index].x, self.elements[index].y = self.x + self.bg.width * 0.5 - self.elements[index].width * 0.5 - PADDING, yOffset
	self:insert(self.elements[index])

	nextElement()

	self.elements[index] = widget.newButton{
		id = "hour-",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label="-",
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = ADJUST_BUTTON_SIZE,
		height = ADJUST_BUTTON_SIZE,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = onHourMinus
	}
	self.elements[index].x, self.elements[index].y = self.elements[index-1].x - self.elements[index-1].width * 0.5 - ADJUST_BUTTON_SIZE * 0.5 - PADDING, yOffset
	self:insert(self.elements[index])

	yOffset = self.elements[index].stageBounds.yMax + PADDING * 4

	addTextElement({text=SceneManager.getRosettaString("minute"),x=minX,y=yOffset,align="left",color=GC.DARK_GRAY})
	
	self.sliderMinute = slider.newSlider({ 
		track = "graphics/slider/track.png",
		thumbDefault = "graphics/slider/thumb.png",
		thumbOver = "graphics/slider/thumbDrag.png",
		id = "minute",
		onChange	= updateSlider,
		trackDefaultSizeW = DEFAULT_SLIDER_WIDTH,
		trackDefaultSizeH = 20,
		thumbDefaultSizeW = 30,
		thumbDefaultSizeH = 30,
		value=tonumber(time.minute),
		minValue = 0,
		maxValue = 59,
		isInteger = true,
		snapToInteger = false,
		showTickMarks = true
	})
	
	self.sliderMinute.x = x2 + DEFAULT_SLIDER_WIDTH * 0.5 - 10
	self.sliderMinute.y = yOffset
	self:insert(self.sliderMinute)

	nextElement()

	self.elements[index] = widget.newButton{
		id = "minute+",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label="+",
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = ADJUST_BUTTON_SIZE,
		height = ADJUST_BUTTON_SIZE,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = onMinutePlus
	}
	self.elements[index].x, self.elements[index].y = self.x + self.bg.width * 0.5 - self.elements[index].width * 0.5 - PADDING, yOffset
	self:insert(self.elements[index])

	nextElement()

	self.elements[index] = widget.newButton{
		id = "minute-",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label="-",
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = ADJUST_BUTTON_SIZE,
		height = ADJUST_BUTTON_SIZE,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = onMinuteMinus
	}
	self.elements[index].x, self.elements[index].y = self.elements[index-1].x - self.elements[index-1].width * 0.5 - ADJUST_BUTTON_SIZE * 0.5 - PADDING, yOffset
	self:insert(self.elements[index])

	yOffset = self.elements[index].stageBounds.yMax + PADDING * 3

	addTextElement({text=SceneManager.getRosettaString("time_zone"),x=minX,y=yOffset,align="left",color=GC.DARK_GRAY})
	
	addSelector({id="timeZone",width=120,height=BUTTON_HEIGHT,value=time.tz,options=TIME_ZONE_VALUES,labels=TIME_ZONE_LABELS,x=30,y=yOffset - BUTTON_HEIGHT * 0.5})

	function self:dismiss()
		self.bg:removeSelf()
		self.bg = nil
		
		self.overlay:removeSelf()
		self.overlay = nil

		self.titleBG:removeSelf()
		self.titleBG = nil

		self.title:removeSelf()
		self.title = nil

		self.btnNow:removeSelf()
		self.btnNow = nil

		self.btnClear:removeSelf()
		self.btnClear = nil

		self.btnDone:removeSelf()
		self.btnDone = nil

		self.sliderHour:removeSelf()
		self.sliderHour = nil

		self.sliderMinute:removeSelf()
		self.sliderMinute = nil

		self.divider:removeSelf()
		self.divider = nil

		for i = 1, #self.elements do
			self.elements[1]:removeSelf()
			table.remove(self.elements,1)
		end
		self.elements = nil

		self:removeSelf()
		self = nil

		_G.customOverlay = nil
	end

	self.onEventCallback = function(event)
		if (event.target.id == "now") then
		elseif (event.target.id == "clear") then
			if (callback) then callback({id=id,time = ""}) end
			self:dismiss()
		elseif (event.target.id == "done") then
			if (callback) then callback({id=id,time = getElementById("lblTime").text}) end
			self:dismiss()
		end
	end

	self.btnNow = widget.newButton{
		id = "now",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("now"),
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = BUTTON_WIDTH,
		height = BUTTON_HEIGHT,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = onNow
	}
	self.btnNow.x, self.btnNow.y = self.x - self.bg.width * 0.5 + self.btnNow.width * 0.5 + PADDING, self.bg.stageBounds.yMax - self.btnNow.height * 0.5 - PADDING
	self:insert(self.btnNow)

	self.btnClear = widget.newButton{
		id = "clear",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("clear"),
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = BUTTON_WIDTH,
		height = BUTTON_HEIGHT,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = self.onEventCallback
	}
	self.btnClear.x, self.btnClear.y = self.x, self.btnNow.y
	self:insert(self.btnClear)

	self.btnDone = widget.newButton{
		id = "done",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("done"),
		labelColor = { default=BUTTON_TEXT_COLOR, over=BUTTON_TEXT_COLOR_OVER },
		width = BUTTON_WIDTH,
		height = BUTTON_HEIGHT,
		cornerRadius = 4,
		strokeColor = BUTTON_BORDER_COLOR,
		strokeWidth = 1,
		onRelease = self.onEventCallback
	}
	self.btnDone.x, self.btnDone.y = self.x + self.bg.width * 0.5 - self.btnDone.width * 0.5 - PADDING, self.btnNow.y
	self:insert(self.btnDone)

	self.divider = display.newRect(0,0,self.bg.width - PADDING,1)
	self.divider:setFillColor(unpack(GC.DARK_GRAY2))
	self.divider.x, self.divider.y = self.x, self.bg.y + self.bg.height * 0.5 - BUTTON_HEIGHT - PADDING * 2
	self:insert(self.divider)

	self.touchListener = function(s,event)
		local result = true
		--print ("id: "..self.id)
		--print ("phase: "..event.phase)
		if (event.phase == "ended") then
			--result = self.onRelease(e)

			if (self.list) then
				--self.list:reloadData()
			end
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	self.x, self.y = params.x or display.contentCenterX, params.y or display.contentCenterY

	local function hide()
		self:dismiss()
	end

	local function showComplete()
		_G.customOverlay = hide
	end

	return self
end

return timePicker