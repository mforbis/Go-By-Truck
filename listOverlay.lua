local widget = require("widget-v1")
local newWidget = require("widget") -- For listview
local SceneManager = require("SceneManager")
local alert = require("alertBox")
local GC = require("AppConstants")
local utils = require("utils")

local PADDING = 10
local FONT = "Oswald"
local DEFAULT_BG_COLOR = {0.9,0.9,0.9}
local DEFAULT_STROKE_COLOR = {0.35,0.35,0.35}
local DEFAULT_TITLE_BGCOLOR = {0.4,0.4,0.4}
local DEFAULT_TITLE_COLOR = {1,1,1}
local BUTTON_ACTION_BACKGROUND_COLOR = {239/255,96/255,40/255}
local BUTTON_ACTION_BACKGROUND_COLOR_OVER = {189/255,63/255,22/255}
local LISTVIEW_SELECTOR_COLOR = {102/255,102/255,102/255}
local LISTVIEW_TEXT_COLOR = {102/255,102/255,102/255}
local LISTVIEW_TEXT_COLOR_OVER = {1,1,1}

local TEXT_HEIGHT = 20

local BUTTON_XOFFSET = 5
local SELECTOR_DEFAULT_WIDTH = 240
local SELECTOR_DEFAULT_HEIGHT = 35

local LIGHT_GRAY2 = {230/255,230/255,230/255}
local MEDIUM_GRAY = {172/255,172/255,172/255}
local DARK_GRAY = {102/255,102/255,102/255}
BUTTON_ACTION_TEXT_COLOR = DARK_GRAY
BUTTON_ACTION_TEXT_COLOR_OVER = WHITE

local LOCATION_TYPE_PICKUP = 11
local LOCATION_TYPE_DROPOFF = 12

local listOverlay = {}

function listOverlay:show(params)
	local self = display.newGroup()

	local oType = params.type

	local strokeWidth = params.strokeWidth or 2
	local width = 300
	local font = "Oswald"
	local fontSize = 18
	local cornerRadius = 4

	local packaging = params.packaging or {}
	local locations = params.locations or {}
	local addressBook = params.addressBook or {}

	local rowHeight = TEXT_HEIGHT * 5 + PADDING
	local label = "no_packaging"
	local options = params.packaging

	local currSelection
	local currRow

	local defaultType

	local callback = nil

	if params.callback and type(params.callback) == "function" then
		callback = params.callback
	end

	self.list = nil
	self.onRowRender = nil
	self.onRowTouch = nil

	if (oType == "locations") then
		options = params.locations
		label = "no_locations"
	elseif (oType == "packaging") then
		if #options > 0 then
			defaultType = options[1].pkgType
		end
	end

	function boolToString(state)
		local str = "no"

		if (state == true) then
			str = "yes"
		end

		return SceneManager.getRosettaString(str)
	end

	local function locationTypeToLabel(lType)
		local label = ""

		if (lType == LOCATION_TYPE_PICKUP) then
			label = "pickup"
		elseif (lType == LOCATION_TYPE_DROPOFF) then
			label = "dropoff"
		end

		if (label ~= "") then label = SceneManager.getRosettaString(label) end

		return label
	end

	local function getListRowOptions()
		return {rowHeight = rowHeight,rowColor = {default={1,1,1},over=LISTVIEW_OVER_COLOR}}
	end

	local function updateState()
		self.label.isVisible = #options == 0
	end

	local function getAddressBookOptions()
		local options = {}

		for i = 1, #addressBook do
			table.insert(options,addressBook[i].alias.." - "..(addressBook[i].address or addressBook[i].address1 or "").." "..(addressBook[i].address2 or ""))
		end

		return options
	end

	local function getAddressBookIDs()
		local ids = {}

		for i = 1, #addressBook do
			table.insert(ids, addressBook[i].addressGuid)
		end

		return ids
	end

	local function getLocationLabelById(id,which)
		local label = SceneManager.getRosettaString("select_"..which.."_location")
		
		for i=1,#locations do
			if (tostring(locations[i].addressGuid) == tostring(id)) then
				label = locations[i].alias.." - "..locations[i].address
				break
			end
		end

		return label
	end

	local function getLocationLabels(locations,which)
		local labels = {"select_"..which.."_location"}

		local lType = LOCATION_TYPE_PICKUP
		if (which == "dropoff") then
			lType = LOCATION_TYPE_DROPOFF
		end

		for i=1,#locations do
			if (locations[i].type == lType) then
				table.insert(labels,locations[i].alias.." - "..locations[i].address1.." "..locations[i].address2.." "..locations[i].city..", "..locations[i].state.." "..locations[i].zip)
			end
		end

		return labels
	end

	local function getLocationOptions(locations,which)
		local options = {""}
		
		local lType = LOCATION_TYPE_PICKUP
		if (which == "dropoff") then
			lType = LOCATION_TYPE_DROPOFF
		end

		for i = 1,#locations do
			if (locations[i].type == lType) then
				table.insert(options,locations[i].addressGuid)
			end
		end

		return options
	end

	local function removeObject()
		table.remove(options, currRow)
		
		--self.list:deleteRow(currRow)
		self.list:deleteAllRows()
		for i = 1, #options do
			self.list:insertRow(getListRowOptions())
		end
		--self.list:reloadData()
		updateState()
	end

	local function removeOnComplete( event )
		local i = event.target.id
		if 1 == i then
			removeObject()
		end
	end

	local function showRemovePrompt()
	    alert:show({
	    	title = SceneManager.getRosettaString("remove"), buttonAlign = "horizontal",
	    	message = SceneManager.getRosettaString("remove_"..oType.."_question"),
	        buttons={SceneManager.getRosettaString("yes"),
	        SceneManager.getRosettaString("no")},
	        callback=removeOnComplete
	    })
	end

	local function locationOnComplete()
		self.list:reloadData()
	end
	
	local function showLocationPopup(location)
		SceneManager.showLocation({data={location=location,addressBook=addressBook},callback=locationOnComplete})		
	end

	local function getAddressBookIndexById(id)
		local index = nil

		for i = 1, #addressBook do
			if (tostring(addressBook[i].addressGuid) == tostring(id)) then
				index = i
				break
			end
		end

		return index
	end

	local function buildAddressFromAddressInfo(addressInfo)
		local address = ""

		address = (addressInfo.address or addressInfo.address1 or "")

		if (addressInfo.address2 and addressInfo.address2 ~= "") then
			address = address.." "..addressInfo.address2
		end

		address = address.." "..addressInfo.city..", "..addressInfo.state.." "..addressInfo.zip

		return address
	end

	local function addLocationOnComplete(event,value)
		local bookIndex = getAddressBookIndexById(value)

		if (bookIndex) then
			table.insert(locations,{})

			locations[#locations].addressGuid = value
			locations[#locations].type = GC.LOCATION_TYPE_PICKUP
			locations[#locations].alias = addressBook[bookIndex].alias
			locations[#locations].address = buildAddressFromAddressInfo(addressBook[bookIndex])
			locations[#locations].startDate = ""
			locations[#locations].stopDate = ""
			locations[#locations].startTime = ""
			locations[#locations].stopTime = ""
			locations[#locations].podRequired = false

			self.list:insertRow(getListRowOptions())
			self.list:reloadData()

			showLocationPopup(locations[#locations])
		else
			-- NOTE: Some kind of error, but should never get here
		end

		updateState()
	end

	local function packageOnComplete()
		self.list:reloadData()
	end

	local function listOptionOnComplete(event,value)
		-- event.id = row index, value = selection
		if (value == 1) then
			if (oType == "packaging") then
				SceneManager.showPackaging({data={package = options[event.id],locations=utils.shallowcopy(locations)},callback=packageOnComplete})
			elseif (oType == "locations") then
				showLocationPopup(locations[event.id])
			end
		elseif (value == 2) then
			-- delete
			currRow = event.id
			showRemovePrompt()
		end
	end

	local function getDateTimeString(dateTime1,dateTime2)
		local strDateTime = "N/A"

		if (dateTime1 and dateTime1 ~= "") then
			strDateTime = dateTime1
		end

		if (dateTime2 and dateTime2 ~= "") then
			if (strDateTime ~= "N/A") then strDateTime = strDateTime.." - "; end
			strDateTime = strDateTime..dateTime2
		end

		return strDateTime
	end

	self.overlay = display.newRect(self,0,0,display.contentWidth,display.contentHeight)
	self.overlay.id = "overlay"
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y

	self.bg = display.newRect(self,0,0,width,400)
	self.bg:setFillColor(unpack(params.bgColor or DEFAULT_BG_COLOR))
	self.bg.strokeWidth = strokeWidth
	self.bg:setStrokeColor(unpack(params.strokeColor or DEFAULT_STROKE_COLOR))
	self.bg.x, self.bg.y = self.x, self.y

	local minY = self.bg.stageBounds.yMin + strokeWidth

	if (params.callback ~= nil and type(params.callback) == "function") then
		self.callback = params.callback
	end

	if (params.title) then
		self.titleBG = display.newRect( self, 0, 0, self.bg.width - strokeWidth, params.titleHeight or 40)
		self.titleBG:setFillColor(unpack(params.titleBGColor or DEFAULT_TITLE_BGCOLOR))
		self.titleBG.x, self.titleBG.y = self.x,self.bg.stageBounds.yMin + self.titleBG.height * 0.5 + strokeWidth * 0.5
		self.title = display.newText(self, params.title, 0,0,font, params.size or 18)
		self.title:setFillColor(unpack(params.color or DEFAULT_TITLE_COLOR))
		self.title.x, self.title.y =  self.titleBG.x, self.titleBG.y
		minY = self.titleBG.stageBounds.yMax
	end

	self.onEventCallback = function(event)
		if (event.target.id == "add") then
			if (oType == "packaging") then
				table.insert( packaging, {} )
				if (#packaging > 1) then
					-- Copy values from previous to here
					packaging[#packaging].pkgType = packaging[1].pkgType
					packaging[#packaging].pkgValue = 0
					packaging[#packaging].pkgPickup = packaging[1].pkgPickup
					packaging[#packaging].pkgDropoff = packaging[1].pkgDropoff
				else
					packaging[#packaging].pkgType = defaultType or GC.PACKAGING_OPTIONS[1]
					packaging[#packaging].pkgValue = 0
				end
				self.list:insertRow(getListRowOptions())
				self.list:reloadData()
			elseif (oType == "locations") then
				if (#addressBook > 0) then
					alert:show({
						title = SceneManager.getRosettaString("add_a_location"),width=self.list.width,
	            		list = {options = getAddressBookOptions(),radio = false,fontSize=14},ids = getAddressBookIDs(),
	            		buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
	            		callback=addLocationOnComplete
	            	})
	            else
	            	alert:show({
				    	title = SceneManager.getRosettaString("no_locations"),
				    	message = SceneManager.getRosettaString("no_locations_addressbook_message"),
				        buttons={SceneManager.getRosettaString("ok")}
				    })
	            end
			end
			updateState()
		elseif (event.target.id == "done") then
			-- TODO: Update packaging/locations based on what is in the table, since
			-- it will be too complicated to keep track of adding/deleting, etc...
			if (callback) then callback(); end
			self:dismiss()
		end
	end

	self.btnAdd = widget.newButton{
		id = "add",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("add",1),xOffset = 10,
		labelColor = { default={1,1,1}, over={1,1,1} },
		icon = {default="graphics/plus.png",width=15,height=15,align="left"},
		width = 120,
		height = 35,
		cornerRadius = 4,
		strokeColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		strokeWidth = 1,
		onRelease = self.onEventCallback
	}
	self.btnAdd.x, self.btnAdd.y = self.x - self.btnAdd.width * 0.5 - PADDING, self.bg.stageBounds.yMax - self.btnAdd.height * 0.5 - PADDING
	self:insert(self.btnAdd)

	self.btnDone = widget.newButton{
		id = "done",
		defaultColor = BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = font,
		fontSize = 18,
		label=SceneManager.getRosettaString("done",1),
		labelColor = { default={1,1,1}, over={1,1,1} },
		width = 120,
		height = 35,
		cornerRadius = 4,
		strokeColor = BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		strokeWidth = 1,
		onRelease = self.onEventCallback
	}
	self.btnDone.x, self.btnDone.y = self.x + self.btnAdd.width * 0.5 + PADDING, self.btnAdd.y
	self:insert(self.btnDone)

	self.divider = display.newRect( self.x, self.btnAdd.stageBounds.yMin - PADDING, self.bg.width - 2, 2 )
	self.divider:setFillColor(172/255,172/255,172/255)
	self:insert(self.divider)

	self.label = display.newText(self, SceneManager.getRosettaString(label), 0,0,font, 20)
	self.label:setFillColor(0.4,0.4,0.4)
	self.label.x, self.label.y =  self.x,self.y
	self:insert(self.label)

	updateState()

	self.onRowRender = function(event)
		local row = event.row

		local groupContentHeight = row.contentHeight
		local groupContentWidth = row.contentWidth

		local rowCenterY = groupContentHeight * 0.5
		local rowCenterX = groupContentWidth * 0.5
		local halfWidth = (groupContentWidth - (PADDING * 3)) * 0.5
		local minX, maxX = PADDING, groupContentWidth - PADDING

		row.elements = {}

		local option = options[row.index]
		local index = 1
		
		local function addTextElement(params)
		   	local yAdjust = 0
		   	local align = params.align or "left"

			if params.multiline then
		    	row.elements[index] = display.newText( {text = params.text, x=0,y=0,width = self.list.width - PADDING * 2,font=params.font or APP_FONT, fontSize = params.size or 14, align=align} )
		    	yAdjust = row.elements[index].height * 0.5
		    	-- If from an option, try to align it with the box
		    	if (params.yOffset) then
		        	yAdjust = yAdjust - params.yOffset
		    	end
			else
				row.elements[index] = display.newText({text = params.text,x=0,y=0,font=APP_FONT,fontSize = params.size or 14, align=align})
			end
			row:insert(row.elements[index])
			if (align == "left") then
				row.elements[index].anchorX = 0
			elseif (align == "right") then
				row.elements[index].anchorX = 1
			end
			row.elements[index].x, row.elements[index].y = params.x,params.y + yAdjust
			row.elements[index]:setFillColor(unpack(params.color or DARK_GRAY))
		end

		local row1 = TEXT_HEIGHT * 0.5 + PADDING * 0.5

		if (oType == "packaging") then
			addTextElement({text=SceneManager.getRosettaString("type")..": "..option.pkgType,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY})
   			index = index + 1
   			addTextElement({text=SceneManager.getRosettaString("quantity")..": "..option.pkgValue,x=maxX,y=row1,yOffset = 0,align="right",color=DARK_GRAY})
   			row1 = row.elements[index].y + row.elements[index].height * 0.5 + PADDING * 0.5
   			index = index + 1
   			addTextElement({text=SceneManager.getRosettaString("pickup")..": "..getLocationLabelById(option.pkgPickup,"pickup"),multiline=true,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY})
   			index = index + 1
   			addTextElement({text=SceneManager.getRosettaString("dropoff")..": "..getLocationLabelById(option.pkgDropoff,"dropoff"),multiline=true,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY})	
			row.elements[index].y = groupContentHeight - row.elements[index].height * 0.5 - PADDING * 0.5
   		elseif (oType == "locations") then
			addTextElement({text=SceneManager.getRosettaString("type")..": "..locationTypeToLabel(option.type),x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY})
   			index = index + 1
   			addTextElement({text=SceneManager.getRosettaString("pod_required")..": "..boolToString(option.podRequired),x=maxX,y=row1,yOffset = 0,align="right",color=DARK_GRAY})
   			row1 = row.elements[index].y + row.elements[index].height * 0.5 + PADDING * 0.5
   			index = index + 1
   			addTextElement({group=row,element = row.elements[index],text=SceneManager.getRosettaString("address")..": "..getLocationLabelById(option.addressGuid,"pickup"),multiline=true,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY})
   			
   			row1 = groupContentHeight - TEXT_HEIGHT * 0.5 - PADDING * 0.5
   			index = index + 1
   			local strValue = getDateTimeString(option.startTime,option.stopTime)
   			addTextElement({text=SceneManager.getRosettaString("arrival_times")..": "..strValue,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY,size=12})
   			
   			row1 = row.elements[index].y - row.elements[index].height * 0.5 - PADDING
   			index = index + 1
   			local strValue = getDateTimeString(option.startDate,option.stopDate)
   			addTextElement({text=SceneManager.getRosettaString("arrival_dates")..": "..strValue,x=minX,y=row1,yOffset = 0,align="left",color=DARK_GRAY,size=12})
   		end

		if (#options > 1 and row.index < #options) then
			index = index + 1
			row.elements[index] = display.newRect(0, 0, groupContentWidth, 1)
			row.elements[index]:setFillColor(unpack(DARK_GRAY))
			row.elements[index].x, row.elements[index].y = rowCenterX, groupContentHeight - 1
			row:insert(row.elements[index])
		end
	end

	self.onRowTouch = function( event )
		local row = event.target
		local rowPressed, rowSelected = false, false
		local textColor

		if event.phase == "press" then
			rowPressed = true
	   	elseif event.phase == "release" then
	      	-- TODO: selected option
	      	rowSelected = true
		elseif event.phase == "swipeLeft" then
		elseif event.phase == "swipeRight" then
		else
	    	-- Cancelled
	   	end

	   	for i=1,#row.elements do
			textColor = row.elements[i].color or DARK_GRAY
			if (rowPressed) then
				textColor = row.elements[i].overColor or DARK_GRAY
			end
			row.elements[i]:setFillColor(unpack(textColor))
		end

	   	if (rowSelected) then
	   		local id = row.index
	   		
	   		alert:show({title = SceneManager.getRosettaString("select_option"),id=row.index,
            list = {options = {SceneManager.getRosettaString("edit"),SceneManager.getRosettaString("delete")},radio = false,fontSize=16},
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=listOptionOnComplete})
	   	end
	end

	self.list = newWidget.newTableView {
		top = minY,
		height = 300,--listRows * rowHeight,
		width = self.bg.width - strokeWidth,
		hideBackground = true,
		onRowRender = self.onRowRender,
		onRowTouch = self.onRowTouch,
		noLines = true,
		--isLocked = #self.options <= LISTVIEW_MINIMUM_ROWS
	}
	self:insert(self.list)

	self.list.fontSize = fontSize

	for i=1,#options do
		self.list:insertRow(getListRowOptions())
	end
	self.list.x = self.x

	function self:dismiss()
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

		self.label:removeSelf()
		self.label = nil

		self.list:removeSelf()
		self.list = nil

		self.btnAdd:removeSelf()
		self.btnAdd = nil

		self.btnDone:removeSelf()
		self.btnDone = nil

		self.divider:removeSelf()
		self.divider = nil

		self:removeSelf()
		self = nil

		_G.customOverlay = nil
	end

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

	if (params.group) then
		params.group:insert(self)
	end
	
	local function hide()
		self:dismiss()
	end

	local function showComplete()
		_G.customOverlay = hide
	end

	return self
end

return listOverlay
