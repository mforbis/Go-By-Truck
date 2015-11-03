local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local utils = require("utils")

local sceneGroup = nil
local bg = nil
local btnBack = nil
local btnHome = nil
local btnFake = nil
local title = nil
local titleBG = nil

local detailsBG, detailsTitle = nil, nil
local elements, detailsHeader = nil, nil

local PADDING_OUTER = 10
local PADDING_KEY = 25

local MessageX = display.contentCenterX
local MessageY = display.contentHeight - 40

local rolePrefix = nil

--[[
Titles for carrier:
1. Professionalism & Communication:
2. Timely Pick-Up & Drop-Off:
3. Safety & Security:

Titles for shipper:
1. Professional & Met Company/Driver Needs:
2. Loading & Unloading Simplicity:
3. Timely Payment Release:

Note: Each title has 3 scores (Satisfied,Neutral, and Unsatisfied)
Also, they are floats (ex: 0.00%)

Shipments Transacted: (Integer)
Member Since: (String) ex: 05-14-2014
Your Feedback Score: (Float) ex: 100.0%

My Feedback Details: (Not sure of specific values for all yet)
a. CARRIER #/SHIPPER # (Integer [SID/GUID])
b. SHIPMENT # (Integer)
c. PROFESSIONALISM
d. PUNCTUALITY
e. SAFETY

Leave Feedback:
ACTION (Leave Feedback)
SHIPMENT # (Integer ex: 362)
FROM (String ex: SCHENECTADY, NY)
TO (String ex: SPRINGFIELD, MO)
(If Carrier) RELEASE DATE (String ex: 04-25-2014)
(If Shipper) AMOUNT PAID (String ex: $750.00)
SHIPPER # or CARRIER # (Integer ex: ...8893)

]]--

local messageQ = nil

local API_FEEDBACK_DETAILS = "feedbackDetails"
local apiCommand

local function onBack()
   SceneManager.goToDashboard()
end

local function buildDateString(dateString)
    local pattern = "(%d+)%-(%d+)%-(%d+)"
    local year, month, day
    
    year, month, day = dateString:match(pattern)
   
    return month.."-"..day.."-"..year
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function showFeedbackDetails(data)
   --print ("date: "..buildDateString(response.member_since))
   -- USER_ROLE_feedback_areaX (1-3)
   local SCORE_OFFSETS = {display.contentCenterX - 90,display.contentCenterX, display.contentCenterX + 90}
   local SCORE_COLORS = {GC.DARK_GREEN,GC.ORANGE,GC.RED}
   local SCORE_LABELS = {"satisfied","neutral","unsatisfied"}

   local xOffset = detailsBG.stageBounds.xMin
   local yOffset = detailsTitle.stageBounds.yMax + PADDING_OUTER * 2

   local elementIndex = 1
   local fontSizeScore = 26
   local fontSizeText = 14
   local linePadding = PADDING_OUTER

   if (detailsBG.height <= 500) then
      fontSizeScore = 20
      linePadding = 8
   end

   for i = 1, 3 do
      elements[elementIndex] = display.newText( {text=i..". "..SceneManager.getRosettaString(rolePrefix.."_feedback_area"..i),font=GC.APP_FONT,fontSize=fontSizeText-1} )
      elements[elementIndex]:setFillColor(unpack(GC.DARK_GRAY))
      elements[elementIndex].x, elements[elementIndex].y = xOffset + elements[elementIndex].width * 0.5 + PADDING_OUTER, yOffset
      sceneGroup:insert(elements[elementIndex])
      yOffset = elements[elementIndex].stageBounds.yMax + linePadding * 2
      
      -- Add individual scores for each area
      -- Scores are in this order: (satisified * numCategories), (neutral * numCategories), (unsatisified * numCategories)
      -- Values should be 1,4,7 - 2,5,8 - 3,6,9
      for j = 1, 3 do
         elementIndex = elementIndex + 1
         
         --elements[elementIndex] = display.newText( {text=math.floor(data.scores[i + ((j - 1) * 3)]).."%",font="Oswald",fontSize=fontSizeScore} )
         elements[elementIndex] = display.newText( {text=math.floor(data.scores[j + ((i - 1) * 3)]).."%",font="Oswald",fontSize=fontSizeScore} )
         elements[elementIndex]:setFillColor(unpack(GC.ORANGE))
         elements[elementIndex].x, elements[elementIndex].y = SCORE_OFFSETS[j], yOffset
         sceneGroup:insert(elements[elementIndex])

         elementIndex = elementIndex + 1
         elements[elementIndex] = display.newText( {text=SceneManager.getRosettaString(SCORE_LABELS[j]),font=GC.APP_FONT,fontSize=fontSizeText} )
         elements[elementIndex]:setFillColor(unpack(GC.DARK_GRAY))
         elements[elementIndex].x, elements[elementIndex].y = SCORE_OFFSETS[j], elements[elementIndex-1].stageBounds.yMax + 5
         sceneGroup:insert(elements[elementIndex])
      end

      yOffset = elements[elementIndex].stageBounds.yMax + linePadding

      elementIndex = elementIndex + 1
      elements[elementIndex] = display.newRect(0,0,detailsBG.width - PADDING_OUTER * 2, 1)
      elements[elementIndex]:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
      elements[elementIndex].x, elements[elementIndex].y = display.contentCenterX, yOffset
      sceneGroup:insert(elements[elementIndex])
      
      yOffset = elements[elementIndex].stageBounds.yMax + linePadding * 2
   end

   yOffset = yOffset + linePadding * 0.5

   elementIndex = elementIndex + 1

   elements[elementIndex] = display.newText( {text=SceneManager.getRosettaString("your_feedback_score"),font=GC.APP_FONT,fontSize=20} )
   elements[elementIndex]:setFillColor(unpack(GC.DARK_GRAY))
   elements[elementIndex].x, elements[elementIndex].y = xOffset + elements[elementIndex].width * 0.5 + PADDING_OUTER, yOffset
   sceneGroup:insert(elements[elementIndex])
   
   elementIndex = elementIndex + 1
   elements[elementIndex] = display.newText( {text=math.floor(data.final).."%",font="Oswald",fontSize=fontSizeScore} )
   elements[elementIndex]:setFillColor(unpack(GC.ORANGE))
   elements[elementIndex].x, elements[elementIndex].y = detailsBG.stageBounds.xMax - elements[elementIndex].width * 0.5 - PADDING_OUTER, yOffset
   sceneGroup:insert(elements[elementIndex])

   elementIndex = elementIndex + 1

   elements[elementIndex] = display.newText( {text=SceneManager.getRosettaString("member_since")..": "..buildDateString(data.member_since),font=GC.APP_FONT,fontSize=fontSizeText} )
   elements[elementIndex]:setFillColor(unpack(GC.DARK_GRAY))
   elements[elementIndex].x, elements[elementIndex].y = detailsBG.stageBounds.xMin + elements[elementIndex].width * 0.5 + PADDING_OUTER, detailsBG.stageBounds.yMax - elements[elementIndex].height * 0.5 - linePadding
   sceneGroup:insert(elements[elementIndex])
   yOffset = elements[elementIndex].stageBounds.yMin - linePadding * 1.5

   elementIndex = elementIndex + 1

   elements[elementIndex] = display.newText( {text=SceneManager.getRosettaString("shipments_transacted")..": "..utils.addNumberSeparator(data.shipments),font=GC.APP_FONT,fontSize=fontSizeText} )
   elements[elementIndex]:setFillColor(unpack(GC.DARK_GRAY))
   elements[elementIndex].x, elements[elementIndex].y = xOffset + elements[elementIndex].width * 0.5 + PADDING_OUTER, yOffset
   sceneGroup:insert(elements[elementIndex])
end

local function apiCallback(response)
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.status == "true") then
      if (apiCommand == API_FEEDBACK_DETAILS) then
         showFeedbackDetails(response)
      end 
   else
      -- TODO: Handle different API request errors
      messageQ = "could_not_remove"
   end

   apiCommand = nil

   showMessage()
end

local function onPost(shipment,company)
   SceneManager.goToPostFeedback({shipment=shipment,company=company})
end

local function getFeedbackDetails()
   apiCommand = API_FEEDBACK_DETAILS
   api.getFeedbackDetails({sid=SceneManager.getUserSID(),callback=apiCallback})
end

local function onEventCallback(event)
   if (event.target.id == "back") then
      SceneManager.goToDashboard()
   elseif (event.target.id == "fake") then
      onPost(362,"Boyo Company")
   end
end

function scene:create( event )
   sceneGroup = self.view

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER) then
      rolePrefix = "carrier"
   else
      rolePrefix = "shipper"
   end

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("my_feedback"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnHome = widget.newButton{
      id = "back",
      default = "graphics/home.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnHome.x, btnHome.y = btnHome.width * 0.5 + 5, titleBG.y
   sceneGroup:insert(btnHome)

   btnBack = widget.newButton{
      id = "back",
      default = "graphics/back.png",
      width = GC.HEADER_BUTTON_SIZE, height = GC.HEADER_BUTTON_SIZE,
      overColor = {0.5,0.5,0.5,1},
      onRelease = onEventCallback
   }
   btnBack.x, btnBack.y = display.contentWidth - btnBack.width * 0.5 - 5, titleBG.y
   sceneGroup:insert(btnBack)

   btnFake = widget.newButton{
      id = "fake",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label="POST",
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 60,
      height = 40,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnFake.x, btnFake.y = display.contentWidth - btnFake.width * 0.5 - 5, titleBG.y
   -- NOTE: Hiding because this might not be needed for 1.0
   btnFake.isVisible = false
   sceneGroup:insert(btnFake)

   detailsBG = display.newRect(sceneGroup,0,0,display.contentWidth - PADDING_OUTER * 2,display.contentHeight - titleBG.height - PADDING_OUTER * 2)
   detailsBG:setFillColor(1,1,1)
   --detailsBG.strokeWidth = 1
   --detailsBG:setStrokeColor(unpack(GC.DARK_GRAY))
   detailsBG.anchorY = 0
   detailsBG.x, detailsBG.y = display.contentCenterX, titleBG.stageBounds.yMax + PADDING_OUTER
   
   detailsTitle = display.newText( {text=SceneManager.getRosettaString("feedback_received"),font=GC.APP_FONT,fontSize=28} )
   detailsTitle:setFillColor(unpack(GC.DARK_GRAY))
   detailsTitle.x, detailsTitle.y = detailsBG.stageBounds.xMin + detailsTitle.width * 0.5 + PADDING_OUTER, detailsBG.stageBounds.yMin + detailsTitle.height * 0.5 + 2
   sceneGroup:insert(detailsTitle)

   elements = {}
--[[
   elements[2] = display.newText({text=SceneManager.getRosettaString("feedback_key1",1),font=GC.APP_FONT,fontSize=14})
   elements[2].x,elements[2].y = elements[3].stageBounds.xMax + PADDING_OUTER * 2 + elements[4].width * 0.5, yOffset
   elements[2]:setFillColor( unpack(MEDIUM_GRAY) )
   
   elements[3] = display.newText({text=SceneManager.getRosettaString("feedback_key2",1),font=GC.APP_FONT,fontSize=14})
   elements[3].x,elements[3].y = elements[4].stageBounds.xMax + PADDING_KEY + elements[5].width * 0.5, yOffset
   elements[3]:setFillColor( unpack(MEDIUM_GRAY) )

   elements[4] = display.newText({text=SceneManager.getRosettaString("feedback_key3",1),font=GC.APP_FONT,fontSize=14})
   elements[4].x,elements[4].y = elements[5].stageBounds.xMax + PADDING_KEY + elements[6].width * 0.5, yOffset
   elements[4]:setFillColor( unpack(MEDIUM_GRAY) )

   elements[5] = display.newRect( 0, 0, detailsBG.width - 10, 1 )
   elements[5]:setFillColor(unpack(GC.DARK_GRAY))
   elements[5].x, elements[5].y = display.contentCenterX, elements[4].stageBounds.yMax + 2
   sceneGroup:insert(elements[5])
   ]]--
   getFeedbackDetails()
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
      _G.sceneExit = nil
   elseif ( phase == "did" ) then
      composer.removeScene("SceneMyFeedback")
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnBack:removeSelf()
   btnBack = nil

   btnHome:removeSelf()
   btnHome = nil
   
   btnFake:removeSelf()
   btnFake = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   detailsBG:removeSelf()
   detailsBG = nil

   detailsTitle:removeSelf()
   detailsTitle = nil

   for i=1, #elements do
      elements[1]:removeSelf()
      table.remove(elements,1)
   end
   elements = nil
end

function scene:update()
   if (_G.messageQ) then
      messageQ = _G.messageQ
      _G.messageQ = nil
      showMessage()
   end
   -- TODO: Need to update current list based on type (my feedback, pending)
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