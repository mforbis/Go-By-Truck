local widget = require("widget-v1")
local widgetNew = require("widget")
local SceneManager = require("SceneManager")

--[[
1.0 - Initial Version
]]--

local shipperInfo = {}

local PADDING = 10
local SIDE_PADDING = 5
local LINE_HEIGHT = 10
local LINE_ADJUST = 5
local SPACE = 5
local ROUNDED_SIZE = 7

-- colors
local LIGHT_GRAY = {228/255,228/255,228/255}
local MEDIUM_GRAY = {172/255,172/255,172/255}
local MEDIUM_GRAY2 = {102/255,102/255,102/255}
local DARK_GRAY = {68/255,68/255,68/255}
local GREEN = {136/255,187/255,0}
local ORANGE = {239/255,96/255,40/255}
local RED = {1,0,0}

local STROKE_WIDTH = 1
local STROKE_COLOR = LIGHT_GRAY

local DEFAULT_WIDTH = 300
local DEFAULT_HEIGHT = 360
local DEFAULT_FONT = "Oswald" -- native.systemFont
local DEFAULT_FONT_SIZE = 18
local HEADER_HEIGHT = 40
local DIVIDER_HEIGHT = 1
local BUTTON_ACTION_TEXT_COLOR = {1,1,1}
local BUTTON_ACTION_TEXT_COLOR_OVER = {1,1,1}
local BUTTON_ACTION_BACKGROUND_COLOR = {233/255,78/255,27/255}
local BUTTON_ACTION_BACKGROUND_COLOR_OVER = {189/255,63/255,22/255}
local BUTTON_ACTION_BORDER_COLOR = {189/255,63/255,22/255}
local BUTTON_ACTION_RADIUS_SIZE = 4
local BUTTON_CANCEL_TEXT_COLOR = {60/255,60/255,59/255}
local BUTTON_CANCEL_TEXT_COLOR_OVER = {1,1,1}
local BUTTON_CANCEL_BORDER_COLOR = {60/255,60/255,59/255}

local DEFAULT_BUTTON_WIDTH = 180
local DEFAULT_BUTTON_HEIGHT = 35

local DEFAULT_BG_COLOR = {235/255,235/255,235/255}
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local DEFAULT_TITLE_BGCOLOR = {0.4,0.4,0.4}
local DEFAULT_TITLE_COLOR = {1,1,1}
local DEFAULT_MSG_COLOR = {0.35,0.35,0.35}

local DEFAULT_KEY_ADJUST = 50

function shipperInfo:show(params)
	local self = display.newGroup()
	
	local strokeWidth = 2
	local showDetails = params.showDetails or false

	self.overlay = display.newRect(self,0,0,display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y

	self.bg = display.newRect(self,0,0,DEFAULT_WIDTH,DEFAULT_HEIGHT)
	self.bg:setFillColor(unpack(DEFAULT_BG_COLOR))
	self.bg.strokeWidth = strokeWidth
	self.bg:setStrokeColor(unpack(DEFAULT_STROKE_COLOR))
	self.bg.x, self.bg.y = self.x, self.y

	local minY = self.bg.stageBounds.yMin + strokeWidth

	self.titleBG = display.newRect( self, 0, 0, self.bg.width - strokeWidth, HEADER_HEIGHT)
	self.titleBG:setFillColor(unpack(DEFAULT_TITLE_BGCOLOR))
	self.titleBG.x, self.titleBG.y = self.x,self.bg.stageBounds.yMin + self.titleBG.height * 0.5 + strokeWidth * 0.5
	self.title = display.newText(self, SceneManager.getRosettaString("shipper_profile"), 0,0,DEFAULT_FONT, 18)
	self.title:setFillColor(unpack(DEFAULT_TITLE_COLOR))
	self.title.x, self.title.y =  self.titleBG.x, self.titleBG.y
	minY = self.titleBG.stageBounds.yMax
	
	self.scrollView = widgetNew.newScrollView
	{
	  left     = 0,
	  top      = 0,
	  width    = self.bg.width,
	  height   = DEFAULT_HEIGHT - HEADER_HEIGHT - DEFAULT_BUTTON_HEIGHT - DIVIDER_HEIGHT - PADDING * 2,
	  hideBackground = true,
	  bottomPadding  = 20,
	  horizontalScrollDisabled   = true
	}
	self.scrollView.anchorY = 0
	self.scrollView.x, self.scrollView.y = self.x, self.titleBG.stageBounds.yMax
	self:insert(self.scrollView)

	minY = self.scrollView.stageBounds.yMax

	self.divider = display.newRect( self.x, minY, self.scrollView.width - strokeWidth, 1 )
	self.divider.anchorY = 0
	self.divider:setFillColor(unpack(MEDIUM_GRAY))
	self:insert(self.divider)
	minY = self.divider.stageBounds.yMax

	self.elements = {}
	local yOffset = 0
	local currElement

	local function nextLine(previous)
	   if (not previous) then
	      yOffset = yOffset + LINE_HEIGHT
	   else
	      yOffset = previous.y + previous.height * 0.5 + LINE_HEIGHT
	   end
	end

	local function nextElement()
	   currElement = #self.elements + 1
	end

	local function getElementById(id)
		for i = 1, #self.elements do
			if (self.elements[i].id == id) then
				return self.elements[i]
			end
		end
	end

	local function adjustSectionHeight(id,element)
   		local section = getElementById(id)
	   	local h = (element.stageBounds.yMax - section.stageBounds.yMin) + PADDING
	   	
	   	local yAdjust = (h - section.height) * 0.5
	   	section.height = h
	   	section.y = section.y + yAdjust
   	end

	local elementWidth = self.scrollView.width - PADDING * 2
	local centerX = self.scrollView.width * 0.5

	nextElement()
	nextLine()

	local infoHeight = 50
	if (showDetails) then
		infoHeight = 140
	end

	self.elements[currElement] = display.newRoundedRect(0,0,elementWidth,infoHeight,ROUNDED_SIZE)
	self.elements[currElement].id = "company_information"
	self.elements[currElement]:setFillColor(1,1,1)
	self.elements[currElement].strokeWidth = STROKE_WIDTH
	self.elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
	self.elements[currElement].x, self.elements[currElement].y = centerX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	local minX = SIDE_PADDING + PADDING
	local maxX = self.scrollView.width - PADDING - SIDE_PADDING
	local halfWidth = (elementWidth - SIDE_PADDING * 3) * 0.5
	local midX = minX + halfWidth + SIDE_PADDING

	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("company_information"),font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(DARK_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.companyStatusName,font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(DARK_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = maxX - self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])
	
	nextLine(self.elements[currElement])
	nextElement()

	self.elements[currElement] = display.newRect(0,0,elementWidth - PADDING * 2, 1)
	self.elements[currElement]:setFillColor(unpack(LIGHT_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = centerX,yOffset - LINE_ADJUST
	self.scrollView:insert(self.elements[currElement])

	if (showDetails) then
		-- TODO: Add support for showDetails that will display details of company
	end

	nextElement()
	nextLine(getElementById("company_information"))

	self.elements[currElement] = display.newRoundedRect(0,0,elementWidth,140,ROUNDED_SIZE)
	self.elements[currElement].id = "gbt_application_information"
	self.elements[currElement]:setFillColor(1,1,1)
	self.elements[currElement].strokeWidth = STROKE_WIDTH
	self.elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
	self.elements[currElement].x, self.elements[currElement].y = centerX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("gbt_application_information"),font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(DARK_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement])
	nextElement()

	self.elements[currElement] = display.newRect(0,0,elementWidth - PADDING * 2, 1)
	self.elements[currElement]:setFillColor(unpack(LIGHT_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = centerX,yOffset - LINE_ADJUST
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("member_since")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.memberSince,font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = maxX - self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	local secondColumnX = maxX - self.elements[currElement].width

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("num_shipments_transported")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()
	
	self.elements[currElement] = display.newText({text=params.loadsThroughGbt,font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].anchorX = 0
	self.elements[currElement].x, self.elements[currElement].y = secondColumnX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("num_disputes")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()
	
	self.elements[currElement] = display.newText({text=params.disputes,font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].anchorX = 0
	self.elements[currElement].x, self.elements[currElement].y = secondColumnX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("tonu")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()
	
	self.elements[currElement] = display.newText({text=params.tonu,font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].anchorX = 0
	self.elements[currElement].x, self.elements[currElement].y = secondColumnX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("most_recent_note")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()
	
	self.elements[currElement] = display.newText({text="Testing out how to handle notes that are included. Now to add a second or more line.",font=DEFAULT_FONT,fontSize = 12,width=elementWidth - SIDE_PADDING * 2,align="center"})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = centerX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	adjustSectionHeight("gbt_application_information",self.elements[currElement])

	nextElement()
	nextLine(getElementById("gbt_application_information"))

	self.elements[currElement] = display.newRoundedRect(0,0,elementWidth,140,ROUNDED_SIZE)
	self.elements[currElement].id = "shipper_feedback_profile"
	self.elements[currElement]:setFillColor(1,1,1)
	self.elements[currElement].strokeWidth = STROKE_WIDTH
	self.elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
	self.elements[currElement].x, self.elements[currElement].y = centerX, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipper_feedback_profile"),font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(DARK_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement])
	nextElement()

	self.elements[currElement] = display.newRect(0,0,elementWidth - PADDING * 2, 1)
	self.elements[currElement]:setFillColor(unpack(LIGHT_GRAY))
	self.elements[currElement].x, self.elements[currElement].y = centerX,yOffset - LINE_ADJUST
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipper_feedback_score"),font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	local color = utils.getFeedbackScoreColor(params.feedbackScore)

	self.elements[currElement] = display.newText({text=params.feedbackScore.."%",font=DEFAULT_FONT,fontSize = 16})
	self.elements[currElement]:setFillColor(unpack(color))
	self.elements[currElement].x, self.elements[currElement].y = (minX + self.elements[currElement-1].width) + self.elements[currElement].width * 0.5 + SPACE, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	local adjust = centerX - ((self.elements[currElement-1].width + self.elements[currElement].width + SPACE) * 0.5)
	
	self.elements[currElement-1].x = adjust + self.elements[currElement-1].width * 0.5
	self.elements[currElement].x = self.elements[currElement-1].x + self.elements[currElement-1].width * 0.5 + self.elements[currElement].width * 0.5 + SPACE
	
	nextLine(self.elements[currElement])
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipper_feedback_area1")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	local scoreWidth = elementWidth / 3

	self.elements[currElement] = display.newText({text=params.q1Satisfied.."%\n"..SceneManager.getRosettaString("satisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(GREEN))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q1Neutral.."%\n"..SceneManager.getRosettaString("neutral"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(ORANGE))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q1Unsatisfied.."%\n"..SceneManager.getRosettaString("unsatisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(RED))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth * 2, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipper_feedback_area2")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	local scoreWidth = elementWidth / 3

	self.elements[currElement] = display.newText({text=params.q2Satisfied.."%\n"..SceneManager.getRosettaString("satisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(GREEN))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q2Neutral.."%\n"..SceneManager.getRosettaString("neutral"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(ORANGE))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q2Unsatisfied.."%\n"..SceneManager.getRosettaString("unsatisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(RED))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth * 2, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	self.elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipper_feedback_area3")..":",font=DEFAULT_FONT,fontSize = 14})
	self.elements[currElement]:setFillColor(unpack(MEDIUM_GRAY2))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextLine(self.elements[currElement]);yOffset = yOffset - LINE_HEIGHT
	nextElement()

	local scoreWidth = elementWidth / 3

	self.elements[currElement] = display.newText({text=params.q3Satisfied.."%\n"..SceneManager.getRosettaString("satisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(GREEN))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q3Neutral.."%\n"..SceneManager.getRosettaString("neutral"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(ORANGE))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	nextElement()

	self.elements[currElement] = display.newText({text=params.q3Unsatisfied.."%\n"..SceneManager.getRosettaString("unsatisfied"),font=DEFAULT_FONT,fontSize = 12,width=scoreWidth})
	self.elements[currElement]:setFillColor(unpack(RED))
	self.elements[currElement].x, self.elements[currElement].y = minX + self.elements[currElement].width * 0.5 + scoreWidth * 2, yOffset + self.elements[currElement].height * 0.5
	self.scrollView:insert(self.elements[currElement])

	adjustSectionHeight("shipper_feedback_profile",self.elements[currElement])

	function self:dismiss()
		self.overlay:removeSelf()
		self.overlay = nil

		self.titleBG:removeSelf()
		self.titleBG = nil
		self.title:removeSelf()
		self.title = nil

      self.divider:removeSelf()
      self.divider = nil

		self.close:removeSelf()
		self.close = nil

      for i=1,#self.elements do
         self.elements[1]:removeSelf()
         table.remove(self.elements,1)
      end
      
		self.scrollView:removeSelf()
		self.scrollView = nil

		self:removeSelf()
		self = nil

		_G.customOverlay = nil
	end

	local function handleClose()
		self:dismiss()
	end

	local offY = minY + DEFAULT_BUTTON_HEIGHT * 0.5 + PADDING
		
	self.close = widget.newButton{
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = DEFAULT_FONT,
		fontSize = DEFAULT_FONT_SIZE,
		label=SceneManager.getRosettaString("close"),
		labelColor = { default=BUTTON_ACTION_TEXT_COLOR, over=BUTTON_ACTION_TEXT_COLOR_OVER },
		width = DEFAULT_BUTTON_WIDTH,
		height = DEFAULT_BUTTON_HEIGHT,
		cornerRadius = cornerRadius,
		strokeColor = BUTTON_ACTION_BORDER_COLOR,
		strokeWidth = BUTTON_ACTION_BORDER_WIDTH,
		onRelease = handleClose
   	}
   	self.close.x, self.close.y = self.x, offY
   	self:insert(self.close)

	minY = self.close.stageBounds.yMax

	self.x, self.y = params.x or display.contentCenterX, params.y or display.contentCenterY

	local function showComplete()
		_G.customOverlay = handleClose
	end

	return self
end

return shipperInfo