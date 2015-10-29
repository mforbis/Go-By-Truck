local widget = require("widget-v1")
local alert = require("alertBox")
local GC = require("AppConstants")
local SceneManager = require("SceneManager")
local utils = require("utils")
local api = require("api")

local overlayFundShipment = {}

local PADDING = 10
local TIME_TO_SCALE_MS = 200
local OVER_COLOR = {0.75,0.75,0.75}

function overlayFundShipment:new(params)
	local self = display.newGroup()

	local quoteId = params.quoteId
	local fromCityState = params.fromCityState
	local toCityState = params.toCityState
	local quoteAmount = params.quoteAmount
	local gbtBalance = params.gbtBalance
	local loadIdGuid = params.loadIdGuid
	local fundedAmount = params.fundedAmount
	local amountToFund = quoteAmount - fundedAmount
	local isNoCCFees = params.isNoCCFees
	local ccFeePct = (params.ccFeePct or 0) / 100
	local options = params.options or {}

	local callback = nil
	if (params.callback and type(params.callback) == "function") then
		callback = params.callback
	end

	-- Testing
	if (_G.beta and loadIdGuid == 0) then
		quoteId = 330
		fromCityState = "Springfield, MO"
		toCityState = "Springfield, MO"
		isNoCCFees = false
		gbtBalance = 300--623
		fundedAmount = 300
		amountToFund = quoteAmount - fundedAmount
		ccFeePct = 2.59 / 100
		loadIdGuid = 414
		local json = require("json")
		options = json.decode('[{"id":334,"label":"Jefferys American Express | ...0005 | AMERICAN EXPRESS"},{"id":336,"label":"Jefferys 2nd American Express | ...8431 | AMERICAN EXPRESS"},{"id":335,"label":"Jefferys Visa.......................... | ...1111 | VISA"}]')
	end

	self.overlay = display.newRect(0,0,display.contentWidth,display.contentHeight)
	self.overlay:setFillColor(0,0,0,0.5)
	self.overlay.x, self.overlay.y = self.x, self.y
	self:insert(self.overlay)

	self.bg = display.newRect(0,0,self.overlay.width - PADDING, self.overlay.height - PADDING)
	self.bg:setFillColor(245/255,245/255,245/255)
	self.bg.x, self.bg.y = self.x, self.y
	self:insert(self.bg)

	self.titleBG = display.newRect(0,0,self.bg.width,35)
	self.titleBG.x, self.titleBG.y = self.x, self.bg.stageBounds.yMin + self.titleBG.height * 0.5
	self.titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
	self:insert(self.titleBG)

	self.title = display.newText(SceneManager.getRosettaString("fund_your_shipment"),0,0,GC.APP_FONT,18)
	self.title.x, self.title.y = self.titleBG.x, self.titleBG.y
	self:insert(self.title)

	local elementWidth = self.bg.width - PADDING * 2

	self.message = display.newText({
		text = SceneManager.getRosettaString("fund_your_shipment_message")..":"..quoteId..".  ("..fromCityState.." to "..toCityState..")",
		x=0,y=0,
		width=elementWidth,
		font=GC.APP_FONT,fontSize=12,
		align="left"
	})
	self.message.x, self.message.y = self.x, self.titleBG.stageBounds.yMax + self.message.height * 0.5 + PADDING * 0.5
	self.message:setFillColor(unpack(GC.DARK_GRAY))
	self:insert(self.message)

	self.box = display.newRect(0, 0, elementWidth, 100)
   	self.box.strokeWidth = 1
   	self.box:setStrokeColor(unpack(GC.ORANGE))
   	self.box.x, self.box.y = self.x, self.message.stageBounds.yMax + self.box.height * 0.5 + PADDING * 0.5
   	self:insert(self.box)

   	self.boxTitle = display.newText(SceneManager.getRosettaString("payment_summary"),0,0,GC.APP_FONT,14)
   	self.boxTitle:setFillColor(unpack(GC.DARK_GRAY))
	self.boxTitle.x, self.boxTitle.y = self.x, self.box.stageBounds.yMin + self.boxTitle.height * 0.5
	self:insert(self.boxTitle)

	self.quoteAmount = display.newText(SceneManager.getRosettaString("quote_amount"),0,0,GC.APP_FONT,14)
	self.quoteAmount:setFillColor(unpack(GC.DARK_GRAY))
	self.quoteAmount.x, self.quoteAmount.y = self.x, self.boxTitle.stageBounds.yMax

	local COLORS = {{245/255,245/255,246/255},{1,1,1}}

	self.innerBoxes = {}
	self.innerLabels = {}
	self.innerAmounts = {}

	local INNER_HEIGHT = 25
	local yOffset = self.boxTitle.stageBounds.yMax + INNER_HEIGHT * 0.5 + PADDING

	local innerLabels = {"quote_amount","funded_amount","credit_card_fees","grand_total"}
	local innerAmounts = {quoteAmount,fundedAmount,0,amountToFund}

	for i=1,4 do
		self.innerBoxes[i] = display.newRect(0,0,self.box.width - PADDING * 2,INNER_HEIGHT)
		self.innerBoxes[i]:setFillColor(unpack(COLORS[(i%2)+1]))
		self.innerBoxes[i].x, self.innerBoxes[i].y = self.x, yOffset
		self:insert(self.innerBoxes[i])

		self.innerLabels[i] = display.newText(SceneManager.getRosettaString(innerLabels[i])..":",0,0,GC.APP_FONT,13)
		self.innerLabels[i].anchorX = 1
		self.innerLabels[i].x, self.innerLabels[i].y = self.innerBoxes[i].stageBounds.xMax - 90, yOffset
		self.innerLabels[i]:setFillColor(unpack(GC.DARK_GRAY))
		self:insert(self.innerLabels[i])

		local color = GC.DARK_GRAY
		local label = "$"..utils.formatMoney(innerAmounts[i])

		if (i == 2) then
			label = "("..label..")"
		elseif (i == 4) then
			color = GC.LIGHT_GREEN
		end

		self.innerAmounts[i] = display.newText(label,0,0,GC.APP_FONT,13)
		self.innerAmounts[i].anchorX = 1
		self.innerAmounts[i].x, self.innerAmounts[i].y = self.innerBoxes[i].stageBounds.xMax - PADDING, yOffset
		self.innerAmounts[i]:setFillColor(unpack(color))
		self:insert(self.innerAmounts[i])

		yOffset = yOffset + INNER_HEIGHT
	end

	self.innerDivider = display.newRect(0,0,self.innerBoxes[1].width,1)
	self.innerDivider:setFillColor(0,0,0)
	self.innerDivider.x, self.innerDivider. y = self.innerBoxes[1].x, self.innerBoxes[4].stageBounds.yMin
	self:insert(self.innerDivider)

	self.innerBox = display.newRect(0,0,self.innerBoxes[1].width, INNER_HEIGHT * 4)
	self.innerBox.strokeWidth = 1
	self.innerBox:setStrokeColor(unpack(GC.MEDIUM_GRAY))
	self.innerBox:setFillColor(0,0,0,0)
	self.innerBox.x, self.innerBox.y = self.box.x, self.innerBoxes[2].stageBounds.yMax
	self:insert(self.innerBox)

	self.box.height = self.box.height + self.innerBoxes[#self.innerBoxes].stageBounds.yMax + PADDING - self.box.stageBounds.yMax
	self.box.y = self.message.stageBounds.yMax + self.box.height * 0.5 + PADDING * 0.5

	local paymentOptions = utils.shallowcopy(options)

	if (gbtBalance > 0) then
		-- First payment has cash option
		table.insert(paymentOptions,1,{id=-1,label="GBT Cash Account | Balance: $"..utils.formatMoney(gbtBalance)})
	end

	table.insert(options,1,{id=0,label=SceneManager.getRosettaString("select_payment_option")})
	table.insert(paymentOptions,1,{id=0,label=SceneManager.getRosettaString("select_payment_option")})

	local paymentLabels = {}
	
	for i = 1,#paymentOptions do
		table.insert(paymentLabels,paymentOptions[i].label or "")
	end

	local optionLabels = {}
	
	for i = 1,#options do
		table.insert(optionLabels,options[i].label or "")
	end

	local function formatAmountLabel(amount)
		return "$"..utils.addNumberSeparator(utils.formatMoney(amount))
	end

	local function calculatePaymentSummary()
		local paymentId = paymentOptions[self.payment.row].id
		local totalAmountApproved = amountToFund
		local ccBalance = 0
		
		if (paymentId == -1) then
			ccBalance = totalAmountApproved - gbtBalance
		elseif (paymentId ~= 0) then
			ccBalance = totalAmountApproved
		end
		
		if (ccBalance < 0) then
			ccBalance = 0
		end
		
		local ccFees = ccFeePct * ccBalance
		self.innerAmounts[3].text = formatAmountLabel(ccFees)
		
		if (isNoCCFees) then
			ccFees = 0
		end

		self.innerAmounts[4].text = formatAmountLabel(totalAmountApproved+ccFees)
	end

	local function paymentCallback(event,value)
		self.payment.row = value
		self.payment:setLabel(paymentOptions[value].label)
		
		if (paymentOptions[self.payment.row].id == -1 and amountToFund > gbtBalance) then
			self.payment2.isVisible = true
		else
			self.payment2.isVisible = false
			self.payment2:setLabel(options[1].label)
			self.payment2.row = 1
		end

		calculatePaymentSummary()
	end

	local function payment2Callback(event,value)
		self.payment2.row = value
		self.payment2:setLabel(options[value].label)
	end

	local function showOptions(options,selected,callback)
		alert:show({title=SceneManager.getRosettaString("please_select"),width=display.contentWidth - PADDING * 2,
	    	list = {options = options,selected = selected,fontSize=14},
			buttons={SceneManager.getRosettaString("cancel")},cancel = 1,
			callback=callback
		})
	end

	local function onPayment()
		showOptions(paymentLabels,self.payment.row or 1,paymentCallback)
	end

	local function onPayment2()
		showOptions(optionLabels,self.payment2.row or 1,payment2Callback)
	end

	self.payment = widget.newButton{
      id = "payment",x = 0,y = 0,labelAlign="left",xOffset = 5,
      width = elementWidth,height = 50, overColor = OVER_COLOR,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = paymentOptions[1].label,labelWidth=elementWidth - 25,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onPayment   
   	}
   	self.payment.x, self.payment.y = self.x, self.box.stageBounds.yMax + self.payment.height * 0.5 + PADDING
   	self.payment.row = 1
   	self:insert(self.payment)

	self.payment2 = widget.newButton{
      id = "payment2",x = 0,y = 0,labelAlign="left",xOffset = 5,
      width = elementWidth,height = 50,overColor = OVER_COLOR,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = options[1].label,labelWidth=elementWidth - 25,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onPayment2   
   	}
   	self.payment2.x, self.payment2.y = self.x, self.payment.stageBounds.yMax + self.payment2.height * 0.5 + PADDING
   	self.payment2.isVisible = false
   	self.payment2.row = 1
   	self:insert(self.payment2)

   	calculatePaymentSummary()

	local buttonWidth = (self.bg.width - PADDING * 3) * 0.5

	local function showMessage(messageQ)
		if (messageQ) then
			alert:show({
			 title = SceneManager.getRosettaString("error"),
			 message = SceneManager.getRosettaString(messageQ),
			 buttons={SceneManager.getRosettaString("ok")}
			})
			messageQ = nil
		end
	end

	local function fundCallback(response)
		local messageQ = nil
		if (response == nil or response.error_msg == nil) then
			messageQ = "invalid_server_response"
		elseif (response.error_msg.errorMessage ~= "") then
			messageQ = response.error_msg.errorMessage
		elseif (response.status == "true") then
			-- TODO: Handle successful funding. Website automatically submits acceptQuote form.
			-- TODO: Maybe add alert dialog and then ok causes below to execute.
			if (callback) then
				callback(true)
			end

			self:hide()
		else
			messageQ = "invalid_server_response"
		end

		showMessage(messageQ)
	end

	local function fundLoad()
		api.fundLoad({
			sid=SceneManager.getUserSID(),
			id=loadIdGuid,
			paymentId = paymentOptions[self.payment.row].id,
			paymentId2 = options[self.payment2.row].id,
			amount = amountToFund,
			gbtBalance = gbtBalance,
			callback = fundCallback
		})
	end

	local function onCancel()
		self:hide()
	end

	local function onSubmit()
		local messageQ = nil
		local title = nil

		local paymentId = paymentOptions[self.payment.row].id
		local paymentId2 = options[self.payment2.row].id
		
		if (paymentId == 0) then
			title = SceneManager.getRosettaString("payment_type_required")
			messageQ = SceneManager.getRosettaString("select_payment")
		elseif (paymentId == -1 and (amountToFund > gbtBalance) and paymentId2 == 0) then
			local remainingBalance = utils.formatMoney(amountToFund - gbtBalance)
			title = SceneManager.getRosettaString("payment2_type_required")
			messageQ = string.gsub(SceneManager.getRosettaString("select_payment2_message"),"{balance}",remainingBalance)
		end

		if (messageQ) then
			alert:show({title=title,width=display.contentWidth - PADDING * 2,
		    	message = messageQ,
				buttons={SceneManager.getRosettaString("ok")},cancel = 1
			})
		else
			fundLoad()
		end
	end

	self.cancel = widget.newButton{
		id = "cancel",
		defaultColor = defaultColor,
		overColor = overColor,
		font = GC.BUTTON_FONT,
		fontSize = 18,
		label=SceneManager.getRosettaString("cancel",1),
		labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER },
		width = buttonWidth,
		height = GC.BUTTON_ACTION_HEIGHT,
		cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
		strokeColor = GC.DARK_GRAY,
		strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
		onRelease = onCancel
   	}
   	self.cancel.x, self.cancel.y = self.bg.stageBounds.xMin + self.cancel.width * 0.5 + PADDING, self.bg.stageBounds.yMax - self.cancel.height * 0.5 - PADDING
   	self:insert(self.cancel)

   	self.submit = widget.newButton{
		id = "submit",
		defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
		overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
		font = GC.BUTTON_FONT,
		fontSize = 18,
		label=SceneManager.getRosettaString("submit",1),
		labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
		width = buttonWidth,
		height = GC.BUTTON_ACTION_HEIGHT,
		cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
		strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
		strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
		onRelease = onSubmit
   	}
   	self.submit.x, self.submit.y = self.bg.stageBounds.xMax - self.submit.width * 0.5 - PADDING, self.cancel.y
   	self:insert(self.submit)

	function self:dismiss()
		self.overlay:removeSelf()
		self.overlay = nil

		self.bg:removeSelf()
		self.bg = nil

		self.titleBG:removeSelf()
		self.titleBG = nil

		self.title:removeSelf()
		self.title = nil

		self.message:removeSelf()
		self.message = nil

		self.payment:removeSelf()
		self.payment = nil

		self.payment2:removeSelf()
		self.payment2 = nil

		self.cancel:removeSelf()
		self.cancel = nil

		self.submit:removeSelf()
		self.submit = nil

		self.box:removeSelf()
		self.box = nil

		self.innerBox:removeSelf()
		self.innerBox = nil

		for i = 1, #self.innerBoxes do
			self.innerBoxes[1]:removeSelf()
			table.remove(self.innerBoxes,1)

			self.innerLabels[1]:removeSelf()
			table.remove(self.innerLabels,1)

			self.innerAmounts[1]:removeSelf()
			table.remove(self.innerAmounts,1)
		end
		self.innerBoxes = nil

		self.innerDivider:removeSelf()
		self.innerDivider = nil

		self.boxTitle:removeSelf()
		self.boxTitle = nil

		self:removeSelf()
		self = nil

		_G.customOverlay = nil
	end

	self.touchListener = function(s,event)
		local result = true
		
		if (event.phase == "ended") then
			-- NOTE: Do nothing for now
		end
		return result
	end
	
	self.overlay.touch = self.touchListener
	self.overlay:addEventListener("touch")

	local function hideComplete()
		self:dismiss()
		_G.customOverlay = nil
	end

	function self:hide()
		self.overlay.isVisible = false
		self.tween = transition.to( self, {time=TIME_TO_SCALE_MS, xScale = 0.1, yScale = 0.1, onComplete=hideComplete} )
	end

	local function hide()
		self:hide()
	end

	local function showComplete()
		self.overlay.isVisible = true
		_G.customOverlay = hide
	end

	function self:show()
		self.xScale, self.yScale = 0.1,0.1
		self.overlay.isVisible = false
		self.tween = transition.to( self, {time=TIME_TO_SCALE_MS, xScale = 1.0, yScale=1.0,onComplete=showComplete} )
	end

	self.x, self.y = display.contentCenterX, display.contentCenterY

	self:show()

	return self
end

return overlayFundShipment