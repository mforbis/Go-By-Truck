local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local toggle = require("toggle")
local GC = require("AppConstants")
local alert = require("alertBox")
local api = require("api")
local status = require("status")
local datePicker = require("datePicker")
local listOverlay = require("listOverlay")

local sceneGroup = nil
local bg = nil
local btnBack = nil
local btnActionLeft, btnActionRight = nil, nil
local title = nil
local titleBG = nil
local lblShipmentId = nil

local elements = nil

local scrollView = nil

local PADDING = 10
local LINE_HEIGHT = 10
local LINE_ADJUST = 5
local OPTION_HEIGHT = 30
local SPACE = 5
local ROUNDED_SIZE = 7
local STROKE_WIDTH = 1
local STROKE_COLOR = GC.MEDIUM_GRAY
local BUTTON_HEIGHT = GC.BUTTON_ACTION_HEIGHT
local HELP_SIZE = 25
local BUTTON_XOFFSET = 5
local SECTION_SHADOW_XOFFSET = 2
local SECTION_SHADOW_YOFFSET = 3
local SECTION_TITLE_FONT_SIZE = 18
local SECTION_SUBTITLE_FONT_SIZE = 14
local SELECTOR_DEFAULT_WIDTH = 200
local SELECTOR_DEFAULT_HEIGHT = 35
local IMAGE_DEFAULT_SIZE = 25
local NUMBER_INPUT_WIDTH = 45

local BG_COLOR = GC.WHITE
local SECTION_BG_COLOR = {245/255,245/255,245/255}

local TRAILER_OPTIONS = {"doubleDropDeck","flatbed","gooseneck","reefer","stepDropDeck","van"}
local DOUBLE_DROP_DECK = TRAILER_OPTIONS[1]
local FLATBED = TRAILER_OPTIONS[2]
local GOOSENECK = TRAILER_OPTIONS[3]
local REEFER = TRAILER_OPTIONS[4]
local STEP_DROP_DECK = TRAILER_OPTIONS[5]
local VAN = TRAILER_OPTIONS[6]

local FORM_VALID = ""

local COMMODITY_OPTIONS = {
   0,"Agricultural","Alcohol","Apparel / Shoes","Appliances",
   "Automobile Parts","Building Products","Consumer care products/ perfume",
   "Electronics Includes cell phones; computers","Food and beverages",
   "Furniture (Not Personal Household)","General Merchandise","Machinery &amp; Equipment",
   "Metals / Metal Products","Paper Products","Pharmaceuticals",
   "Precious Metals, Gems, Monies or currency","Scrap Metal / Waste","Tobacco"
}

local COMMODITY_LABELS = {
   "commodity_option1","commodity_option2","commodity_option3","commodity_option4",
   "commodity_option5","commodity_option6","commodity_option7","commodity_option8",
   "commodity_option9","commodity_option10","commodity_option11","commodity_option12",
   "commodity_option13","commodity_option14","commodity_option15","commodity_option16",
   "commodity_option17","commodity_option18","commodity_option19",
}

local MAX_TRAILER_LENGTH_OPTIONS = {100,28,45,48,50,53}
local MAX_TRAILER_LENGTH_LABELS = {"trailer_option1","trailer_option2","trailer_option3",
"trailer_option4","trailer_option5","trailer_option6"}

local COVERAGE_OPTIONS = {0,"Tarps","Dry Van","Either"}
local COVERAGE_LABELS = {"select_coverage","tarps","dry_van","either"}

local currSection

local currStep = nil

local currElement = nil
local yOffset = nil

local updated = nil

local shipment = nil
local isEdit = nil

local messageQ = nil

local trailerError

local elementWidth

local addressBook = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function getElementIndexById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return i
      end
   end
   return -1
end

local function getElementById(id)
   return elements[getElementIndexById(id)]
end

-- getShipmentDetails returns date format of 2014-10-30 for stopDate
-- addEditShipment expects date format of 2014/11/22 for endDate
local function fixDateStamps()
   for i = 1, #shipment.locations do
      shipment.locations[i].startDate = string.gsub(shipment.locations[i].startDate, "-", "/")
      shipment.locations[i].stopDate = string.gsub(shipment.locations[i].stopDate, "-", "/")
   end
end

local function isCargoGreaterThan100K()
   return (utils.isValidParameter(shipment.loadDetail.cargoValue) and tonumber(shipment.loadDetail.cargoValue) > 100000 )
end

local function updateLocationsState()
   local bLabel = "add_new_location"

   if shipment.locations then
      getElementById("locations_label").text = #shipment.locations.." "..SceneManager.getRosettaString("locations_label")
      if #shipment.locations > 0 then
         bLabel = "manage_locations"
      end
   end

   getElementById("manageLocations"):setLabel(SceneManager.getRosettaString(bLabel))
end

local function updatePackagingState()
   local bLabel = "add"

   if shipment.packaging then
      getElementById("packaging_label").text = #shipment.packaging.." "..SceneManager.getRosettaString("packages_label")
      if #shipment.packaging > 0 then
         bLabel = "manage"
      end
   end
   
   getElementById("managePackaging"):setLabel(SceneManager.getRosettaString(bLabel.."_packaging"))
end

local function updateNativeScrollElements()
   if (getElementById("shipperNote").stageBounds.yMax > scrollView.stageBounds.yMax) or
      (getElementById("shipperNote").stageBounds.yMin <= scrollView.stageBounds.yMin) then
      getElementById("shipperNote").isVisible = false
   else
      getElementById("shipperNote").isVisible = true
   end
end

local function scrollToElement(id,focus)
   local section = getElementById(id)

   local function onScrollComplete()
      -- scrollToPosition doesn't fire scroll listener
      -- certain elements (native) need to be manually shown once done for now
      updateNativeScrollElements()

      if (focus) then
         section.isVisible = true
         native.setKeyboardFocus(section)
      end
   end

   if (section) then
      scrollView:scrollToPosition({y=-(section.y - section.height * 0.5 - PADDING + 1),time = 200,onComplete = onScrollComplete})
   end
end

-- NOTE: Added text attribute to easily pass in text label
-- TODO: Rewrite other functions to use text attribute/parameter
local function onHelp(event)
   local strHelp = nil
   if (event.phase == "release") then
      -- id is deprecated, but left in for now until all others have been fixed
      if (event.target.id == "liftGate") then
         strHelp = "lift_gate_help"
      elseif (event.target.id == "expedited") then
         strHelp = "expedited_help"
      elseif (event.target.id == "packaging_section") then
         strHelp = "packaging_help"
      elseif (event.target.text ~= nil) then
         strHelp = event.target.text
      end
   elseif (event.phase == "moved") then
      local dy = math.abs(( event.y - event.yStart ))
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus(event)
      end
   end

   if (strHelp) then
      alert:show({message=SceneManager.getRosettaString(strHelp),
         buttons={SceneManager.getRosettaString("ok")}})
   end
end

local function addLine()
   yOffset = yOffset + LINE_HEIGHT
end

local function nextLine(previous)
   if (not previous) then
      if (elements[currElement] == nil) then
         yOffset = yOffset + LINE_HEIGHT
      else
         yOffset = yOffset + elements[currElement].height * 0.5 + LINE_HEIGHT
      end
   else
      yOffset = previous.y + previous.height * 0.5 + LINE_HEIGHT
   end
end

local function nextElement()
   currElement = #elements + 1
end

local function adjustSectionHeight(id,element)
   local section = getElementById(id)
   local h = ((element.stageBounds.yMax + PADDING) - section.stageBounds.yMin)
   
   local yAdjust = (h - section.height) * 0.5
   section.height = h
   section.y = section.y + yAdjust
end

local function addTextElement(params)
   nextElement()
   local yAdjust = 0

   if params.multiline then
      elements[currElement] = display.newText( {text = params.text, x=0,y=0,width = scrollView.width - PADDING * 2,font=params.font or GC.APP_FONT, fontSize = params.size or 14, align=params.align or "left"} )
      scrollView:insert(elements[currElement])
      yAdjust = elements[currElement].height * 0.5
      -- If from an option, try to align it with the box
      if (params.yOffset) then
         yAdjust = yAdjust - params.yOffset
      end
   else
      elements[currElement] = display.newText(scrollView,params.text,0,0,GC.APP_FONT, params.size or 14)
   end
   scrollView:insert(elements[currElement])
   --elements[index].anchorX, elements[index].anchorY = 0,0.5
   elements[currElement].x, elements[currElement].y = params.x + elements[currElement].width * 0.5,params.y + yAdjust
   elements[currElement]:setFillColor(unpack(params.color or GC.DARK_GRAY))
end

local function overlayOnComplete()
   updateLocationsState()
   updatePackagingState()
end

local function showOverlay(type)
   listOverlay:show({type=type,title=SceneManager.getRosettaString("manage_"..type),locations=shipment.locations,packaging=shipment.packaging,addressBook=addressBook,group=sceneGroup,callback=overlayOnComplete})
end

local forwardType = nil

local function locationsCallback(response)
   if (response == nil or response.locations == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      addressBook = response.locations
      showOverlay(forwardType)
   end

   showMessage()
end

local function managePackaging()
   -- TODO: show listOverlay
   -- NOTE: If no locations, then selects are empty
   -- NOTE: If at least one pickup/dropoff choose that by default
   -- NOTE: after insert expand section, and push everything else down
   
   --Log("packaging: "..#shipment.packaging)
   
   if (#addressBook > 0) then
      showOverlay("packaging")
   else
      forwardType = "packaging"
      api.getLocations({sid=SceneManager.getUserSID(),callback=locationsCallback})
   end
end

local function manageLocations()

   if (#addressBook > 0) then
      showOverlay("locations")
   else
      forwardType = "locations"
      api.getLocations({sid=SceneManager.getUserSID(),callback=locationsCallback})
   end
end

local function notNumber(number)
   return tonumber(number) == nil
end

local function validate()
   if (shipment.coverSelected and shipment.coverage == COVERAGE_OPTIONS[1]) then
      currSection = "services"
      return "select_coverage"
   end

   if (#shipment.locations == 0) then
      currSection = "pickup_dropoff"
      return "add_a_location"
   end

   if (notNumber(shipment.loadDetail.weight) or notNumber(shipment.loadDetail.length) or
      notNumber(shipment.loadDetail.width) or notNumber(shipment.loadDetail.height)) then
      currSection = "section_dimensions"
      return "total_shipment_dimensions_error"
   end

   if (not utils.isValidParameter(shipment.loadDetail.commodity,0)) then
      currSection = "commodity_section"
      return "select_commodity"
   end

   if (#shipment.packaging == 0) then
      currSection = "packaging_section"
      return "add_packaging"
   end

   if (shipment.pricingOptions ~= GC.ESCROW_TYPE_FAST) and (shipment.pricingOptions ~= GC.ESCROW_TYPE_MANUAL) then
      currSection = "escrow_section"
      return "escrow_option_error"
   end

   if (not shipment.publishNow and not shipment.publishLater) then
      currSection = "posting_section"
      return "posting_time_error"
   elseif (shipment.publishLater and shipment.scheduledDateStr == "") then
      currSection = "posting_section"
      return "posting_date_error"
   end

   if (getElementById("cargoValueCheckbox").state and not (isCargoGreaterThan100K())) then
      currSection = "cargo_value"
      return "cargo_value_details"
   end

   return FORM_VALID
end

local function postAlertOnComplete()
   SceneManager.goToMyShipments()
end

local function postCallback(response)
   local posted = false

   if (response == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      if (response.error_msg.error ~= "APPLICATION_EXCEPTION") then
         messageQ = response.error_msg.errorMessage
      else
         messageQ = response.error_msg.error or "server_error"
      end
   else
      posted = true
   end

   if posted then
      alert:show({
         title = SceneManager.getRosettaString("posted"),
         message = SceneManager.getRosettaString("shipment_posted_success"),
         buttons={SceneManager.getRosettaString("ok")},
         callback=postAlertOnComplete
      })
   else
      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
   end
end

local function onBack()
   -- TODO: Maybe add an are you sure prompt if we have done some editing?
   if (composer.getSceneName("previous") == "SceneMyShipments") then
      SceneManager.goToMyShipments()
   else
      SceneManager.goToDashboard()
   end
end

local function onEventCallback(event)
   if (event.phase == "release") then
      if (event.target.id == "back") then
         onBack()
      elseif (event.target.id == "right") then
         -- TODO: Validate, and show possible errors for each section
         local result = validate()

         if (result == FORM_VALID) then
            api.addEditShipment({sid=SceneManager.getUserSID(),loadIdGuid=shipment.loadIdGuid,shipment=shipment,callback=postCallback})
         else
            scrollToElement(currSection)
            alert:show({
               title = SceneManager.getRosettaString("error"),
               message = SceneManager.getRosettaString(result),
               buttons={SceneManager.getRosettaString("ok")}
            })
         end
      elseif (event.target.id == "manageLocations") then
         manageLocations()
      elseif (event.target.id == "managePackaging") then
         managePackaging()
      end
   elseif (event.phase == "moved") then
      local dy = math.abs( ( event.y - event.yStart ) )
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus( event )
      end
   end
end

local function selectorSetLabel(selector)
   local label = ""
   
   if (selector.value ~= nil) then
      for i=1,#selector.options do
         if (selector.value == selector.options[i]) then
            label = SceneManager.getRosettaString(selector.labels[i])
         end
      end
   end

   selector:setLabel(label)
end

local function selectorSetValue(selector,value)
   selector.value = selector.options[value]
   selectorSetLabel(selector)
   if (selector.id == "commodity") then
      shipment.loadDetail.commodity = selector.value
   else
      shipment[selector.id] = selector.value
   end
   Log ("selector: id = "..selector.id..", value: "..selector.value)

end

local function selectionOnComplete(event,value)
   local selector = getElementById(event.id)

   if (selector) then
      selectorSetValue(selector,value)
   end
end

local function selectorGetOptionIndex(id)
   local selector = getElementById(id)
   local index = 0

   if (selector) then
      for i=1,#selector.options do
         if (selector.value == selector.options[i]) then
            index = i
         end
      end
   end

   return index
end

local function selectorGetLabels(id)
   local selector = getElementById(id)
   local options = {}

   if (selector) then
      for i=1,#selector.labels do
         table.insert( options, SceneManager.getRosettaString(selector.labels[i]) )
      end
   end

   return options
end

local function showSelections(event)
   if (event.phase == "release") then
      if (event.target.id) then
         alert:show({title = SceneManager.getRosettaString(event.target.title or "select_option"),id=event.target.id,
            list = {options = selectorGetLabels(event.target.id),selected = selectorGetOptionIndex(event.target.id),fontSize=event.target.fontSize or 16},
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=selectionOnComplete})
      end
   elseif (event.phase == "moved") then
      local dy = math.abs( ( event.y - event.yStart ) )
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus( event )
      end
   end
end

local function addSelector(params)
   local size = params.size or 18
   nextElement()

   elements[currElement] = widget.newButton {
      id = params.id,
      overColor = GC.LIGHT_GRAY2,
      font = GC.BUTTON_FONT,
      fontSize = size,
      label="",labelAlign="left",xOffset = BUTTON_XOFFSET,
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = params.width or SELECTOR_DEFAULT_WIDTH,
      height = params.height or SELECTOR_DEFAULT_HEIGHT,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = showSelections
   }

   elements[currElement].value = params.value
   elements[currElement].options = params.options
   elements[currElement].labels = params.labels
   elements[currElement].fontSize = params.fontSize

   elements[currElement].x, elements[currElement].y = params.x, params.y + elements[currElement].height * 0.5
   selectorSetLabel(elements[currElement])

   if (params.enabled == false) then
      elements[currElement]:disable()
   end
   scrollView:insert(elements[currElement])
end

local function insertDivider(element)
   if (element == nil) then
      element = elements[currElement]
   end

   nextElement()
   elements[currElement] = display.newRect(0, 0, elementWidth, 1)
   elements[currElement]:setFillColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = scrollView.x, element.y + element.height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])
end

local function allTrailersAreUnchecked()
   local uncheckedCount = 0

   for i=1,#TRAILER_OPTIONS do
      if (not shipment[TRAILER_OPTIONS[i]]) then
         uncheckedCount = uncheckedCount + 1
      end
   end

   return uncheckedCount == #TRAILER_OPTIONS
end

local function enableAllTrailers()
   for i=1,#TRAILER_OPTIONS do
      shipment[TRAILER_OPTIONS[i]] = true
      getElementById(TRAILER_OPTIONS[i]).setState(true)
      getElementById(TRAILER_OPTIONS[i]).setToggleState(true)
   end
end

local function disableTrailer(id)
   shipment[id] = false
   getElementById(id).setState(false)
   getElementById(id).setToggleState(false)
end

local function manageTrailers()
   enableAllTrailers()

   local commodity = shipment.loadDetail.commodity
   local coolOrFrozen = shipment.coolOrFrozen
   local dryVan = shipment.coverage == COVERAGE_OPTIONS[3]
   local swingDoors = shipment.options.swingDoors
   local sideKit = (shipment.loadEquipment.sideKit > 0)
   local tarps = shipment.coverage == COVERAGE_OPTIONS[2]
   local crane = shipment.crane
   local sideLoaded = shipment.sideLoaded
   local liftGate = shipment.liftGate
   local ventedVan = (shipment.loadEquipment.ventedVan > 0)
   local maxTrailerLength = shipment.maxTrailerLength
   local cargoLength = tonumber(shipment.loadDetail.length) or 0
   
   -- TODO: Add trailer error to scrollview and also hide it here =)

   if (commodity == COMMODITY_OPTIONS[4] or commodity == COMMODITY_OPTIONS[8] or
         commodity == COMMODITY_OPTIONS[16] or commodity == COMMODITY_OPTIONS[19] or
         commodity == COMMODITY_OPTIONS[17] or commodity == COMMODITY_OPTIONS[15] or
         dryVan or liftGate or ventedVan or swingDoors) then
      disableTrailer(FLATBED)
      disableTrailer(STEP_DROP_DECK)
      disableTrailer(GOOSENECK)
      disableTrailer(DOUBLE_DROP_DECK)
   end

   if (commodity == COMMODITY_OPTIONS[18]) then
      disableTrailer(REEFER)
   end

   if (coolOrFrozen) then
      disableTrailer(FLATBED)
      disableTrailer(STEP_DROP_DECK)
      disableTrailer(GOOSENECK)
      disableTrailer(DOUBLE_DROP_DECK)
      disableTrailer(VAN)
   end

   if (sideKit) then
      disableTrailer(GOOSENECK)
      disableTrailer(DOUBLE_DROP_DECK)
      disableTrailer(VAN)
      disableTrailer(REEFER)
   end

   if (tarps or crane or sideLoaded) then
      disableTrailer(VAN)
      disableTrailer(REEFER)
   end

   if (allTrailersAreUnchecked()) then
      -- TODO: Display trailer error
      -- Your current shipment options have removed all trailer possibilities. Please alter your selections so at least one trailer option is selected.
      if (not trailerError) then
         -- Show alert box or toast with following message
         -- Your current shipment options have removed all trailer possibilities
      end

      trailerError = true
   else
      trailerError = false
   end

   if (maxTrailerLength > 0 and maxTrailerLength < cargoLength) then
      -- TODO: Display trailer error
      -- The length of your cargo is greater than the maximum trailer length you have specified.
   end
end

local function setLoadTypeMessage(message)
   local ldMessage = getElementById("loadtype_message")
   local dimensionsError = getElementById("dimensions_error")

   if (message) then
      ldMessage.text = message
      ldMessage.isVisible = true
      dimensionsError.isVisible = false
   else
      ldMessage.isVisible = false
      dimensionsError.isVisible = true
   end
end

local function calculateFreightClass()
   return utils.calculate(shipment.loadDetail.weight,shipment.loadDetail.length,shipment.loadDetail.lengthInches,shipment.loadDetail.width,shipment.loadDetail.height)
end

local function calculateShipmentType()
   local message = nil
   local loadType = utils.calculateType(shipment.loadDetail.weight,shipment.loadDetail.length,shipment.loadDetail.lengthInches,shipment.loadDetail.width,shipment.loadDetail.height)
   shipment.loadType = loadType

   --Log ("loadType: "..tostring(loadType))
   
   local exclusive = getElementById("exclusiveUse")
   local lblExclusive = getElementById("exclusiveUse_label")
   local exclusiveHelp = getElementById("exclusive_help")

   --exclusive.isVisible = false
   --lblExclusive.isVisible = false
   --exclusiveHelp.isVisible = false

   if (loadType == GC.TRUCKLOAD) then
      shipment.exclusiveUse = false
      exclusive.setState(false)
      exclusive.setToggleState(false)
      message = SceneManager.getRosettaString("tl_message")
   end

   if (loadType == GC.LESS_THAN_TRUCKLOAD) then
      --exclusive.isVisible = true
      --lblExclusive.isVisible = true
      --exclusiveHelp.isVisible = true
      exclusive.setToggleState(true)
      local class = calculateFreightClass()
      --Log ("class: "..class)
      message = SceneManager.getRosettaString("ltl_message").." "..SceneManager.getRosettaString("with_freight_class").." "..class
   end

   if (loadType == GC.OVER_DIMENSIONAL) then
      shipment.exclusiveUse = false
      exclusive.setState(false)
      exclusive.setToggleState(false)
      message = SceneManager.getRosettaString("od_message")
   end
   
   setLoadTypeMessage(message)
end

local function inputSetValue(id, value)
   local input = getElementById(id)

   if (input) then
      input.value = value
      input:setLabel(value)
      if (id == "options.other") then
         shipment.options.other = value
      elseif (id == "loadEquipment.other") then
         shipment.loadEquipment.other = value
      elseif (string.find(id,"loadDetail")) then
         local id = string.sub(id,12)
         if (value ~= "" and input.type == "number") then
            value = tonumber(value)
         end

         shipment.loadDetail[id] = value
         --Log ("found: "..id..", value: "..tostring(shipment.loadDetail[id]))
         if (id == "weight" or id == "length" or id == "lengthInches" or id == "height") then
            calculateShipmentType()
         end
      else
         --Log ("input id: "..id)
         shipment[id] = value
      end
   end
end

local function inputOnComplete(event,value)
   local i = event.target.id
   
   if (i == 2) then
      if (event.id and value) then
         if (event.id == "loadDetail.lengthInches" and tonumber(value) and (tonumber(value) < 0 or tonumber(value) > 11)) then
            alert:show({title = SceneManager.getRosettaString("error"),
               message = SceneManager.getRosettaString("length_inches_error"),
               buttons={SceneManager.getRosettaString("ok")},buttonHeight=30,
            })
         else
            inputSetValue(event.id,value)
            manageTrailers()
         end
      end
   end
end

local function showInput(event)
   if (event.phase == "release") then
      if (event.target.id) then
         alert:show({title = event.target.title,id=event.target.id,
            input = {text=event.target.value,type=event.target.type,maxlength=event.target.maxLength},buttonAlign="horizontal",
            buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,cancel=1,
            callback=inputOnComplete})
      end
   elseif (event.phase == "moved") then
      local dy = math.abs( ( event.y - event.yStart ) )
      -- If the touch on the button has moved more than 10 pixels,
      -- pass focus back to the scroll view so it can continue scrolling
      if ( dy > 10 ) then
         event.target:loseFocus() -- Resets button look
         scrollView:takeFocus( event )
      end
   end
end

local function addInput(params)
   local xOffset = 0

   if (params.label) then
      addTextElement({
         text=SceneManager.getRosettaString(params.label),
         x=params.x,
         y=params.y,multiline = false,
         yOffset = elements[currElement].height * 0.5,
         align=params.align or "left",
         color=params.color or GC.DARK_GRAY})
      elements[currElement].id = params.id.."_label"
      --xOffset = params.x + elements[currElement].width + params.width * 0.5 + SPACE
      if (params.xOffset == "right") then
         xOffset = elements[currElement].width + (params.width or INPUT_DEFAULT_WIDTH)
      else
         xOffset = 105
      end

      if (params.type == "number") then
         params.labelAlign = "left"
      end
   end

   nextElement()

   local icon = nil
   if (params.type == "number") then
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true}
   end

   elements[currElement] = widget.newButton{
      id = params.id,x = 0,y = 0,labelAlign=params.labelAlign or "left",xOffset = BUTTON_XOFFSET,
      width = params.width or INPUT_DEFAULT_WIDTH,height = params.height or BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      label=params.label,
      icon = icon,
      hint = {text=params.hint,color = GC.MEDIUM_GRAY},
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = showInput
   }
   
   elements[currElement].x, elements[currElement].y = params.x + xOffset, params.y
   elements[currElement].maxLength = params.maxLength
   elements[currElement].value = params.value
   elements[currElement]:setLabel(params.value)
   elements[currElement].type = params.type or "text"
   elements[currElement].title = params.title or SceneManager.getRosettaString("please_enter")
   scrollView:insert(elements[currElement])
end

-- TODO: Show toast of option de/selected notice
local function showEquipmentNotice(id,state)
   local text = SceneManager.getRosettaString("equipmentNotice")
   text = string.gsub(text,"%%1",id)

   local stateText = "selected"

   if (state == false) then
      stateText = "de-selected"
   end

   text = string.gsub(text, "%%2", SceneManager.getRosettaString(stateText))

   --Log ("notice: "..text)
end

local function inTable(t,id)
   for i=1,#t do
      if (t[i] == id) then
         return true
      end
   end

   return false
end

local function updateElementByState(element,state)
   if (state) then
      element:enable()
   else
      element:disable()
   end
end

local function handlePublishToggle(id)
   local state = shipment[id]

   if (id == "publishNow" and state) then
      getElementById("publishLater").setState(false)
      shipment.publishLater = false
      getElementById("scheduledDateStr"):disable()
   elseif (id == "publishLater" and state) then
      getElementById("publishNow").setState(false)
      shipment.publishNow = false
      getElementById("scheduledDateStr"):enable()
   end
end

local function optionCallback(element)
   if (element.id == "cargoValueCheckbox") then
      local cargoValue = getElementById("loadDetail.cargoValue")
      updateElementByState(cargoValue,element.state)
      if (not element.state) then
         cargoValue.value = ""
         cargoValue:setLabel("")
         shipment.loadDetail.cargoValue = ""
      end
   elseif (element.id == "liftGate") then
      --getElementById("loadEquipment.liftGate").setState(element.state)
      --showEquipmentNotice(SceneManager.getRosettaString("lift_gate"),element.state)
   elseif (element.id == "rampLoaded") then
      --getElementById("loadEquipment.ramps").setState(element.state)
      --showEquipmentNotice(SceneManager.getRosettaString("ramps"),element.state)
   elseif (element.id == "coverSelected") then
      updateElementByState(getElementById("coverage"),element.state)
   elseif (string.find(element.id,"loadEquipment")) then
      local id = string.sub(element.id,15)
      shipment.loadEquipment[id] = element.state
      Log ("shipment.loadEquipment."..id.." = "..tostring(shipment.loadEquipment[id]))
   elseif (inTable(GC.REQUIREMENTS_OPTIONS,element.id)) then
      shipment.options[element.id] = element.state
      Log ("shipment.options."..element.id.." = "..tostring(shipment.options[element.id]))
   elseif (string.find(element.id,"certifications")) then
      local id = string.sub(element.id,16)
      shipment.certifications[id] = element.state
      Log ("shipment.certifications."..id.." = "..tostring(shipment.certifications[id]))
   elseif (element.id == GC.ESCROW_TYPE_FAST or element.id == GC.ESCROW_TYPE_MANUAL) then
      if (element.state) then
         if ((shipment.pricingOptions == GC.ESCROW_TYPE_MANUAL or shipment.pricingOptions == GC.ESCROW_TYPE_FAST) and element.id ~= shipment.pricingOptions) then
            getElementById(shipment.pricingOptions).setState(false)
         end
         shipment.pricingOptions = element.id
      else
         getElementById(element.id).setState(true)
      end
   else
      shipment[element.id] = element.state
      Log ("shipment."..element.id.." = "..tostring(shipment[element.id]))
   end
   
   if (element.id == "publishNow" or element.id == "publishLater") then
      handlePublishToggle(element.id)
   end

   if (element.id ~= "doubleDropDeck" or element.id ~= "flatbed" or element.id ~= "van" or
         element.id ~= "gooseneck" or element.id ~= "reefer" or element.id ~= "stepDropDeck") then
      manageTrailers()
   end
end

local function addHelp(params)
   nextElement()

   elements[currElement] = widget.newButton{
      id = params.id,
      defaultColor = GC.DARK_GRAY,
      overColor = GC.ORANGE,
      default="graphics/question.png",
      width = HELP_SIZE,
      height = HELP_SIZE,
      onEvent = onHelp
   }
   elements[currElement].text = params.text
   elements[currElement].x, elements[currElement].y = params.x + HELP_SIZE * 0.5 + SPACE, params.y
   scrollView:insert(elements[currElement])
end

local function addOption(params)
   local size = params.size or OPTION_HEIGHT
   nextElement()
   
   local baseImg = "check"
   if (params.type == "radio") then
      baseImg = "radio"
   end

   elements[currElement] = toggle.new({id=params.id, x = 0, y = 0,on = "graphics/"..baseImg.."_on.png", onWidth = size, onHeight = size,
               off = "graphics/"..baseImg.."_off.png", offWidth = size, offHeight = size,
               state = params.state or false, callback = params.callback or onEventCallback})
   if (params.enabled ~= nil) then
      elements[currElement].setToggleState(params.enabled)
   end

   elements[currElement].type = "boolean"

   scrollView:insert(elements[currElement])
   elements[currElement].x, elements[currElement].y = params.x + elements[currElement].width * 0.5,params.y
   
   addTextElement({text=SceneManager.getRosettaString(params.label),x=params.x + elements[currElement].width + SPACE,y=params.y,multiline = params.multiline,yOffset = elements[currElement].height * 0.5,align=params.align,color=params.color})
   elements[currElement].id = params.id.."_label"

   if (params.hasHelp) then
      addHelp({id=params.id,x=elements[currElement].x + elements[currElement].width * 0.5,y=params.y})
   end
end

local function addOptions(t)
   if (t and type(t) == "table") then
      for i=1, #t do
         addOption({id=t[i].id,label=t[i].label or t[i].id,x=t[i].x,y=yOffset,state = t[i].state,callback=optionCallback})
         if (t[i].help and t[i].help ~= "") then
            addHelp({text=t[i].help,x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
         end

         if (t[i].newLine == true) then
            yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT
         end
      end
   end
end

local function addImage(params)
   nextElement()
   
   local width = params.width or IMAGE_DEFAULT_SIZE
   local height = params.height or IMAGE_DEFAULT_SIZE

   elements[currElement] = display.newImageRect(params.src, width, height )
   elements[currElement].anchorX, elements.anchorY = 0,0
   elements[currElement].x, elements[currElement].y = params.x, params.y
   scrollView:insert(elements[currElement])

   if (params.nextLine == true) then
      yOffset = yOffset + elements[currElement].height + LINE_ADJUST
   end
end

local function createActionLeftButton()
   if (btnActionLeft) then
      btnActionLeft:removeSelf()
      btnActionLeft = nil
   end

   local defaultColor = GC.LIGHT_GRAY
   local labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }
   local overColor = GC.DARK_GRAY
   local strokeColor = GC.DARK_GRAY
   local label = "cancel"

   if (currStep > 1) then
      defaultColor = GC.LIGHT_BLUE
      overColor = GC.DARK_BLUE
      labelColor = { default=GC.WHITE, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER }
      strokeColor = GC.DARK_BLUE
      label = "previous"
   end

   btnActionLeft = widget.newButton { 
      id = "left",
      defaultColor = defaultColor,
      overColor = overColor,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString(label,1),
      labelColor = labelColor,
      width = 140,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = strokeColor,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnActionLeft.x, btnActionLeft.y = btnActionLeft.width * 0.5 + PADDING , display.contentHeight - btnActionLeft.height * 0.5 - PADDING
   btnActionLeft.isVisible = false
   sceneGroup:insert(btnActionLeft)
end

-- TODO: Might still need this
local function updateCurrStep(which)
end

local function setShipperNote(note)
   shipment.shipperNote = note
   getElementById("shipperNoteText").text = note
end

local function inputListener( event )
   if event.phase == "began" then
      local x, y = scrollView:getContentPosition()

      --Log ("pos: x="..x..",y:"..y)
      -- Before showing keyboard, lets scroll the list up to not cover it up.
      scrollView.oldPos = y

      scrollToElement("shipperNote")
   elseif event.phase == "ended" then
      setShipperNote(getElementById("shipperNote").text)
      native.setKeyboardFocus( nil )
   elseif event.phase == "submitted" then
      setShipperNote(getElementById("shipperNote").text)
      native.setKeyboardFocus( nil )
   elseif event.phase == "editing" then
      -- TODO: Clip to max length (128)
   end
end

local function scrollListener(event)
   if (event.phase == nil) then
      -- snapping back
      getElementById("shipperNote").isVisible = true
   else
      if (event.phase == "moved") then
         local x, y = scrollView:getContentPosition()

         --Log ("pos: x="..x..",y:"..y)
         --Log ("y: "..y..", element y: "..getElementById("customerEmail").stageBounds.yMax)

      elseif (event.phase == "began") then
         native.setKeyboardFocus( nil )
         -- Let's scroll the list back to its original position if
         -- we scrolled it up to show the keyboard.
         if (scrollView.oldPos) then
            scrollView:scrollToPosition{y = scrollView.oldPos,time = 200}
            scrollView.oldPos = nil
         end
      end
         updateNativeScrollElements()
   end
end

local function addElements()
   elements = {}
   elementWidth = scrollView.width - PADDING * 2
   yOffset = 0

   -- New, or edit?
   if (utils.isValidParameter(shipment.loadIdGuid)) then
      isEdit = true

      lblShipmentId = display.newText({text=SceneManager.getRosettaString("shipment").." #: "..shipment.loadIdGuid,font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
      lblShipmentId:setFillColor(unpack(GC.DARK_GRAY))
      lblShipmentId.x, lblShipmentId.y = display.contentCenterX, yOffset + lblShipmentId.height * 0.5
      scrollView:insert(lblShipmentId)

      nextLine()
      addLine();addLine()
   end

   nextElement()
   nextLine()

   elements[currElement] = display.newRoundedRect(0,0,elementWidth,120,ROUNDED_SIZE)
   elements[currElement].id = "cargo_loading_unloading"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])
   
   local minX = elements[currElement].stageBounds.xMin + PADDING
   local halfWidth = (elementWidth - PADDING * 3) * 0.5
   local quarterWidth = (halfWidth - PADDING) * 0.5
   local midX = minX + halfWidth + PADDING

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("cargo_loading_unloading",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine()

   addOptions({
      {id="crane",x=minX,state=shipment.crane},
      {id="dock",x=midX,state=shipment.dock,newLine=true},
      {id="forkLift",label="forklift",x=minX,state=shipment.forkLift},
      {id="liftGate",label="lift_gate",help="lift_gate_help",x=midX,state=shipment.liftGate,newLine=true},  
      {id="rampLoaded",label="ramp_loaded",x=minX,state=shipment.rampLoaded},  
      {id="rearLoaded",label="rear_loaded",x=midX,state=shipment.rearLoaded,newLine=true},  
      {id="sideLoaded",label="side_loaded",x=minX,state=shipment.sideLoaded}
   })
   
   nextLine()
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("cargo_loading_unloading_error"),font=GC.APP_FONT,fontSize = 13})
   elements[currElement].id = "cargo_error"
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = scrollView.x, yOffset + LINE_ADJUST
   elements[currElement].isVisible = false
   scrollView:insert(elements[currElement])
   
   adjustSectionHeight("cargo_loading_unloading",elements[currElement])
   nextLine(getElementById("cargo_loading_unloading"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,50,ROUNDED_SIZE)
   elements[currElement].id = "services"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("services",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine()

   addOption({id="expedited",label="expedited_option",x=minX,y=yOffset,state = shipment.expedited,hasHelp=true,callback=optionCallback})
   
   yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT

   -- Hack
   if shipment.coverage == "0" then shipment.coverage = 0 end

   shipment.coverSelected = shipment.coverage ~= COVERAGE_OPTIONS[1]
   print ("value: "..tostring(shipment.coverSelected))
   addOption({id="coverSelected",label="coverage_option",x=minX,y=yOffset,state = shipment.coverSelected,callback=optionCallback})
   
   yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT

   local defaultValue = COVERAGE_OPTIONS[1]
   
   if (utils.isValidParameter(shipment.coverage,0)) then
      defaultValue = shipment.coverage
   end
   
   addSelector({id="coverage",value=defaultValue,options=COVERAGE_OPTIONS,labels=COVERAGE_LABELS,enabled=shipment.coverSelected,x=scrollView.x,y=yOffset - LINE_ADJUST})

   adjustSectionHeight("services",elements[currElement])
   nextLine(getElementById("services"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,145,ROUNDED_SIZE)
   elements[currElement].id = "pickup_dropoff"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("pickup_dropoff_locations",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="",font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement].id = "locations_label"
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   nextElement()

   elements[currElement] = widget.newButton{
      id = "manageLocations",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 14,
      label=SceneManager.getRosettaString("manage_locations",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 160,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset
   scrollView:insert(elements[currElement])

   updateLocationsState()

   adjustSectionHeight("pickup_dropoff",elements[currElement])
   nextLine(getElementById("pickup_dropoff"))
   
   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,180,ROUNDED_SIZE)
   elements[currElement].id = "section_dimensions"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_shipment_dimensions",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine()
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_weight"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_length"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])
   
   nextLine(elements[currElement])
   yOffset = yOffset + BUTTON_HEIGHT * 0.5 - LINE_ADJUST
   
   addInput({id="loadDetail.weight",hint=SceneManager.getRosettaString("pounds"),title=SceneManager.getRosettaString("weight"),value=shipment.loadDetail.weight,width=halfWidth,maxLength=11,type="number",x=getElementById("services").stageBounds.xMin + PADDING + halfWidth * 0.5,y=yOffset})
   addInput({id="loadDetail.length",hint=SceneManager.getRosettaString("feet"),title=SceneManager.getRosettaString("length").." ("..SceneManager.getRosettaString("feet")..")",value=shipment.loadDetail.length,width=quarterWidth,maxLength=3,type="number",x=midX + quarterWidth * 0.5,y=yOffset})
   addInput({id="loadDetail.lengthInches",hint=SceneManager.getRosettaString("inches"),title=SceneManager.getRosettaString("length").." ("..SceneManager.getRosettaString("inches")..")",value=shipment.loadDetail.lengthInches,width=quarterWidth,maxLength=2,type="number",x=midX + quarterWidth * 1.5 + PADDING,y=yOffset})
   
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_width"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_HEIGHT
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_height"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_HEIGHT
   scrollView:insert(elements[currElement])
   
   nextLine(elements[currElement])
   yOffset = yOffset + BUTTON_HEIGHT * 0.5 - LINE_ADJUST
   
   addInput({id="loadDetail.width",hint=SceneManager.getRosettaString("inches"),title=SceneManager.getRosettaString("width"),value=shipment.loadDetail.width,width=halfWidth,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING + halfWidth * 0.5,y=yOffset})
   addInput({id="loadDetail.height",hint=SceneManager.getRosettaString("inches"),title=SceneManager.getRosettaString("height"),value=shipment.loadDetail.height,width=halfWidth,maxLength=3,type="number",x=midX + halfWidth * 0.5,y=yOffset})
   
   nextLine()
   nextElement()

   elements[currElement] = display.newText({text="",font=GC.APP_FONT,fontSize = 13,width=elementWidth - PADDING * 2,height=80,align="left"})
   elements[currElement].id = "loadtype_message"
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = scrollView.x, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("total_shipment_dimensions_error"),font=GC.APP_FONT,fontSize = 13})
   elements[currElement].id = "dimensions_error"
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = scrollView.x, elements[currElement-1].y
   elements[currElement].isVisible = false
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement-1])
   addLine()

   addOption({id="exclusiveUse",label="my_shipment_exclusive",x=minX,y=yOffset,state = shipment.exclusiveUse,callback=optionCallback})
   addHelp({id="exclusive_help",text="exclusive_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})

   adjustSectionHeight("section_dimensions",getElementById("exclusiveUse"))
   nextLine(getElementById("section_dimensions"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "commodity_section"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("commodity",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine()
   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 18})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("general_commodity"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])

   defaultValue = COMMODITY_OPTIONS[1]

   if (utils.isValidParameter(shipment.loadDetail.commodity,0)) then
      defaultValue = shipment.loadDetail.commodity
   end

   addSelector({id="commodity",value=defaultValue,options=COMMODITY_OPTIONS,labels=COMMODITY_LABELS,width=elementWidth - PADDING * 2,x=scrollView.x,y=yOffset - LINE_ADJUST,fontSize=14})

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("specific_commodity"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_HEIGHT
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   
   addInput({id="loadDetail.specificCommodity",title=SceneManager.getRosettaString("specific_commodity"),value=shipment.loadDetail.specificCommodity,width=elementWidth - PADDING * 2,maxLength=128,type="text",x=scrollView.x,y=yOffset + LINE_HEIGHT + 3})

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("commodity_error"),font=GC.APP_FONT,fontSize = 13})
   elements[currElement].id = "commodity_error"
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = scrollView.x, yOffset + LINE_ADJUST
   elements[currElement].isVisible = false
   scrollView:insert(elements[currElement])

   adjustSectionHeight("commodity_section",elements[currElement])
   nextLine(getElementById("commodity_section"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "packaging_section"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("packaging",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addHelp({id="packaging_section",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="",font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement].id = "packaging_label"
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   nextElement()

   elements[currElement] = widget.newButton{
      id = "managePackaging",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 14,
      label=SceneManager.getRosettaString("manage_packaging",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 160,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset
   scrollView:insert(elements[currElement])

   updatePackagingState()
   
   adjustSectionHeight("packaging_section",elements[currElement])
   nextLine(getElementById("packaging_section"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "escrow_section"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 24})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("escrow_options",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addOption({id=GC.ESCROW_TYPE_FAST,label="move_shipment_fast",type="radio",x=minX,y=yOffset,state = shipment.pricingOptions == GC.ESCROW_TYPE_FAST,callback=optionCallback})
   
   nextLine(elements[currElement]);

   addTextElement({text=SceneManager.getRosettaString("move_shipment_fast_details"),x=minX,y=yOffset,multiline = true,color=GC.DARK_GRAY})
   
   nextLine(elements[currElement]);addLine();addLine()

   addOption({id=GC.ESCROW_TYPE_MANUAL,label="move_shipment_manually",type="radio",x=minX,y=yOffset,state = shipment.pricingOptions == GC.ESCROW_TYPE_MANUAL,callback=optionCallback})

   nextLine(elements[currElement]);

   addTextElement({text=SceneManager.getRosettaString("move_shipment_manually_details"),x=minX,y=yOffset,multiline = true,color=GC.DARK_GRAY})
   
   adjustSectionHeight("escrow_section",elements[currElement])
   nextLine(getElementById("escrow_section"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "posting_section"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("posting",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine()
   nextElement()

   elements[currElement] = display.newText({text="*",font=GC.APP_FONT,fontSize = 18})
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - 5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("post_shipment_time"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addOption({id="publishNow",label="immediately",x=minX,y=yOffset,state = shipment.publishNow,callback=optionCallback})
   addHelp({text="immediately_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   addOption({id="publishLater",label="later",x=midX,y=yOffset,state = shipment.publishLater,callback=optionCallback})
   addHelp({text="later_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("schedule_date"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_HEIGHT
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   
   addImage({src="graphics/calendar.png",width=30,height=30,x=minX,y=yOffset})
   addInput({id="scheduledDateStr",title=SceneManager.getRosettaString("schedule_date"),value=shipment.scheduledDateStr,width=elementWidth - PADDING * 3 - elements[currElement-1].width,type="text",x=scrollView.x,y=yOffset + LINE_HEIGHT + 3})
   if (shipment.publishNow) then
      elements[currElement]:disable()
   end

   elements[currElement-1].y = elements[currElement].y

   adjustSectionHeight("posting_section",elements[currElement])
   nextLine(getElementById("posting_section"))

   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "notes_section"
   elements[currElement]:setFillColor(unpack(SECTION_BG_COLOR))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipment_notes",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine()
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("shipment_notes_details"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 + LINE_ADJUST
   scrollView:insert(elements[currElement])

   -- TODO: Add Note area
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newRect( 0, 0, elementWidth - PADDING * 2, 100)
   elements[currElement].touchListener = function(self,e)
      local result = true
      
      if (e.phase == "ended") then
         -- If Native element is hiding allow the rect to pretend we touched it
         scrollToElement("shipperNote",true)
      end
      return result
   end
   
   elements[currElement].touch = elements[currElement].touchListener
   elements[currElement]:addEventListener("touch")
   elements[currElement]:setFillColor(unpack(GC.WHITE))
   elements[currElement].strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH
   elements[currElement]:setStrokeColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   -- NOTE: Hack to show text when hiding native element. If more time allows revisit and spin our own native replacement
   elements[currElement] = display.newText({text=shipment.shipperNote,font=GC.APP_FONT,fontSize = 16,width=elements[currElement-1].width-10,height=elements[currElement-1].height-5,align="left"})
   elements[currElement].id = "shipperNoteText"
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].x,elements[currElement-1].y + 5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = native.newTextBox( 0, 0, elements[currElement-2].width,elements[currElement-2].height)
   elements[currElement].id="shipperNote"
   elements[currElement].isVisible = false
   elements[currElement].isEditable = true
   elements[currElement].native = true
   elements[currElement]:addEventListener( "userInput", inputListener )
   elements[currElement].font = native.newFont( GC.APP_FONT, 16 )
   elements[currElement]:setTextColor( unpack(GC.DARK_GRAY) )
   elements[currElement].text = shipment.shipperNote
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   adjustSectionHeight("notes_section",elements[currElement])
   nextLine(getElementById("notes_section"))

   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("other_options",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   insertDivider()

   nextLine(elements[currElement]);yOffset = yOffset - LINE_HEIGHT
   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("requirements",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement].id = "requirements_title"
   elements[currElement]:setFillColor(unpack(GC.ORANGE))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addHelp({text="requirements_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])
   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "requirements_section"
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("requirements_details"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addOptions({
      {id="hardhat",x=minX,state=shipment.options.hardhat},
      {id="longSleeves",x=midX,state=shipment.options.longSleeves,newLine=true},
      {id="noPassengers",x=minX,state=shipment.options.noPassengers},
      {id="tolls",help="tolls_help",x=midX,state=shipment.options.noPassengers,newLine=true},  
      {id="lumpers",help="lumpers_help",x=minX,state=shipment.options.lumpers},  
      {id="layover",help="layover_help",x=midX,state=shipment.options.layover,newLine=true},  
      {id="safetyGlasses",x=minX,state=shipment.options.safetyGlasses}, 
      {id="driverAssist",help="driverAssist_help",x=midX,state=shipment.options.driverAssist,newLine=true},  
      {id="steelToedBoots",x=minX,state=shipment.options.steelToedBoots},
      {id="storage",x=midX,state=shipment.options.storage,newLine=true},
      {id="fuelSurcharge",x=minX,state=shipment.options.fuelSurcharge},
      {id="noPets",x=midX,state=shipment.options.noPets,newLine=true},
      {id="airRide",x=minX,state=shipment.options.airRide},
      {id="swingDoors",x=midX,state=shipment.options.swingDoors,newLine=true},
      {id="tradeShow",x=minX,state=shipment.options.tradeShow,newLine=true},
      {id="scale",label="scale_tickets_label",x=minX,state=shipment.options.scale,newLine=true},
   })

   nextLine(elements[currElement]);addLine()

   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("other"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   local w = elementWidth * 0.75
   addInput({id="options.other",title=SceneManager.getRosettaString("height"),value=shipment.options.other,width=w,maxLength=64,type="text",x=elements[currElement].stageBounds.xMax + PADDING + w * 0.5,y=elements[currElement].y})
   
   getElementById("requirements_section").lastElement = currElement

   adjustSectionHeight("requirements_section",elements[currElement])
   nextLine(getElementById("requirements_section"))

   insertDivider(getElementById("requirements_section"))

   -- NOTE: Not ready. One quirk is the scrollView doesn't adjust the inner
   -- height according to visible elements.
   local function hideSection(sectionID)
      local idx = getElementIndexById(sectionID)

      if (idx >= 1) then
         for i=idx, elements[idx].lastElement do
            elements[i].isVisible = false
         end
      end
   end

   --hideSection("requirements_section")

   nextLine(elements[currElement]);yOffset = yOffset - LINE_HEIGHT
   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("equipment",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE})
   elements[currElement].id = "equipment_title"
   elements[currElement]:setFillColor(unpack(GC.ORANGE))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addHelp({text="equipment_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])
   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "equipment_section"
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("equipment_details"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addInput({id="loadEquipment.binders",label="binders",labelAlign="center",value=shipment.loadEquipment.binders,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.blankets",label="blankets",labelAlign="center",value=shipment.loadEquipment.blankets,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.boomers",label="boomers",labelAlign="center",value=shipment.loadEquipment.boomers,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.chains",label="chains",labelAlign="center",value=shipment.loadEquipment.chains,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.coilRacks",label="coilRacks",labelAlign="center",value=shipment.loadEquipment.coilRacks,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.cradles",label="cradles",labelAlign="center",value=shipment.loadEquipment.cradles,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.dunnage",label="dunnage",labelAlign="center",value=shipment.loadEquipment.dunnage,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.levelers",label="levelers",labelAlign="center",value=shipment.loadEquipment.levelers,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.liftGate",label="liftGate",labelAlign="center",value=shipment.loadEquipment.liftGate,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.loadBars",label="loadBars",labelAlign="center",value=shipment.loadEquipment.loadBars,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.lumber",label="lumber",labelAlign="center",value=shipment.loadEquipment.lumber,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.padding",label="padding",labelAlign="center",value=shipment.loadEquipment.padding,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.palletJack",label="palletJack",labelAlign="center",value=shipment.loadEquipment.palletJack,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.ramps",label="ramps",labelAlign="center",value=shipment.loadEquipment.ramps,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.pipeStakes",label="pipeStakes",labelAlign="center",value=shipment.loadEquipment.pipeStakes,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.straps",label="straps",labelAlign="center",value=shipment.loadEquipment.straps,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.pallets",label="pallets",labelAlign="center",value=shipment.loadEquipment.pallets,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   addInput({id="loadEquipment.sideKit",label="sideKit",labelAlign="center",value=shipment.loadEquipment.sideKit,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=midX,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.ventedVan",label="ventedVan",labelAlign="center",value=shipment.loadEquipment.ventedVan,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,y=yOffset})
   nextLine(elements[currElement]);addLine();addLine();
   addInput({id="loadEquipment.sealLockForSecurement",label="sealLockForSecurement",labelAlign="center",value=shipment.loadEquipment.sealLockForSecurement,width=NUMBER_INPUT_WIDTH,maxLength=3,type="number",x=getElementById("services").stageBounds.xMin + PADDING,xOffset="right",y=yOffset})
   
   -- Old toggle version
   -- NOTE: The old toggle logic is still in place
   --[[
   addOptions({
      {id="loadEquipment.binders",label="binders",x=minX,state=shipment.loadEquipment.binders},
      {id="loadEquipment.blankets",label="blankets",x=midX,state=shipment.loadEquipment.blankets,newLine=true},
      {id="loadEquipment.boomers",label="boomers",help="boomers_help",x=minX,state=shipment.loadEquipment.boomers},
      {id="loadEquipment.chains",label="chains",x=midX,state=shipment.loadEquipment.chains,newLine=true},
      {id="loadEquipment.coilRacks",label="coilRacks",x=minX,state=shipment.loadEquipment.coilRacks},
      {id="loadEquipment.cradles",label="cradles",x=midX,state=shipment.loadEquipment.cradles,newLine=true},
      {id="loadEquipment.dunnage",label="dunnage",x=minX,state=shipment.loadEquipment.dunnage},
      {id="loadEquipment.levelers",label="levelers",x=midX,state=shipment.loadEquipment.levelers,newLine=true},
      {id="loadEquipment.liftGate",label="liftGate",x=minX,state=shipment.loadEquipment.liftGate},
      {id="loadEquipment.loadBars",label="loadBars",x=midX,state=shipment.loadEquipment.loadBars,newLine=true},
      {id="loadEquipment.lumber",label="lumber",x=minX,state=shipment.loadEquipment.lumber},
      {id="loadEquipment.padding",label="padding",x=midX,state=shipment.loadEquipment.padding,newLine=true},
      {id="loadEquipment.palletJack",label="palletJack",x=minX,state=shipment.loadEquipment.palletJack},
      {id="loadEquipment.ramps",label="ramps",x=midX,state=shipment.loadEquipment.ramps,newLine=true},
      {id="loadEquipment.pipeStakes",label="pipeStakes",x=minX,state=shipment.loadEquipment.pipeStakes},
      {id="loadEquipment.straps",label="straps",x=midX,state=shipment.loadEquipment.straps,newLine=true},
      {id="loadEquipment.pallets",label="pallets",x=minX,state=shipment.loadEquipment.pallets},
      {id="loadEquipment.sideKit",label="sideKit",x=midX,state=shipment.loadEquipment.sideKit,newLine=true},
      {id="loadEquipment.ventedVan",label="ventedVan",x=minX,state=shipment.loadEquipment.ventedVan},
      {id="loadEquipment.sealLockForSecurement",label="sealLockForSecurement",x=midX,state=shipment.loadEquipment.sealLockForSecurement,newLine=true},
   })
   ]]--
   nextLine(elements[currElement]);addLine()

   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("other"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   local w = elementWidth * 0.75
   addInput({id="loadEquipment.other",title=SceneManager.getRosettaString("height"),value=shipment.loadEquipment.other,width=w,maxLength=64,type="text",x=elements[currElement].stageBounds.xMax + PADDING + w * 0.5,y=elements[currElement].y})
   
   getElementById("equipment_section").lastElement = currElement

   adjustSectionHeight("equipment_section",elements[currElement])
   nextLine(getElementById("equipment_section"))

   insertDivider(getElementById("equipment_section"))

   nextLine(elements[currElement]);yOffset = yOffset - LINE_HEIGHT
   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("certificates_section_title",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement].id = "certificates_title"
   elements[currElement]:setFillColor(unpack(GC.ORANGE))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "certificates_section"
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("certificates_section_details"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addOption({id="certifications.doubleTripleTrailer",label="certificate_double_triple_option",x=minX,y=yOffset,state = shipment.certifications.doubleTripleTrailer,callback=optionCallback})
   addHelp({text="double_triple_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT

   addOption({id="certifications.hazmat",label="certificate_hazmat_option",x=minX,y=yOffset,state = shipment.certifications.hazmat,callback=optionCallback})
   addHelp({text="hazmat_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT
   
   addOption({id="certifications.twikCard",label="certificate_twic_option",x=minX,y=yOffset,state = shipment.certifications.twikCard,callback=optionCallback})
   addHelp({text="twic_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("tarps",1),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);addLine();addLine()

   addOption({id="loadEquipment.nurseryTarps",label="nursery_tarps",x=minX,y=yOffset,state = shipment.loadEquipment.nurseryTarps,callback=optionCallback})
   addOption({id="loadEquipment.smokeTarp",label="smoke_tarps",x=midX,y=yOffset,state = shipment.loadEquipment.smokeTarp,callback=optionCallback})
   
   yOffset = yOffset + OPTION_HEIGHT + LINE_HEIGHT

   addOption({id="loadEquipment.steelTarps",label="steel_tarps",x=minX,y=yOffset,state = shipment.loadEquipment.steelTarps,callback=optionCallback})
   addOption({id="loadEquipment.lumberTarps",label="lumber_tarps",x=midX,y=yOffset,state = shipment.loadEquipment.lumberTarps,callback=optionCallback})

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("cargo_value",1),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement].id = "cargo_value"
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addHelp({text="cargo_value_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement]);addLine();addLine()

   addOption({id="cargoValueCheckbox",label="cargo_value_label",x=minX,y=yOffset,state = isCargoGreaterThan100K(),callback=optionCallback})
   
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("cargo_value_details"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=120,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addInput({id="loadDetail.cargoValue",title=SceneManager.getRosettaString("cargo_value"),value=shipment.loadDetail.cargoValue,width=100,maxLength=11,type="number",x=elements[currElement].stageBounds.xMax + SPACE + 100 * 0.5,y=elements[currElement].y})
   updateElementByState(getElementById("loadDetail.cargoValue"),isCargoGreaterThan100K())

   nextLine(elements[currElement-1])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("temperature_control",1),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   addLine()

   addOption({id="coolOrFrozen",label="temperature_control_label",x=minX,y=yOffset,state = shipment.coolOrFrozen,callback=optionCallback})
   
   getElementById("certificates_section").lastElement = currElement

   adjustSectionHeight("certificates_section",elements[currElement])
   nextLine(getElementById("certificates_section"))

   insertDivider(getElementById("certificates_section"))

   nextLine(elements[currElement]);yOffset = yOffset - LINE_HEIGHT
   nextElement()
   
   elements[currElement] = display.newText({text=SceneManager.getRosettaString("trailer_selection",1),font=GC.APP_FONT,fontSize = SECTION_TITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement].id = "trailer_title"
   elements[currElement]:setFillColor(unpack(GC.ORANGE))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement]);yOffset = yOffset - LINE_HEIGHT
   nextElement()

   elements[currElement] = display.newRoundedRect(0,0,elementWidth,205,ROUNDED_SIZE)
   elements[currElement].id = "trailer_section"
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement(0)

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("trailer_selection_info"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE,width=elementWidth - PADDING * 2,align="left"})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   yOffset = elements[currElement].stageBounds.yMax
   nextElement()

   for i=1,#TRAILER_OPTIONS do
      addImage({src="graphics/trailer_"..TRAILER_OPTIONS[i].."_option.png",x=minX,y=yOffset,width=200,height=49,nextLine = false})
      nextLine(elements[currElement]);yOffset = yOffset + OPTION_HEIGHT * 0.5 - LINE_ADJUST
      addOption({id=TRAILER_OPTIONS[i],label=TRAILER_OPTIONS[i],x=minX,y=yOffset,state = shipment[TRAILER_OPTIONS[i]],callback=optionCallback})
      nextLine(elements[currElement]);addLine();addLine();
   end

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("maximum_trailer_length"),font=GC.APP_FONT,fontSize = SECTION_SUBTITLE_FONT_SIZE})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = getElementById("services").stageBounds.xMin + PADDING + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   addHelp({text="maximum_trailer_length_help",x=elements[currElement].x + elements[currElement].width * 0.5,y=elements[currElement].y})
   
   nextLine(elements[currElement])

   defaultValue = MAX_TRAILER_LENGTH_OPTIONS[1]

   if (utils.isValidParameter(shipment.maxTrailerLength)) then
      defaultValue = shipment.maxTrailerLength
   end

   addSelector({id="maxTrailerLength",value=defaultValue,options=MAX_TRAILER_LENGTH_OPTIONS,labels=MAX_TRAILER_LENGTH_LABELS,x=scrollView.x,width=elementWidth - PADDING * 2,y=yOffset - LINE_ADJUST})

   getElementById("trailer_section").lastElement = currElement

   adjustSectionHeight("trailer_section",elements[currElement])
end

function scene:create( event )
   sceneGroup = self.view

   currStep = 1
   updated = false
   isEdit = false
   trailerError = false

   addressBook = {}

   if (event.params) then
      shipment = event.params
   else
      local json = require("json")
      -- TODO: After testing uncomment below, and finish filling it out for defaults
      shipment = {}
      
      shipment.loadDetail = {
         weight="",length="",lengthInches="",width="",height="",
         commodity="",specificCommodity="",freightClass="",cargoValue=""
      }
      
      shipment.loadType = nil
      shipment.exclusiveUse = false
      shipment.certifications = {doubleTripleTrailer=false,hazmat=false,hazmatType="",twikCard=false}

      shipment.coverage = COVERAGE_OPTIONS[1]
      shipment.coolOrFrozen = false
      shipment.expedited = false

      -- Cargo Loading / Unloading
      shipment.crane = false
      shipment.dock = false
      shipment.forkLift = false
      shipment.liftGate = false
      shipment.rampLoaded = false
      shipment.rearLoaded = false
      shipment.sideLoaded = false

      -- trailers are all selected by default and any trailer length
      shipment.doubleDropDeck = true
      shipment.stepDropDeck = true
      shipment.flatbed = true
      shipment.gooseneck = true
      shipment.reefer = true
      shipment.van = true
      shipment.maxTrailerLength = MAX_TRAILER_LENGTH_OPTIONS[1]

      shipment.loadEquipment = {binders=0,blankets=0,boomers=0,chains=0,coilRacks=0,cradles=0,
         dunnage=0,levelers=0,liftGate=0,loadBars=0,lumber=0,padding=0,palletJack=0,ramps=0,
         pipeStakes=0,straps=0,pallets=0,sideKit=0,ventedVan=0,sealLockForSecurement=0,
         nurseryTarps=0,smokeTarp=0,steelTarps=0,lumberTarps=0,other=""
      }

      shipment.options = {hardhat=false,longSleeves=false,noPassengers=false,tolls=false,
         lumpers=false,layover=false,safetyGlasses=false,driverAssist=false,
         steelToedBoots=false,storage=false,fuelSurcharge=false,noPets=false,
         airRide=false,swingDoors=false,tradeShow=false,scale=false,
         other=""
      }

      shipment.packaging = {
         --{pkgType="Rolls",pkgValue=5,pkgPickup="438",pkgDropoff="426"}
      }
      
      shipment.locations = {
         --{addressGuid="438",type=11,startDate="2014-09-01",stopDate="2014-09-02",startTime="03:28 pm EST",stopTime="04:30 pm EST",podRequired=false},
         --{addressGuid="426",type=12,startDate="2014-09-07",stopDate="2014-09-07",startTime="",stopTime="",podRequired=false},
      }

      shipment.shipperNote = ""

      shipment.pricingOptions = "" -- manualSelected or fastSelected
      shipment.loadPricing = {
         reserve="700.00",paymentId=0,paymentId2=0
      }
      
      shipment.publishNow = false
      shipment.publishLater = false
      shipment.scheduledDateStr = ""

      --shipment = json.decode([[{"loadIdGuid": 385, "shipperId": 1336,
      --[[      "shipperNote":"if shipment had a note\nwith multiple lines.\nThis is what it might look like.\nNow you now.",
            "loadDetail":{"weight":10000,"length":13,"lengthInches":0,"width":100,
            "height":10,"commodity":"Electronics Includes cell phones; computers",
            "specificCommodity":"new tablets","freightClass":50,"cargoValue":100000.01},
            "tripMiles":431, "lowestQuote":555.96,
            "matchedAmount":"", "loadType":9, "exclusiveUse":true,
            "publishNow":false,"publishLater":false,"scheduledDateStr":"",
            "certifications":{"doubleTripleTrailer":true,"hazmat":true, "twikCard":true},
            "coverSelected":true, "coverage":"Either",
            "expedited":false,"maxTrailerLength":100,"crane":false,"dock":true,"forkLift":true,
            "liftGate":true,"rampLoaded":true,"rearLoaded":true,"sideLoaded":false,
            "doubleDropDeck":true,"flatbed":true,"gooseneck":true,"reefer":true,
            "stepDropDeck":true,"van":true,"coolOrFrozen":false,
            "loadEquipment":{"binders":false,"blankets":false,"boomers":false,"chains":true,
            "coilRacks":false,"cradles":false,"dunnage":false,"levelers":false,"liftGate":false,
            "loadBars":false,"lumber":false,"padding":false,"palletJack":true,"ramps":false,
            "pipeStakes":false,"straps":false,"pallets":false,"sideKit":false,"ventedVan":false,
            "sealLockForSecurement":false,"nurseryTarps":true,"smokeTarp":true,"steelTarps":true,"lumberTarps":true,"other":"duct tape"},
            "options":{"hardhat":false,"longSleeves":false,"noPassengers":false,"tolls":false,
            "lumpers":false,"layover":false,"safetyGlasses":false,"driverAssist":false,
            "steelToedBoots":false,"storage":false,"fuelSurcharge":true,"noPets":false,
            "airRide":false,"swingDoors":false,"tradeShow":false,"scale":false,
            "other":"elbow grease"}, "numQuotes":"1",
            "packaging":[{"pkgType":"Rolls","pkgValue":5,"pkgPickup":438,"pkgDropoff":426},
            {"pkgType":"Reels","pkgValue":1,"pkgPickup":423,"pkgDropoff":426}],
            "locations":[{"addressGuid":423,"type":11,"alias":"GBT","address1":"3524 E Nora St","address2":"","city":"SPRINGFIELD","state":"MO","zip":"65809","startDate":"08/25/2014","stopDate":"08/26/2014","startTime":"03:28 pm EST","stopTime":"04:30 pm EST"},
            {"addressGuid":438,"type":11,"alias":"Moonbeam","address1":"3003 E Chestnut Expy","address2":"STE 575","city":"SPRINGFIELD","state":"MO","zip":"65802","startDate":"09/02/2014","stopDate":"09/03/2014"},
            {"addressGuid":426,"type":12,"alias":"TX Office","address1":"925 S. Main St.","address2":"","city":"GRAPEVINE","state":"TX","zip":"76051","startDate":"08/29/2014","stopDate":""}],
            "pickup":{ "name":"GBT","address": "3524 E Nora St",
            "city":"SPRINGFIELD","state": "MO", "zip": "65809", "startDate":"08/18/2014",
            "stopDate":"08/18/2014"}, "delivery":{ "name":"TX Office",
            "address": "925 S. Main St.", "city": "GRAPEVINE","state": "TX", "zip": "76051",]]--
            --"startDate":"08/21/2014","stopDate":""}}]])
      
   end

   -- NOTE: Some fields need to be a certain value
   if (not tonumber(shipment.loadPricing.paymentId2)) then shipment.loadPricing.paymentId2 = 0 end

   fixDateStamps()
   
   --local json = require("json")
   --Log ("shipment: "..json.encode(shipment))

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.WHITE))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("post_shipment"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnBack.x, btnBack.y = btnBack.width * 0.5 + 5, titleBG.y
   sceneGroup:insert(btnBack)

   updateCurrStep(currStep)

   createActionLeftButton()

   btnActionRight = widget.newButton {
      id = "right",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("save_next",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 140,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnActionRight.x, btnActionRight.y = display.contentWidth - btnActionRight.width * 0.5 - PADDING , btnActionLeft.y
   btnActionRight.x = display.contentCenterX
   sceneGroup:insert(btnActionRight)

   divider = display.newRect( 0, 0, display.contentWidth, 2 )
   divider.anchorY = 0
   --divider:setFillColor(unpack(GC.DARK_GRAY))
   divider:setFillColor(1,0,0)
   divider.x, divider.y = display.contentCenterX, btnActionRight.stageBounds.yMin - PADDING
   sceneGroup:insert(divider)

   scrollView = widgetNew.newScrollView
   {
      id       = "onBottom",
      left     = 0,
      top      = 0,
      width    = display.contentWidth,
      height   = divider.stageBounds.yMin - titleBG.height,
      listener = scrollListener,
      hideBackground = true,
      bottomPadding  = 20,
      horizontalScrollDisabled   = true
   }
   scrollView.anchorY = 0
   scrollView.x, scrollView.y = display.contentCenterX, titleBG.stageBounds.yMax
   sceneGroup:insert(scrollView)

   addElements()

   calculateShipmentType()

   manageTrailers()

   --scrollToElement("pickup_dropoff")
   --datePicker:new({selectPast=false})
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.sceneExit = onBack
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      getElementById("shipperNote").isVisible = false
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
      composer.removeScene("ScenePostShipment")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnBack:removeSelf()
   btnBack = nil

   btnActionLeft:removeSelf()
   btnActionLeft = nil

   btnActionRight:removeSelf()
   btnActionRight = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   if (lblShipmentId) then
      lblShipmentId:removeSelf()
      lblShipmentId = nil
   end

   for i=1,#elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil

   scrollView:removeSelf()
   scrollView = nil
end


---------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
---------------------------------------------------------------------------------

scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

---------------------------------------------------------------------------------

return scene