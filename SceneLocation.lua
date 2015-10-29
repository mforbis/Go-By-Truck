local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local alert = require("alertBox")
local toggle = require("toggle")
local timePicker = require("timePicker")
local datePicker = require("datePicker")

local PADDING = 10
local SPACE = 5
local SELECTOR_DEFAULT_WIDTH = 240
local SELECTOR_DEFAULT_HEIGHT = 38
local BUTTON_HEIGHT = 38
local BUTTON_XOFFSET = 5
local OPTION_HEIGHT = 30

local sceneGroup = nil
local bg = nil
local btnDone = nil
local title = nil
local titleBG = nil
local overlay = nil
local btnStartTime, btnStopTime = nil, nil

local elements = nil
local index = 0

local data = nil

local currSelection

local callback = nil

local function onDone()
   if (data.location.startDate == "") then
      alert:show({
         title = SceneManager.getRosettaString("fields_not_set_title"),
         message = SceneManager.getRosettaString("fields_not_set_message")..":\n"..SceneManager.getRosettaString("start_date"),
         buttons={SceneManager.getRosettaString("ok")},buttonHeight=30
      })
   else
      if (callback) then callback(); end
      composer.hideOverlay("zoomOutInFade",200)
   end
end

local function onEventCallback(event)
   if (event.target.id == "blank") then
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

local function nextElement()
   index = #elements + 1
end

local function getCompanyDetails(id)
   local details = ""

   for i=1,#data.addressBook do
      if (tostring(data.addressBook[i].addressGuid) == tostring(id)) then
         details = data.addressBook[i].alias.."\n"
         -- NOTE: Not sure why this is now failing
         --details = details..data.addressBook[i].address1.." "..data.addressBook[i].address2.." "..data.addressBook[i].zip
         details = details..(data.addressBook[i].address or "").." ".." "..(data.addressBook[i].zip or "")
      end
   end

   return details
end

local function getLocationLabelById(id,which)
   local label = SceneManager.getRosettaString("select_"..which.."_location")

   for i=1,#data.addressBook do
      if (tostring(data.addressBook[i].addressGuid) == tostring(id)) then
         label = data.addressBook[i].alias.." - "..data.addressBook[i].address1
         break
      end
   end

   return label
end

local function getLocationLabels(locations,which)
   local labels = {SceneManager.getRosettaString("select_"..which.."_location")}

   local lType = GC.LOCATION_TYPE_PICKUP
   if (which == "dropoff") then
      lType = GC.LOCATION_TYPE_DROPOFF
   end

   for i=1,#locations do
      if (locations[i].type == lType) then
         table.insert(labels,getLocationLabelById(locations[i].addressGuid,which))
      end
   end

   return labels
end

local function getLocationOptions(locations,which)
   local options = {"0"}
   
   local lType = GC.LOCATION_TYPE_PICKUP
   if (which == "dropoff") then
      lType = GC.LOCATION_TYPE_DROPOFF
   end

   for i = 1,#locations do
      if (locations[i].type == lType) then
         table.insert(options,locations[i].addressGuid)
      end
   end

   return options
end

local function updateElementsBasedOnType(eType)
   local tState = (eType == GC.LOCATION_TYPE_DROPOFF)

   getElementById("podRequired").isVisible = tState
   getElementById("podRequired_label").isVisible = tState
   if (eType ~= data.location.type) then
      getElementById("podRequired").setState(tState)
      getElementById("podRequired").setToggleState(tState)
   end
end

local function selectorSetLabel(selector)
   local label = selector.labels[1]
   
   if (selector.value ~= nil) then
      for i=1,#selector.options do
         --print ("comparing: "..tostring(selector.value).." to '"..tostring(selector.options[i]).."'")
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
   
   --print ("selector: id = "..selector.id..", value: "..tostring(selector.value))
   if (selector.id == "type") then
      updateElementsBasedOnType(selector.value)
   end
   data.location[selector.id] = selector.value
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

   elements[index] = widget.newButton {
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

   elements[index].value = params.value
   elements[index].options = params.options
   elements[index].labels = params.labels
   elements[index].fontSize = params.fontSize

   elements[index].x, elements[index].y = params.x, params.y + elements[index].height * 0.5
   selectorSetLabel(elements[index])

   if (params.enabled == false) then
      elements[index]:disable()
   end

   sceneGroup:insert(elements[index])
end

local function inputSetValue(id, value)
   local input = currSelection
   print ("id: "..tostring(id)..", value: '"..tostring(value).."'")
   if (input) then
      -- TODO: Checks based on which
      if (id == "startDate" or id == "stopDate") then
         -- yyyy/mm/dd
         -- TODO: Provide date picker to help
      elseif (id == "startTime" or id == "stopTime") then
         -- hh:mm am/pm (EST,CST,MST,PST)
         -- TODO: Provide overlay to ensure good data
      end
      input.value = value
      input:setLabel(value)
      --print ("input id: "..id)
      data.location[id] = value
   end
end

local function inputOnComplete(event,value)
   local i = event.target.id
   
   if (i == 2) then
      if (event.id) then
         inputSetValue(event.id,value)
      end
   end
end

local function showInput(event)
   if (event.phase == "release") then
      if (event.target.id) then
         currSelection = event.target
         
         alert:show({title = event.target.title,id=event.target.id,
            input = {text=event.target.value,type=event.target.type,maxlength=event.target.maxLength},buttonAlign="horizontal",
            buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
            callback=inputOnComplete})
         
         --datePicker:new({selectPast=false,date=event.target.value})
      end
   end
end

local function addInput(params)
   local xOffset = 0

   if (params.label) then
      addTextElement({
         id=params.id.."_label",
         text=SceneManager.getRosettaString(params.label),
         x=params.x,
         y=params.y,multiline = false,
         yOffset = elements[index].height * 0.5,
         align=params.align or "left",
         color=params.color or GC.DARK_GRAY})
      elements[index].id = params.id.."_label"
      if (params.xOffset == "right") then
         xOffset = elements[index].width + (params.width or INPUT_DEFAULT_WIDTH)
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
      --icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true}
   end

   elements[index] = widget.newButton{
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
   
   elements[index].x, elements[index].y = params.x + xOffset, params.y
   elements[index].maxLength = params.maxLength
   elements[index].value = params.value
   elements[index]:setLabel(params.value)
   elements[index].type = params.type or "text"
   elements[index].title = params.title or SceneManager.getRosettaString("please_enter")
   sceneGroup:insert(elements[index])
end

local function addTextElement(params)
   nextElement()
   local yAdjust = 0
   local align = params.align or "left"

   if params.multiline then
      elements[index] = display.newText( {text = params.text, x=0,y=0,width = bg.width - PADDING * 2,font=params.font or APP_FONT, fontSize = params.size or 14, align=align} )
      yAdjust = elements[index].height * 0.5
      -- If from an option, try to align it with the box
      if (params.yOffset) then
         yAdjust = yAdjust - params.yOffset
      end
   else
      elements[index] = display.newText({text = params.text,x=0,y=0,font=APP_FONT,fontSize = params.size or 14, align=align})
   end

   sceneGroup:insert(elements[index])

   if (align == "left") then
      elements[index].anchorX = 0
   elseif (align == "right") then
      elements[index].anchorX = 1
   end
   elements[index].x, elements[index].y = params.x,params.y + yAdjust
   elements[index]:setFillColor(unpack(params.color or GC.DARK_GRAY))
end

local function optionCallback(element)
   --print (element.id,element.state)
   data.location[element.id] = element.state
end

local function addOption(params)
   local size = params.size or OPTION_HEIGHT
   nextElement()
   
   local baseImg = "check"
   if (params.type == "radio") then
      baseImg = "radio"
   end

   elements[index] = toggle.new({id=params.id, x = 0, y = 0,on = "graphics/"..baseImg.."_on.png", onWidth = size, onHeight = size,
               off = "graphics/"..baseImg.."_off.png", offWidth = size, offHeight = size,
               state = params.state or false, callback = params.callback or onEventCallback})
   if (params.enabled ~= nil) then
      elements[index].setToggleState(params.enabled)
   end

   elements[index].type = "boolean"

   sceneGroup:insert(elements[index])
   elements[index].x, elements[index].y = params.x + elements[index].width * 0.5,params.y
   
   addTextElement({text=SceneManager.getRosettaString(params.label),x=params.x + elements[index].width + SPACE,y=params.y,multiline = params.multiline,yOffset = elements[index].height * 0.5,align=params.align,color=params.color})
   elements[index].id = params.id.."_label"

   if (params.hasHelp) then
      addHelp({id=params.id,x=elements[index].x + elements[index].width * 0.5,y=params.y})
   end
end

local function onTimeComplete(event)
   if (event.id == "start") then
      data.location.startTime = event.time
      btnStartTime:setLabel(event.time)
   elseif (event.id == "stop") then
      data.location.stopTime = event.time
      btnStopTime:setLabel(event.time)
   end
end

local function onStartTime()
   timePicker:show({id="start",time=data.location.startTime,callback=onTimeComplete})
end

local function onStopTime()
   timePicker:show({id="stop",time=data.location.stopTime,callback=onTimeComplete})
end

function scene:create( event )
   sceneGroup = self.view

   elements = {}

   if (event.params) then
      if (event.params.callback and type(event.params.callback) == "function") then
         callback = event.params.callback
      end
      if (event.params.data) then
         data = event.params.data
      end
   end

   if (data == nil) then
      data = {
         location = {addressGuid="438",type=11,startDate="2014/09/01",endDate="2014/09/02",startTime="",stopTime="04:30 pm EST",podRequired=false},
            --{addressGuid="426",type=12,startDate="2014/09/07",endDate="2014/09/07",startTime="",stopTime="",podRequired=false},
         addressBook = {
            {addressGuid = 438,alias="Moonbeam",address1="3003 E Chestnut Expy",address2="STE 575",city="SPRINGFIELD",state="MO",zip="65802",phoneNumber="417-501-6682",contactEmail="support@moonbeam.co",contactName="MoonbeamDev"},
            {addressGuid = 426,alias="TX Office",address1="925 S. Main St.",address2="",city="GRAPEVINE",state="TX",zip="76051"},
         }
      }
   end

   overlay = display.newRect(sceneGroup,0, 0, 360, 570)
   overlay:setFillColor(0,0,0,0)
   overlay.x, overlay.y = display.contentCenterX, display.contentCenterY

   bg = display.newRect(sceneGroup,0,0,display.contentWidth - 20,400)
   bg:setFillColor(1,1,1)
   bg.strokeWidth = 1
   bg:setStrokeColor(unpack(GC.DARK_GRAY))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, bg.width, 40 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY2))
   titleBG.x, titleBG.y = display.contentCenterX, bg.stageBounds.yMin + titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("manage_location"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   local elementWidth = bg.width - PADDING * 2
   local halfWidth = (bg.width - PADDING * 3) * 0.5
   local minX = bg.stageBounds.xMin + PADDING
   local yOffset = titleBG.stageBounds.yMax + PADDING

   addTextElement({text=getCompanyDetails(data.location.addressGuid),multiline=true,x=display.contentCenterX,y=yOffset,align="center",color=GC.DARK_GRAY})

   yOffset = elements[index].stageBounds.yMax + PADDING * 2
   
   addTextElement({text="*",x=minX,y=yOffset,color=GC.RED,size=30})
   addTextElement({text=SceneManager.getRosettaString("pickup_or_dropoff"),x=minX + SPACE * 3,y=yOffset,align="left",color=GC.DARK_GRAY})

   yOffset = elements[index].stageBounds.yMax + PADDING * 0.5
   
   addSelector({id="type",width=elementWidth,value=data.location.type,options={GC.LOCATION_TYPE_PICKUP,GC.LOCATION_TYPE_DROPOFF},labels={SceneManager.getRosettaString("pickup_location"),SceneManager.getRosettaString("dropoff_location")},x=display.contentCenterX,y=yOffset})
   
   yOffset = elements[index].stageBounds.yMax + PADDING * 2
   
   addTextElement({text="*",x=minX,y=yOffset,color=GC.RED,size=30})
   addTextElement({text=SceneManager.getRosettaString("date_range"),x=minX + SPACE * 3,y=yOffset,align="left",color=GC.DARK_GRAY})

   yOffset = elements[index].stageBounds.yMax + BUTTON_HEIGHT * 0.5 + PADDING * 0.5

   addInput({id="startDate",title=SceneManager.getRosettaString("start_date"),hint=SceneManager.getRosettaString("start_date"),value=data.location.startDate,width=halfWidth,x=minX + halfWidth * 0.5,y=yOffset})
   addInput({id="stopDate",title=SceneManager.getRosettaString("stop_date"),hint=SceneManager.getRosettaString("stop_date").." ("..SceneManager.getRosettaString("optional")..")",value=data.location.stopDate,width=halfWidth,x=display.contentCenterX + PADDING * 0.5 + halfWidth * 0.5,y=yOffset})
   
   yOffset = elements[index].stageBounds.yMax + PADDING * 2
   
   addTextElement({text=SceneManager.getRosettaString("start_time"),x=minX,y=yOffset,align="left",color=GC.DARK_GRAY})
   addTextElement({text=SceneManager.getRosettaString("stop_time"),x=display.contentCenterX + PADDING * 0.5,y=yOffset,align="left",color=GC.DARK_GRAY})

   yOffset = elements[index].stageBounds.yMax + BUTTON_HEIGHT * 0.5 + PADDING * 0.5

   btnStartTime = widget.newButton {
      x = 0,y = 0,labelAlign="left",xOffset = 5,
      width = halfWidth,height = BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      label=data.location.startTime,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onStartTime
   }
   btnStartTime.x, btnStartTime.y = minX + halfWidth * 0.5,yOffset
   sceneGroup:insert(btnStartTime)

   --addInput({id="startTime",title=SceneManager.getRosettaString("start_time"),value=data.location.startTime,width=halfWidth,x=minX + halfWidth * 0.5,y=yOffset})
   --addInput({id="stopTime",title=SceneManager.getRosettaString("stop_time"),value=data.location.stopTime,width=halfWidth,x=display.contentCenterX + PADDING * 0.5 + halfWidth * 0.5,y=yOffset})

   btnStopTime = widget.newButton {
      x = 0,y = 0,labelAlign="left",xOffset = 5,
      width = halfWidth,height = BUTTON_HEIGHT,
      overColor = GC.LIGHT_GRAY2,
      label=data.location.stopTime,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR }, fontSize = 14, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.MEDIUM_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onRelease = onStopTime
   }
   btnStopTime.x, btnStopTime.y = display.contentCenterX + PADDING * 0.5 + halfWidth * 0.5,yOffset
   sceneGroup:insert(btnStopTime)

   yOffset = btnStopTime.stageBounds.yMax + OPTION_HEIGHT * 0.5 + PADDING
   
   addOption({id="podRequired",label="pod_required",x=minX,y=yOffset,state = data.location.podRequired,callback=optionCallback})
   
   updateElementsBasedOnType()

   btnDone = widget.newButton {
      id = "done",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("done",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 140,
      height = 35,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onDone
   }
   btnDone.x, btnDone.y = display.contentCenterX, bg.stageBounds.yMax - btnDone.height * 0.5 - 10
   sceneGroup:insert(btnDone)
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      --datePicker:new({selectPast=false})
      _G.overlay = onDone
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneLocations")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   overlay:removeSelf()
   overlay = nil

   btnDone:removeSelf()
   btnDone = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   btnStartTime:removeSelf()
   btnStartTime = nil

   btnStopTime:removeSelf()
   btnStopTime = nil

   for i = 1, #elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil
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