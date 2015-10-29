local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local alert = require("alertBox")
local api = require("api")

local PADDING = 10
local FONT_SIZE = 16
local CORNER_RADIUS = 5

local sceneGroup = nil
local bg = nil
local btnCancel, btnSubmit = nil, nil
local scrollView = nil
local divider = nil

local title = nil
local titleBG = nil

local loadIdGuid
local data

local elements
local index

local function onCancel()
   composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,200)
end

local function getElementById(id)
   for i = 1, #elements do
      if (elements[i].id == id) then
         return elements[i]
      end
   end

   return nil
end

local function nextElement()
   index = #elements + 1
end

local function addAccessorial(id,accessorial,y)
   local elementWidth = scrollView.width - PADDING * 2
   local minX = PADDING * 2
   local newY
   local yOffset = y

   nextElement()
   elements[index] = display.newRoundedRect(0,0,elementWidth,20,CORNER_RADIUS)
   elements[index].id = id
   elements[index].strokeWidth = 1
   elements[index]:setStrokeColor(unpack(GC.MEDIUM_GRAY))
   elements[index].x, elements[index].y = scrollView.x, yOffset + elements[index].height * 0.5
   scrollView:insert(elements[index])

   yOffset = yOffset + PADDING * 0.5

   nextElement()
   elements[index] = display.newText(accessorial.request,0,0,GC.APP_FONT,12)
   elements[index]:setFillColor(unpack(GC.DARK_GRAY))
   elements[index].x, elements[index].y = minX + elements[index].width * 0.5, yOffset + elements[index].height * 0.5
   scrollView:insert(elements[index])

   yOffset = yOffset + elements[index].height * 0.5 + PADDING

   -- TODO: Add help use GC.ACCESSORIALS and request as id

   -- TODO: Add address

   -- TODO: Add desc if present

   -- TODO: Add amount, and button for changing

   -- TODO: Add accept/deny buttons and change color of input based on state

   -- TODO: Change rect height to encapsulate everything within it
   newY = getElementById(id).y + getElementById(id).height * 0.5
   print (yOffset,newY)
   
   if (yOffset > newY) then
      
   end

   newY = getElementById(id).y + getElementById(id).height * 0.5
   
   return newY + PADDING
end

local function onEventCallback(event)
   if (event.target.id == "blank") then
   end
end

function scene:create( event )
   sceneGroup = self.view

   if (event.params) then
      loadIdGuid = event.params.loadIdGuid
      accessorials = event.params.accessorials
   else
      loadIdGuid = 271
      data = {
         locations = {addressGuid=251,address="314 w Walnut, SPRINGFIELD, MO, 65807"},
         accessorials = {
            {requestId=46,request="Misrepresented Shipment",desc="cause",addressGuid=251,amount=10.00,status=4,approver="",approveDate=""}
         }
      }
   end

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("requested_accessorials_title")..loadIdGuid, 0, 0, GC.SCREEN_TITLE_FONT, FONT_SIZE)
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
      onRelease = onCancel
   }
   btnCancel.x, btnCancel.y = display.contentCenterX - btnCancel.width * 0.5 - PADDING, display.contentHeight - btnCancel.height * 0.5 - PADDING
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
      onRelease = onSubmit
   }
   btnSubmit.x, btnSubmit.y = display.contentCenterX + btnSubmit.width * 0.5 + PADDING, btnCancel.y
   sceneGroup:insert(btnSubmit)

   divider = display.newRect(0,0,display.contentWidth,1)
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnCancel.stageBounds.yMin - PADDING
   sceneGroup:insert(divider)

   scrollView = widgetNew.newScrollView
   {
      left     = 0,
      top      = 0,
      width    = display.contentWidth,
      height   = divider.stageBounds.yMin - titleBG.stageBounds.yMax,
      listener = scrollListener,
      hideBackground = true,
      bottomPadding  = 20,
      horizontalScrollDisabled   = true
   }
   scrollView.anchorY = 0
   scrollView.x, scrollView.y = display.contentCenterX, titleBG.stageBounds.yMax + 1
   sceneGroup:insert(scrollView)

   elements = {}

   local yOffset = PADDING

   for i = 1, #data.accessorials do
      yOffset = addAccessorial(i,data.accessorials[i],yOffset)
   end

   -- TODO: Add disclaimer (requested_accessorials_disclaimer)
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

   if ( phase == "will" ) then
      _G.overlay = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneRequestedAccessorials")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnCancel:removeSelf()
   btnCancel = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   divider:removeSelf()
   divider = nil

   for i = 1, #elements do
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