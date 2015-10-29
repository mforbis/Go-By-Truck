local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local utils = require("utils")
local status = require("status")

-- NOTE: Left off needing to adjust the y values for certain fields if other is selected
-- Hide other length, and width

local MessageX = display.contentCenterX
local MessageY = 360

local PADDING = 10
local SPACE = 5
local BUTTON_XOFFSET = 10
local LINE_PADDING = 4
local LINE_HEIGHT = 5
local LINE_ADJUST = 5
local INFO_BOX_WIDTH = display.contentWidth - PADDING * 2
local INFO_BOX_HEIGHT = display.contentHeight - PADDING * 2
local SHADOW_SHIFT_AMOUNT = 2
local BUTTON_HEIGHT = GC.BUTTON_ACTION_HEIGHT

local FONT_SIZE = 14

local sceneGroup = nil

local overlay = nil
local btnCancel = nil
local btnSubmit = nil
local title = nil
local titleBG = nil
local scrollView = nil

local details = nil

local elements = nil
local currElement = nil

local yOffset = nil

local currTrailer = nil

local missingField = nil

local actionString

local updated

-- label is translation for user, but values are always the same
local TRAILERS = {
   {value="Van",label="van",lengths={28,45,48,53,"other"},widths={96,102,"other"}},
   {value="Reefer",label="reefer",lengths={28,45,48,53,"other"},widths={96,102,"other"}},
   {value="Flatbed",label="flatbed",lengths={45,48,50,53,"other"},widths={96,102,"other"}},
   {value="Step/Drop Deck",label="stepDropDeck",lengths={48,50,53,"other"},widths={96,102,"other"}},
   {value="Removable Gooseneck",label="gooseneck",lengths={48,50,53,"other"},widths={102,"other"}},
   {value="Double Drop Deck",label="doubleDropDeck",lengths={48,50,53,"other"},widths={102,"other"}},
}

local messageQ = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         api.sendAPIError({scene="AddEditTrailer",reason="Invalid JSON"})
      end

      showStatus(messageQ)
      messageQ = nil
   end
end

local function validate()
   if details.maxPayload == "" or tonumber(details.maxPayload) == nil then
      missingField = "max_payload_label"
      return false
   end

   if details.length == "other" and (details.lengthOther == "" or tonumber(details.lengthOther) == nil) then
      missingField = "other_trailer_length_label"
      return false
   end

   if details.width == "other" and (details.widthOther == "" or tonumber(details.widthOther) == nil) then
      missingField = "other_trailer_width_label"
      return false
   end

   return true
end

local function inTable(t,value)
   for i = 1, #t do
      if (tostring(t[i]) == tostring(value)) then
         return true
      end
   end

   return false
end


local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end
end

local function getElementIndexById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return i
      end
   end
end

local function nextLine(previous)
   if (not previous) then
      yOffset = yOffset + LINE_HEIGHT
   else
      yOffset = previous.y + previous.height * 0.5 + 0--LINE_HEIGHT
   end
end

local function nextElement()
   currElement = #elements + 1
end

local function getYPosition(element)
   return yOffset + element.height * 0.5
end

local function updateInputs()
   local lengthIdx = getElementIndexById("lengthOther")
   local widthIdx = getElementIndexById("widthOther")

   if details.length == "other" then
      elements[lengthIdx]:enable()
   else
      elements[lengthIdx]:disable()
      elements[lengthIdx]:setLabel("")
   end
   
   if details.width == "other" then
      elements[widthIdx]:enable()
   else
      elements[widthIdx]:disable()
      elements[widthIdx]:setLabel("")
   end

   --getElementById("maxPayload").isVisible = true
   --elements[lengthIdx].isVisible = details.length == "other"
   --elements[widthIdx].isVisible = details.width == "other"
end

local function findTrailerIndexByValue(value)
   local index = 1

   for i = 1, #TRAILERS do
      if (TRAILERS[i].value == value) then
         index = i
      end
   end
   return index
end

local function updateTrailerLength(which)
   details.length = TRAILERS[currTrailer].lengths[which]
   
   getElementById("length"):setLabel(details.length)
   updateInputs()
end

local function updateTrailerWidth(which)
   details.width = TRAILERS[currTrailer].widths[which]
   
   getElementById("width"):setLabel(details.width)
   updateInputs()
end

local function containsValue(table,value)
   for i = 1, #table do
      if (value == table[i]) then
         return true
      end
   end

   return false
end

local function updateTrailerType(which)
   currTrailer = which

   details.trailerType = TRAILERS[currTrailer].value
   getElementById("trailerType"):setLabel(SceneManager.getRosettaString(TRAILERS[currTrailer].label))

   if details.length ~= "other" and not containsValue(TRAILERS[currTrailer].lengths,details.length) then
      updateTrailerLength(1)
   end

   if details.width ~= "other" and not containsValue(TRAILERS[currTrailer].widths,details.width) then
      updateTrailerWidth(1)
   end
end

local function alertOnComplete( event,value )
   local i = event.target.id
   
   if (event.id == "trailer_type") then
      if i <= #TRAILERS then
         updateTrailerType(i)
      end
   elseif (event.id == "max_payload" and i == 2) then
      if (value and tonumber(value)) then
         details.maxPayload = value
         getElementById("maxPayload"):setLabel(value)
      end
   elseif (event.id == "trailer_length") then
      if i <= #TRAILERS[currTrailer].lengths then
         updateTrailerLength(i)
      end
   elseif (event.id == "length_other" and i == 2) then
      if (value and tonumber(value)) then
         details.lengthOther = value
         getElementById("lengthOther"):setLabel(value)
      end
   elseif (event.id == "trailer_width") then
      if i <= #TRAILERS[currTrailer].widths then
         updateTrailerWidth(i)
      end
   elseif (event.id == "width_other" and i == 2) then
      if (value and tonumber(value)) then
         details.widthOther = value
         getElementById("widthOther"):setLabel(value)
      end
   end

   updateInputs()

end

local function onCancel()
   composer.hideOverlay("zoomOutInFade",200)
end

local function addEditCallback(response)
   --print ("response: "..tostring(response.status))

   if (response == nil or response.error_msg == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      _G.messageQ = actionString.."_successful"
      updated = true
      composer.hideOverlay()
   else
      messageQ = "could_not_"..actionString
   end
   
   showMessage()
end

local function onSubmit()
   if (validate()) then
      api.addEditTrailer({sid=SceneManager.getUserSID(),trailer=details,callback=addEditCallback})
   else
      alert:show({title = SceneManager.getRosettaString("fields_not_set_title"),
         message = SceneManager.getRosettaString("fields_not_set_message")..":\n"..SceneManager.getRosettaString(missingField),
         buttons={SceneManager.getRosettaString("ok")},buttonHeight=30,
         callback=alertOnComplete
      })
   end
end

local function trailerCallback(event,value)
   updateTrailerType(value)
end

local function getTrailerLabels()
   local labels = {}

   for i = 1, #TRAILERS do
      table.insert(labels,SceneManager.getRosettaString(TRAILERS[i].label))
   end

   return labels
end

local function onTrailerType()
   --[[
   alert:show({title = SceneManager.getRosettaString("trailer_type"),id="trailer_type",width=
            buttons={SceneManager.getRosettaString(TRAILERS[1].label),SceneManager.getRosettaString(TRAILERS[2].label),
            SceneManager.getRosettaString(TRAILERS[3].label),SceneManager.getRosettaString(TRAILERS[4].label),
            SceneManager.getRosettaString(TRAILERS[5].label),SceneManager.getRosettaString(TRAILERS[6].label),
            SceneManager.getRosettaString("cancel")},buttonHeight=30,cancel=7,
            callback=alertOnComplete})
   ]]--
   alert:show({title=SceneManager.getRosettaString("trailer_type"),id="trailer_type",
               list = {options = getTrailerLabels(),selected = currTrailer,fontSize=16},
               buttons={SceneManager.getRosettaString("cancel")},cancel = 1,
               callback=trailerCallback})
end

local function onMaxPayload()
   alert:show({title = SceneManager.getRosettaString("max_payload_label"),id="max_payload",
      input = {text=details.maxPayload,type="number",maxlength=6},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onTrailerLength()
   local buttons = utils.shallowcopy(TRAILERS[currTrailer].lengths)
   table.insert( buttons, SceneManager.getRosettaString("cancel"))

   alert:show({title = SceneManager.getRosettaString("trailer_length_label"),id="trailer_length",
      buttons=buttons,buttonHeight=30,cancel=#buttons,
      callback=alertOnComplete})
end

local function onLengthOther()
   alert:show({title = SceneManager.getRosettaString("other_trailer_length_label"),id="length_other",
      input = {text=details.lengthOther,type="number"},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onTrailerWidth()
   local buttons = utils.shallowcopy(TRAILERS[currTrailer].widths)
   table.insert( buttons, SceneManager.getRosettaString("cancel"))

   alert:show({title = SceneManager.getRosettaString("trailer_width_label"),id="trailer_width",
      buttons=buttons,buttonHeight=30,cancel=#buttons,
      callback=alertOnComplete})
end

local function onWidthOther()
   alert:show({title = SceneManager.getRosettaString("other_trailer_width_label"),id="width_other",
      input = {text=details.widthOther,type="number"},buttonAlign="horizontal",
      buttons={SceneManager.getRosettaString("cancel"),SceneManager.getRosettaString("ok")},buttonHeight=30,
      callback=alertOnComplete})
end

local function onStickie(self,event)
      local result = true
      
      if (event.phase == "ended") then
         print ("touched")
      end
      return result
   end

local function onEventCallback(event)
   if (event.phase == "release") then
      if (event.target.id == "cancel") then
         onCancel()
      elseif (event.target.id == "submit") then
         onSubmit()
      elseif (event.target.id == "trailerType") then
         onTrailerType()
      elseif (event.target.id == "maxPayload") then
         onMaxPayload()
      elseif (event.target.id == "length") then
         onTrailerLength()
      elseif (event.target.id == "lengthOther") then
         onLengthOther()
      elseif (event.target.id == "width") then
         onTrailerWidth()
       elseif (event.target.id == "widthOther") then
         onWidthOther()
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

   updated = false

   if (event.params) then 
      details = event.params
   else
      details = {}
      details.trailerType = TRAILERS[1].value
      details.maxPayload = ""
      details.length = TRAILERS[1].lengths[1]
      details.lengthOther = ""
      details.width = TRAILERS[1].widths[1]
      details.widthOther = ""
   end

   currTrailer = findTrailerIndexByValue(details.trailerType)
   
   if (not inTable(TRAILERS[currTrailer].lengths,details.length)) then
      details.lengthOther = details.length
      details.length = "other"
   end

   if (not inTable(TRAILERS[currTrailer].widths,details.width)) then
      details.widthOther = details.width
      details.width = "other"
   end

   overlay = display.newRect(sceneGroup,0,0,display.contentWidth,display.contentHeight)
   overlay:setFillColor(0,0,0,0.5)
   overlay.x, overlay.y = display.contentCenterX,display.contentCenterY

   infoShadow = display.newRect( sceneGroup, 0,0, INFO_BOX_WIDTH + SHADOW_SHIFT_AMOUNT, INFO_BOX_HEIGHT + SHADOW_SHIFT_AMOUNT )
   infoShadow:setFillColor(unpack(GC.MEDIUM_GRAY))
   
   infoBox = display.newRect(sceneGroup,0,0,INFO_BOX_WIDTH,INFO_BOX_HEIGHT)
   infoBox:setFillColor(1,1,1)
   infoBox.x, infoBox.y = display.contentCenterX, display.contentCenterY
   infoShadow.x, infoShadow.y = infoBox.x + SHADOW_SHIFT_AMOUNT, infoBox.y + SHADOW_SHIFT_AMOUNT

   titleBG = display.newRect( sceneGroup, 0, 0, infoBox.width, 30 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5 + infoBox.stageBounds.yMin

   local titleTag = "add_trailer"
   actionString = "add"
   if (details.trailerId) then
      titleTag = "edit_trailer"
      actionString = "update"
   end

   title = display.newText(sceneGroup, SceneManager.getRosettaString(titleTag), 0, 0, GC.SCREEN_TITLE_FONT, 18)
   title.x, title.y = titleBG.x, titleBG.y
   
   btnCancel = widget.newButton{
      id = "cancel",
      defaultColor = defaultColor,
      overColor = overColor,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("cancel",1),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER },
      width = 130,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnCancel.x, btnCancel.y = btnCancel.width * 0.5 + 20, infoBox.stageBounds.yMax - btnCancel.height * 0.5 - PADDING
   sceneGroup:insert(btnCancel)

   btnSubmit = widget.newButton{
      id = "submit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("submit",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 130,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnSubmit.x, btnSubmit.y = display.contentWidth - btnSubmit.width * 0.5 - 20, btnCancel.y
   sceneGroup:insert(btnSubmit)

   elements = {}
   local elementWidth = infoBox.width - PADDING * 2
   yOffset = 0

   scrollView = widgetNew.newScrollView
   {
      left     = 0,
      top      = 0,
      width    = INFO_BOX_WIDTH,
      height   = INFO_BOX_HEIGHT - titleBG.height - BUTTON_HEIGHT - PADDING * 2,-- divider.stageBounds.yMin - titleBG.height,
      listener = scrollListener,
      --hideBackground = true,
      bottomPadding  = 20,
      horizontalScrollDisabled   = true
   }
   scrollView.anchorY = 0
   scrollView.x, scrollView.y = display.contentCenterX, titleBG.stageBounds.yMax
   sceneGroup:insert(scrollView)

   nextLine()
   nextElement()

   local minX = PADDING
   local maxX = scrollView.width - PADDING

   elements[currElement] = display.newText("  = "..SceneManager.getRosettaString("required"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 1
   elements[currElement].x, elements[currElement].y = maxX, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText("*",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = elements[currElement-1].stageBounds.xMin - elements[currElement].width * 0.5 - SPACE, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("trailer_type"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[currElement-1].x + elements[currElement-1].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "trailerType",x = 0,y = 0,labelAlign="left",xOffset = BUTTON_XOFFSET,
      width = elementWidth,height = BUTTON_HEIGHT,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = SceneManager.getRosettaString(TRAILERS[currTrailer].label),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback   
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("max_payload_label"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[4].x, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "maxPayload",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      label = details.maxPayload,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])
   
   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("trailer_length_label"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement].id = currElement
   elements[currElement].touch = onStickie
   elements[currElement]:addEventListener("touch")
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[4].x, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "length",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = details.length,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("other_trailer_length_label"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[4].x, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "lengthOther",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      label = details.lengthOther,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("trailer_width_label"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[4].x, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "width",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      icon = {default="graphics/selector.png",width=12,height=20,align="right",matchTextColor=true},
      label = details.width,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = display.newText("* ",0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.RED))
   elements[currElement].x, elements[currElement].y = minX + elements[currElement].width * 0.5, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextElement()

   elements[currElement] = display.newText(SceneManager.getRosettaString("other_trailer_width_label"),0,0,GC.APP_FONT,FONT_SIZE)
   elements[currElement]:setFillColor(unpack(GC.DARK_GRAY))
   elements[currElement].anchorX = 0
   elements[currElement].x, elements[currElement].y = elements[4].x, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])

   nextLine(elements[currElement])
   nextElement()

   elements[currElement] = widget.newButton{
      id = "widthOther",x = 0,y = 0,labelAlign="left",xOffset = 10,
      width = elementWidth,height = BUTTON_HEIGHT,
      label = details.widthOther,
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.DARK_GRAY }, fontSize = 18, font = GC.APP_FONT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE, strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH, onEvent = onEventCallback
   }
   elements[currElement].x, elements[currElement].y = display.contentCenterX - BUTTON_XOFFSET, getYPosition(elements[currElement])
   scrollView:insert(elements[currElement])
   
   updateInputs()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = onCancel
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase
   local parent = event.parent

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneAddEditTrailer")
      if (updated) then
         parent:update()
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   infoBox:removeSelf()
   infoBox = nil

   infoShadow:removeSelf()
   infoShadow = nil

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