local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local api = require("api")
local status = require("status")

local sceneGroup = nil
local bg = nil
local btnBack = nil
local title = nil
local titleBG = nil
local divider = nil

local elements = nil

local scrollView = nil

local PADDING = 10
local LINE_HEIGHT = 10
local LINE_ADJUST = 5
local SPACE = 5
local HEADER_HEIGHT = 40
local ROUNDED_SIZE = 7
local STROKE_WIDTH = 1
local STROKE_COLOR = GC.MEDIUM_GRAY
local BUTTON_HEIGHT = GC.BUTTON_ACTION_HEIGHT
local HELP_SIZE = 24
local BUTTON_XOFFSET = 5
local SMALL_ICON_SIZE = 10

local RADIUS_OPTIONS = {0,25,50,75,100,150,200,250}

--[[
No Freight found message:

We're Sorry...(Large)

At this time the Go By Truck network has very limited freight and none available in your search area. In an effort to bring more Shippers and their freight on board, we will be opening a sales office this month. Until then, continue to watch your Regional Alerts each morning to stay updated on the freight available in the areas you run. We look forward to keeping you rolling soon!

]]--
local STATE_OPTIONS = {
   0,"AL","AR","AZ","CA","CO","CT","DE","FL","GA","IA","ID","IL","IN","KS","KY","LA",
   "MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM","NV","NY","OH",
   "OK","OR","PA","RI","SC","SD","TN","TX","UT","VA","VT","WA","WI","WV","WY"
}

local STATE_LABELS = {
   "- -","AL","AR","AZ","CA","CO","CT","DE","FL","GA","IA","ID","IL","IN","KS","KY","LA",
   "MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM","NV","NY","OH",
   "OK","OR","PA","RI","SC","SD","TN","TX","UT","VA","VT","WA","WI","WV","WY"
}

local originCities, destinationCities

local currElement = nil
local yOffset = nil

local trailerEmpty = nil

local currTrailer

local cityUpdateID

-- form values
local trailerId
local criteria

local alertPickupCities, alertDropoffCities = nil, nil

--[[
Optional parameters for refining search later
NOTE: Some of below might change this is from a Van search.
NOTE: Form can return shipments that you can't quote or view. 
   Ex: Carrier doesn't have hazmat, but shipment requires it.

truckload, lessThanTruckload, overDimensional
autoaccept

blanketsPalettesAndLoadTypes:
blankets,dunnage,expedited,lumper,padding,pallets,hazmat,scaleTickets

bindersAndStraps:
binders,boomers,chains,coilRacks,cradles,levelers,lumber,nursery,pipeStakes,
ramps,sideKit,smoke,steel,straps

vansAndReefers:
loadBars,palletJack,sealLock,ventedVan,liftGate

findFreight

sent Fields:
trailerId=
-- Returned fields
{"loadIdGuid":"367","shipperId":"1336","shipperScore":"100.0","autoAccept":false,
"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX",
"stops":"1","pieces":"3","weight":"13000","commodity":"Agricultural - Mulch",
"tripMiles":"606","pickUpDate":"10/03/2014","deliveryDate":"11/01/2014",
"lowestQuote":"300.00","loadType":"8"}
]]--
local startToggleEmpty


local messageQ = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end
end

local function nextLine(previous)
   if (not previous) then
      yOffset = yOffset + LINE_HEIGHT
   else
      yOffset = previous.y + previous.height * 0.5 + LINE_HEIGHT
   end
end

local function nextElement()
   currElement = #elements + 1
end

local function addOncomplete(event)
   local i = event.target.id
   if (i == 2) then
      SceneManager.goToAddEditTrailer()
   end
end

local function promptAddTrailer()
   alert:show({title=SceneManager.getRosettaString("add_trailer"),buttonAlign = "horizontal",
      message=SceneManager.getRosettaString("add_trailer_message"),
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("add")},callback=addOncomplete})
end

local function validate()
   local valid1 = (currTrailer ~= nil)
   if (not valid1) then
      promptAddTrailer()
   end

   local valid2 = (criteria.length ~= "" and criteria.width ~= "" and criteria.weight ~= "")
   getElementById("error2").isVisible = not valid2
   
   -- Note: New version of the site doesn't require cities to be selected. Keeping for reference in case this flipflops in the future
   --local valid3 = ((criteria.originState ~= STATE_OPTIONS[1] and criteria.originCity ~= "" and criteria.originCity ~= SceneManager.getRosettaString("select_a_city")) or (criteria.destinationState ~= STATE_OPTIONS[1] and criteria.destinationCity ~= "" and criteria.destinationCity ~= SceneManager.getRosettaString("select_a_city")))
   local valid3 = ((criteria.originState ~= STATE_OPTIONS[1]) or (criteria.destinationState ~= STATE_OPTIONS[1]))
   getElementById("error3").isVisible = not valid3
   
   return valid1 and valid2 and valid3
end

local function findFreightCallback(response)
   local messageQ = nil

   if (response == nil or response.shipments == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      -- turn address1..address2..addressn into locations table
      local shipments = {}
      local i, j = 1,1
      
      while (response.shipments["shipment"..i]) do
         table.insert( shipments, response.shipments["shipment"..i] )
         -- turn address1..address2..addressn into locations table
         shipments[i].locations = {}
         j = 1
         while (shipments[i]["address"..j]) do
            table.insert(shipments[i].locations,shipments[i]["address"..j])
            shipments[i]["address"..j] = nil
            j = j + 1
         end
         i = i + 1
      end
      --local json = require("json")
      --print ("JSON: "..json.encode(shipments))
      --print ("found "..#response.shipments.." shipment(s)")
      
      if (#shipments > 0) then
         -- NOTE: Maybe show results on overlay, so we don't have to recreate this scene
            composer.gotoScene("SceneFindFreightResults",{effect=GC.OVERLAY_ACTION_SHOW,time=GC.SCENE_TRANSITION_TIME_MS,params={shipments=shipments}})
            --SceneManager.goToFindFreightResults({shipments=shipments})
      else
            alert:show({title=SceneManager.getRosettaString("find_freight_no_results_title"),
            message=SceneManager.getRosettaString("find_freight_no_results_message"),
            buttons={SceneManager.getRosettaString("ok")}
            })
      end
   end
   
   showMessage()
end

local function onSubmit()
   if (validate()) then
      api.findFreight(criteria,findFreightCallback)
   else
      alert:show({
         title=SceneManager.getRosettaString("missing_field"),
         message=SceneManager.getRosettaString("missing_field_message"),
         buttons={SceneManager.getRosettaString("ok")}
      })
   end
end

local function onHelp(section)
   alert:show({message = SceneManager.getRosettaString("find_freight_help_section"..section),
      buttons={SceneManager.getRosettaString("ok")}})
end

local function getTrailerWidth(id)
   if (objects[id].width == "other") then
      return objects[id].widthOther
   end
   
   return objects[id].width
end

local function getTrailerLength(id)
   if (objects[id].length == "other") then
      return objects[id].lengthOther
   end
   
   return objects[id].length
end

local function getTrailerWeight(id)
   return objects[id].maxPayload
end

local function buildTrailerLabel(trailer)
   local label = objects[trailer].trailerType.." "

   label = label..getTrailerLength(trailer)
   
   label = label.."x"

   label = label..getTrailerWidth(trailer)

   label = label.." Max: "..getTrailerWeight(trailer).." lbs"

   return label
end

local function updateEmptyState()
   getElementById("x").isVisible = not trailerEmpty
   getElementById("check").isVisible = trailerEmpty

   if (trailerEmpty) then
      getElementById("width"):disable()
      criteria.width = getTrailerWidth(currTrailer)
      getElementById("length"):disable()
      criteria.length = getTrailerLength(currTrailer)
      getElementById("weight"):disable()
      criteria.weight = getTrailerWeight(currTrailer)
   else
      criteria.width, criteria.length, criteria.weight = "","",""
      getElementById("width"):enable()
      getElementById("length"):enable()
      getElementById("weight"):enable()
   end
   
   getElementById("width"):setLabel(criteria.width)
   getElementById("length"):setLabel(criteria.length)
   getElementById("weight"):setLabel(criteria.weight)
   
end

local function toggleEmptyState()
   trailerEmpty = not trailerEmpty
   updateEmptyState()
end

local function selectTrailer(num)
   currTrailer = num
   criteria.trailerId = objects[currTrailer].trailerId
   getElementById("trailer"):setLabel(buildTrailerLabel(currTrailer))
   if (trailerEmpty) then updateEmptyState(); end
end

local function findIndexByTrailerId(id)
   for i = 1, #objects do
      if (objects[i].trailerId == id) then
         return i
      end
   end

   return currTrailer
end

local function populateTrailers()
   -- NOTE: Current webapp selection to the last added trailer regardless of state
   if (startToggleEmpty) then
      trailerEmpty = true

      startToggleEmpty = false
   end

   if (not currTrailer) then
      selectTrailer(1)
   else
      selectTrailer(findIndexByTrailerId(objects[currTrailer].trailerId))
   end
   getElementById("trailer"):enable()
end

local function getTrailerOptions()
   local options = {}

   for i = 1, #objects do
      table.insert( options, buildTrailerLabel(i) )
   end

   --table.insert(options, SceneManager.getRosettaString("cancel"))

   return options
end

local function findRadiusIndex(value)
   local index = 0
   for i = 1, #RADIUS_OPTIONS do
      if RADIUS_OPTIONS[i] == value then
         index = i
      end
   end

   return index
end

local function getRadiusOptions()
   return RADIUS_OPTIONS
end

local function getRadiusLabel(value)
   if (value == 0) then
      return "- "..SceneManager.getRosettaString("select").." -"
   end

   return value
end

local function getStateLabel(value)
   if (value == 0) then
      return STATE_LABELS[1]
   end

   return value
end

local function errorOncomplete()
   SceneManager.goToDashboard()
end

local function updateCitySelectorState(id,value)
   if (value == 0) then
      getElementById(id):disable()
   else
      getElementById(id):enable()
   end
end

local function getCitiesCallback(response)
   local messageQ = nil

   -- TODO: Can't do anything if an error, so this should be an alert box forcing us to go back
   if (response == nil or response.cities == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      -- NOTE: Below for reference if API call changes back to original website one
      --local cityList = utils.split(response.cityList,":")

      --print ("found "..#response.cities.." cities")
      
      if (#response.cities > 1) then
         table.insert(response.cities,1,SceneManager.getRosettaString("select_a_city"))
         if (cityUpdateID == "originState") then
            originCities = utils.shallowcopy(response.cities)
            criteria.originCity = response.cities[1]
            getElementById("originCity"):setLabel(criteria.originCity)
            getElementById("originCity"):enable()

            -- TODO: Find a way to create an alert, so it seems faster
         else
            destinationCities = utils.shallowcopy(response.cities)
            criteria.destinationCity = response.cities[1]
            getElementById("destinationCity"):setLabel(criteria.destinationCity)
            getElementById("destinationCity"):enable()
         end
      end
   end
   
   if (messageQ) then
      alert:show({title=SceneManager.getRosettaString("error"),buttonAlign = "horizontal",
      message=SceneManager.getRosettaString("server_error_message"),
      buttons={SceneManager.getRosettaString("ok")},callback=errorOncomplete})
   end
end

local function getObjectsCallback(response)
   local messageQ = nil

   -- TODO: Can't do anything if an error, so this should be an alert box forcing us to go back
   if (response == nil or response.trailers == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      objects = response.trailers
      if (#objects > 0) then
         populateTrailers()
      else
         getElementById("trailer"):disable()
         promptAddTrailer()
      end
   end
   
   if (messageQ) then
      alert:show({title=SceneManager.getRosettaString("error"),buttonAlign = "horizontal",
      message=SceneManager.getRosettaString("server_error_message"),
      buttons={SceneManager.getRosettaString("ok")},callback=errorOncomplete})
   end
end

local function getObjects()
   if (_G.messageQ) then
      messageQ = _G.messageQ
      _G.messageQ = nil
      --showMessage()
   end

   api.getMyTrailers({sid=SceneManager.getUserSID(),callback=getObjectsCallback})
end

local function trailerCallback(event,value)
   if (value) then
      selectTrailer(value)
   end
end

local function alertOnComplete( event,value )
   local i = event.target.id
   
   if (event.id == "length" and i == 2) then
      if (value) then
         criteria.length = value
         getElementById("length"):setLabel(value)
      end
   elseif (event.id == "width" and i == 2) then
      if (value) then
         criteria.width = value
         getElementById("width"):setLabel(value)
      end
   elseif (event.id == "weight" and i == 2) then
      if (value) then
         criteria.weight = value
         getElementById("weight"):setLabel(value)
      end
   end
end

local function onLength()
   alert:show({title = SceneManager.getRosettaString("length"),id="length",
      input = {text=criteria.length,type="number",maxlength=3},buttonAlign="horizontal",cancel=1,
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onWidth()
   alert:show({title = SceneManager.getRosettaString("width"),id="width",
      input = {text=criteria.width,type="number",maxlength=3},buttonAlign="horizontal",cancel=1,
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onWeight()
   alert:show({title = SceneManager.getRosettaString("weight"),id="weight",
      input = {text=criteria.weight,type="number",maxlength=6},buttonAlign="horizontal",cancel=1,
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

-- TODO: Need an API request to fullfil this
local function getCitiesByState(id,state)
   cityUpdateID = id
   api.getCitiesByState({sid=SceneManager.getUserSID(),state=state,callback=getCitiesCallback})
end

local function selectorCallback(event,value)
   if (event.id == "originRadius") then
      criteria.originRadius = RADIUS_OPTIONS[value]
      getElementById("originRadius"):setLabel(getRadiusLabel(criteria.originRadius))
   elseif (event.id == "destinationRadius") then
      criteria.destinationRadius = RADIUS_OPTIONS[value]
      getElementById("destinationRadius"):setLabel(getRadiusLabel(criteria.destinationRadius))
   elseif (event.id == "originState") then
      if (STATE_OPTIONS[value] ~= criteria.originState) then
         criteria.originState = STATE_OPTIONS[value]
         getElementById("originState"):setLabel(STATE_LABELS[value])
         criteria.originCity = ""
         getElementById("originCity"):setLabel(criteria.originCity)
         getElementById("originCity"):disable()
         if (criteria.originState ~= STATE_OPTIONS[1]) then
            getCitiesByState("originState",criteria.originState)
         end
      end
   elseif (event.id == "destinationState") then
      if (STATE_OPTIONS[value] ~= criteria.destinationState) then
         criteria.destinationState = STATE_OPTIONS[value]
         getElementById("destinationState"):setLabel(STATE_LABELS[value])
         criteria.destinationCity = ""
         getElementById("destinationCity"):setLabel(criteria.destinationCity)
         getElementById("destinationCity"):disable()
         if (criteria.destinationState ~= STATE_OPTIONS[1]) then
            getCitiesByState("destinationState",criteria.destinationState)
         end
      end
   elseif (event.id == "originCity") then
      criteria.originCity = originCities[value]
      getElementById("originCity"):setLabel(criteria.originCity)
   elseif (event.id == "destinationCity") then
      criteria.destinationCity = destinationCities[value]
      getElementById("destinationCity"):setLabel(criteria.destinationCity)
   end
end

local function onRadius(radius,selected)
   alert:show({title=SceneManager.getRosettaString("radius"),id=tostring(radius),
      list = {options = getRadiusOptions(),selected = selected},
      buttons={SceneManager.getRosettaString("cancel")},cancel = 1,callback=selectorCallback})
end

local function showOptions(title,options,id,selected)
   local hasFilter = false
   local rowHeight = nil
   local listRows = nil

   if (id == "originCity" or id == "destinationCity") then
      hasFilter = true
      rowHeight = 40
      listRows = 5
   end

   alert:show({title=title,id=id,rowHeight=rowHeight,
      list = {options = options,selected = selected, hasFilter = hasFilter, filterType = "substring",listRows = listRows},
      buttons={SceneManager.getRosettaString("cancel")},cancel = 1,callback=selectorCallback})
end

local function findOptionIndex(t,value)
   for i=1, #t do
      if (t[i] == value) then
         return i
      end
   end

   return 1
end

local function onOriginCity()
   showOptions(SceneManager.getRosettaString("pick_up_city"),originCities,"originCity",findOptionIndex(originCities,criteria.originCity))
end

local function onDestinationCity()
   showOptions(SceneManager.getRosettaString("drop_off_city"),destinationCities,"destinationCity",findOptionIndex(destinationCities,criteria.destinationCity))
end

local function onOriginState()
   showOptions(SceneManager.getRosettaString("state"),STATE_LABELS,"originState",findOptionIndex(STATE_OPTIONS,criteria.originState))
end

local function onDestinationState()
   showOptions(SceneManager.getRosettaString("state"),STATE_LABELS,"destinationState",findOptionIndex(STATE_OPTIONS,criteria.destinationState))
end

local function onEventCallback(event)
   if (event.phase == "release") then
   	if (event.target.id == "back") then
         SceneManager.goToDashboard()
      elseif (string.sub(event.target.id,1,4) == "help") then
         -- TODO: This is terrible, but pressed for a demo. Please fix!
         onHelp(string.sub(event.target.id,5,5))
      elseif (event.target.id == "find") then
         onSubmit()
      elseif (event.target.id == "trailer") then
         if (#objects > 0) then
            alert:show({title=SceneManager.getRosettaString("please_select"),width=display.contentWidth - PADDING * 2,
               list = {options = getTrailerOptions(),selected = currTrailer,fontSize=14},
               buttons={SceneManager.getRosettaString("cancel")},cancel = 1,
               callback=trailerCallback})
         else
            -- No trailers, prompt user to add one
            promptAddTrailer()
         end
      elseif (event.target.id == "add") then
         SceneManager.goToAddEditTrailer()
      elseif (event.target.id == "trailerEmpty") then
         toggleEmptyState()
      elseif (event.target.id == "length") then
         onLength()
      elseif (event.target.id == "width") then
         onWidth()
      elseif (event.target.id == "weight") then
         onWeight()
      elseif (event.target.id == "originState") then
         onOriginState()
      elseif (event.target.id == "destinationState") then
         onDestinationState()
      elseif (event.target.id == "originCity") then
         onOriginCity()
      elseif (event.target.id == "destinationCity") then
         onDestinationCity()
      elseif (event.target.id == "originRadius") then
         onRadius("originRadius",findRadiusIndex(criteria.originRadius))
      elseif (event.target.id == "destinationRadius") then
         onRadius("destinationRadius",findRadiusIndex(criteria.destinationRadius))
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

function scene:create( event )
	sceneGroup = self.view

   currTrailer = nil
   trailerEmpty = false
   startToggleEmpty = true

   --width, length, weight = "","",""
   --originCity, destinationCity = "",""
   --originState, destinationState = 0,0
   --originRadius, destinationRadius = 0,0

   -- table holds all of the search criteria
   -- this way we can easily expand because 
   -- API creates query string from the table =)
   criteria = {}
   criteria.sid = SceneManager.getUserSID()
   criteria.width, criteria.length, criteria.weight = "","",""
   criteria.originCity, criteria.originState, criteria.originRadius = "",0,0
   criteria.destinationCity, criteria.destinationState, criteria.destinationRadius = "",0,0

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("find_freight"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
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

   btnFindFreight = widget.newButton{
      id = "find",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      xOffset = 12, -- cheap hack to center icon + label
      label=SceneManager.getRosettaString("find_freight",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      icon = {default="graphics/search.png",width=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,height=GC.DASHBOARD_BAR_BUTTON_ICON_SIZE,align="left"},
      width = 180,
      height = BUTTON_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnFindFreight.x, btnFindFreight.y = display.contentCenterX, display.contentHeight - btnFindFreight.height * 0.5 - PADDING
   sceneGroup:insert(btnFindFreight)

   divider = display.newRect( 0, 0, display.contentWidth, 2 )
   divider.anchorY = 0
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnFindFreight.stageBounds.yMin - PADDING
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

   elements = {}
   local elementWidth = scrollView.width - PADDING * 2
   yOffset = 0

   nextElement()
   nextLine()

   elements[currElement] = display.newRoundedRect(0,0,elementWidth,140,ROUNDED_SIZE)
   elements[currElement].id = "section1"
   elements[currElement]:setFillColor(unpack(GC.WHITE))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   local minX = elements[currElement].stageBounds.xMin + PADDING
   local halfWidth = (elementWidth - PADDING * 3) * 0.5
   local midX = minX + halfWidth + PADDING

   nextElement()

   elements[currElement] = display.newRect(0,0,elementWidth,HEADER_HEIGHT,ROUNDED_SIZE)
   elements[currElement]:setFillColor({type='gradient', color1=GC.WHITE,color2=GC.LIGHT_GRAY2,direction="down"})
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, elements[currElement-1].y - elements[currElement-1].height * 0.5 + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("step",1).." 1:",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("find_freight_step1_label",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "help1",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.ORANGE,
      default="graphics/question.png",
      width = HELP_SIZE,
      height = HELP_SIZE,
      onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX + elementWidth * 0.5 - elements[currElement].width * 0.5 - SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextLine(elements[2])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "trailer",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      overColor = GC.LIGHT_GRAY2,
      width = elementWidth - PADDING * 2,height = BUTTON_HEIGHT,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   elements[currElement]:disable()
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "add",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("add_new_trailer_type"),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 180,
      height = BUTTON_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(getElementById("section1"))
   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,220,ROUNDED_SIZE)
   elements[currElement].id = "section2"
   elements[currElement]:setFillColor(unpack(GC.WHITE))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect(0,0,elementWidth,HEADER_HEIGHT,ROUNDED_SIZE)
   elements[currElement]:setFillColor({type='gradient', color1=GC.WHITE,color2=GC.LIGHT_GRAY2,direction="down"})
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, elements[currElement-1].y - elements[currElement-1].height * 0.5 + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("step",1).." 2:",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("find_freight_step2_label",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "help2",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.ORANGE,
      default="graphics/question.png",
      width = HELP_SIZE,
      height = HELP_SIZE,
      onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX + elementWidth * 0.5 - elements[currElement].width * 0.5 - SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("length",1)..":",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("width",1)..":",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "length",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect( 0, 0, halfWidth * 0.4, BUTTON_HEIGHT )
   elements[currElement]:setFillColor(unpack(GC.LIGHT_GRAY))
   elements[currElement].strokeWidth = 1
   elements[currElement]:setStrokeColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax - elements[currElement].width * 0.5 - BUTTON_XOFFSET, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("feet",0),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "width",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect( 0, 0, halfWidth * 0.4, BUTTON_HEIGHT )
   elements[currElement]:setFillColor(unpack(GC.LIGHT_GRAY))
   elements[currElement].strokeWidth = 1
   elements[currElement]:setStrokeColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax - elements[currElement].width * 0.5 - BUTTON_XOFFSET, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("inches",0),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("weight",1)..":",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "weight",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect( 0, 0, halfWidth * 0.4, BUTTON_HEIGHT )
   elements[currElement]:setFillColor(unpack(GC.LIGHT_GRAY))
   elements[currElement].strokeWidth = 1
   elements[currElement]:setStrokeColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax - elements[currElement].width * 0.5 - BUTTON_XOFFSET, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("pounds",0),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "trailerEmpty",x = 0,y = 0,
      width = halfWidth,height = BUTTON_HEIGHT,
      defaultColor = GC.WHITE, overColor = GC.LIGHT_GRAY2,
      label = SceneManager.getRosettaString("my_trailer_empty"),
      labelColor = { default=GC.MEDIUM_GRAY, over=GC.MEDIUM_GRAY }, fontSize = 12, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newImageRect("graphics/x.png", SMALL_ICON_SIZE, SMALL_ICON_SIZE )
   elements[currElement].id = "x"
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SMALL_ICON_SIZE * 0.5 + SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newImageRect("graphics/check.png", SMALL_ICON_SIZE, SMALL_ICON_SIZE )
   elements[currElement].id = "check"
   elements[currElement].isVisible = false
   elements[currElement].x, elements[currElement].y = elements[currElement-1].x, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextLine(getElementById("trailerEmpty"))
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("find_freight_error_section2"),width = elementWidth, font=GC.APP_FONT,fontSize = 12,align="center"})
   elements[currElement].id = "error2"
   elements[currElement].isVisible = false
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(getElementById("section2"))
   nextElement()
   
   elements[currElement] = display.newRoundedRect(0,0,elementWidth,285,ROUNDED_SIZE)
   elements[currElement].id = "section3"
   elements[currElement]:setFillColor(unpack(GC.WHITE))
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newRect(0,0,elementWidth,HEADER_HEIGHT,ROUNDED_SIZE)
   elements[currElement]:setFillColor({type='gradient', color1=GC.WHITE,color2=GC.LIGHT_GRAY2,direction="down"})
   elements[currElement].strokeWidth = STROKE_WIDTH
   elements[currElement]:setStrokeColor(unpack(STROKE_COLOR))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, elements[currElement-1].y - elements[currElement-1].height * 0.5 + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("step",1).." 3:",font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.MEDIUM_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("find_freight_step3_label",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMax + SPACE + elements[currElement].width * 0.5, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "help3",
      defaultColor = GC.DARK_GRAY,
      overColor = GC.ORANGE,
      default="graphics/question.png",
      width = HELP_SIZE,
      height = HELP_SIZE,
      onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX + elementWidth * 0.5 - elements[currElement].width * 0.5 - SPACE, elements[currElement-1].y
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("state",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("state",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "originState",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = getStateLabel(criteria.originState),
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "destinationState",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = getStateLabel(criteria.destinationState),
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("pick_up_city",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("drop_off_city",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "originCity",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = originCity,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   updateCitySelectorState("originCity",criteria.originState)
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "destinationCity",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = destinationCity,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   updateCitySelectorState("destinationCity",criteria.originState)
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("radius",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("radius",1),font=GC.APP_FONT,fontSize = 14})
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "originRadius",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = getRadiusLabel(criteria.originRadius),
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = widget.newButton{
      id = "destinationRadius",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = halfWidth,height = BUTTON_HEIGHT,
      label = getRadiusLabel(criteria.destinationRadius),
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      overColor = GC.LIGHT_GRAY2,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = midX + elements[currElement].width * 0.5 - BUTTON_XOFFSET * 0.5, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText({text=SceneManager.getRosettaString("find_freight_error_section3"),width = elementWidth, font=GC.APP_FONT,fontSize = 12,align="center"})
   elements[currElement].id = "error3"
   elements[currElement].isVisible = false
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = display.contentCenterX, yOffset + elements[currElement].height * 0.5 - LINE_ADJUST
   scrollView:insert(elements[currElement])

   getObjects()

end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      composer.removeScene("SceneFindFreightResults")
      _G.sceneExit = SceneManager.goToDashboard
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
      --composer.removeScene("SceneFindFreight")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnBack:removeSelf()
   btnBack = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   for i=1,#elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil

   scrollView:removeSelf()
   scrollView = nil
end

function scene:update()
   getObjects()
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