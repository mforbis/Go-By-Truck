local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local toggle = require("toggle")
local alert = require("alertBox")

local PADDING_OUTER = 10
local PADDING_KEY = 25
local LINE_PADDING = 5
local QUESTION_WIDTH = 180
local RADIO_BUTTON_SIZE = 20

local sceneGroup = nil
local overlay = nil
local bg = nil
local titleBG, title = nil, nil

local btnSubmit, btnClose = nil, nil

local elements = nil

local params = nil

local yOffset = nil

local updated = nil

local messageQ = nil

local MEDIUM_GRAY = {112/255,112/255,112/255}
local STATUS_VALUES = {10,48,20}

local status1, status2, status3 = nil, nil, nil

--[[
Leave Feedback Form:
Values are (S = 10, N = 48, U = 20)
Names are 'questionXStatus' (X = 1 - 3)

Questions for Carrier:
The shipper was professional and was able to meet the needs of the company/driver.
The shipment loading and unloading process was made quick simplistic.
Payment was released in a timely manner and Accessorials were fairly paid.

Note: Form uses loadIdGuid, has hidden value companyName ex: Boyo Shipping
]]--

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function onClose()
   composer.hideOverlay()
end

local function apiCallback(response)
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage
   elseif (response.status == "true") then
      _G.messageQ = "feedback_posted"
      updated = true
      onClose()
   else
      messageQ = "could_not_post"
   end

   showMessage()
end

local function postFeedback(loadId,status1,status2,status3)
   api.postFeedback({sid=SceneManager.getUserSID(),id=loadId,status1=status1,status2=status2,status3=status3,callback=apiCallback})
end

local function validate()
   return (status1 ~= nil and status2 ~= nil and status3 ~= nil)
end

-- NOTE: If elements change then the id values might need adjustment
local function onEventCallback(event)
   if (event.target) then
      if (event.target.id == "submit") then
         if (validate()) then
            postFeedback(params.shipment,status1,status2,status3)
         else
            alert:show({
               title = SceneManager.getRosettaString("error"),
               message = SceneManager.getRosettaString("form_missing_required"),
               buttons={SceneManager.getRosettaString("ok")}
            })
         end
      elseif (event.target.id == "close") then
         onClose()
      end
   elseif (event.id <=9) then
      elements[7].setState(event.id == 7)
      elements[8].setState(event.id == 8)
      elements[9].setState(event.id == 9)
      status1 = STATUS_VALUES[event.id - 6]
   elseif (event.id <=13) then
      elements[11].setState(event.id == 11)
      elements[12].setState(event.id == 12)
      elements[13].setState(event.id == 13)
      status2 = STATUS_VALUES[event.id - 10]
   else
      elements[15].setState(event.id == 15)
      elements[16].setState(event.id == 16)
      elements[17].setState(event.id == 17)
      status3 = STATUS_VALUES[event.id - 14]
   end
end

local function updateOffset(lastLine)
   yOffset = lastLine + LINE_PADDING
end

function scene:create( event )
   sceneGroup = self.view

   updated = false

   params = event.params
   
   --params = {}
   --params.company = "Boyo Shipping"
   --params.shipment = 362

   status1, status2, status3 = nil, nil, nil

   overlay = display.newRect(sceneGroup,0,0,display.contentWidth,display.contentHeight)
   overlay:setFillColor(0,0,0,0.5)
   overlay.x, overlay.y = display.contentCenterX,display.contentCenterY

   bg = display.newRect(sceneGroup,0,0,300,450)
   bg:setFillColor( unpack(GC.DEFAULT_BG_COLOR) )
   bg.strokeWidth = 1
   bg:setStrokeColor( unpack(GC.DARK_GRAY) )
   bg.x,bg.y = display.contentCenterX,display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, bg.width, 30 )
   titleBG:setFillColor(unpack(GC.DARK_GRAY))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5 + bg.stageBounds.yMin

   title = display.newText(sceneGroup, SceneManager.getRosettaString("leave_feedback"), 0, 0, GC.SCREEN_TITLE_FONT, 18)
   title.x, title.y = titleBG.x, titleBG.y

   elements = {}

   local minX = bg.stageBounds.xMin + PADDING_OUTER
   updateOffset(titleBG.stageBounds.yMax)

   elements[1] = display.newText( {text=SceneManager.getRosettaString("leave_feedback_for",1).." "..string.upper(params.company).." "..SceneManager.getRosettaString("for_shipment",1).." #"..params.shipment,width=bg.width - PADDING_OUTER * 2,font=GC.APP_FONT,fontSize=16} )
   elements[1]:setFillColor( unpack(MEDIUM_GRAY) )
   elements[1].anchorX, elements[1].anchorY = 0, 0
   elements[1].x, elements[1].y = minX, yOffset
   sceneGroup:insert(elements[1])

   updateOffset(elements[1].stageBounds.yMax)

   elements[2] = display.newText( {text=SceneManager.getRosettaString("feedback_legend"),width=bg.width - PADDING_OUTER * 2,font=GC.APP_FONT,fontSize=14} )
   elements[2]:setFillColor( unpack(MEDIUM_GRAY) )
   elements[2].anchorX, elements[2].anchorY = 0, 0
   elements[2].x, elements[2].y = minX, yOffset
   sceneGroup:insert(elements[2])

   local rolePrefix

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER) then
      rolePrefix = "carrier"
   else
      rolePrefix = "shipper"
   end

   updateOffset(elements[2].stageBounds.yMax + 20)

   elements[3] = display.newText( {text=SceneManager.getRosettaString(rolePrefix.."_feedback_question1"),width=QUESTION_WIDTH,font=GC.APP_FONT,fontSize=13} )
   elements[3]:setFillColor( unpack(MEDIUM_GRAY) )
   elements[3].anchorX, elements[3].anchorY = 0, 0
   elements[3].x, elements[3].y = minX, yOffset + 10
   sceneGroup:insert(elements[3])

   elements[4] = display.newText({text=SceneManager.getRosettaString("feedback_key1",1),font=GC.APP_FONT,fontSize=14})
   elements[4].x,elements[4].y = elements[3].stageBounds.xMax + PADDING_OUTER * 2 + elements[4].width * 0.5, yOffset
   elements[4]:setFillColor( unpack(MEDIUM_GRAY) )
   sceneGroup:insert(elements[4])

   elements[5] = display.newText({text=SceneManager.getRosettaString("feedback_key2",1),font=GC.APP_FONT,fontSize=14})
   elements[5].x,elements[5].y = elements[4].stageBounds.xMax + PADDING_KEY + elements[5].width * 0.5, yOffset
   elements[5]:setFillColor( unpack(MEDIUM_GRAY) )
   sceneGroup:insert(elements[5])

   elements[6] = display.newText({text=SceneManager.getRosettaString("feedback_key3",1),font=GC.APP_FONT,fontSize=14})
   elements[6].x,elements[6].y = elements[5].stageBounds.xMax + PADDING_KEY + elements[6].width * 0.5, yOffset
   elements[6]:setFillColor( unpack(MEDIUM_GRAY) )
   sceneGroup:insert(elements[6])
   
   elements[7] = toggle.new({id=7, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[7].x, elements[7].y = elements[4].x, elements[3].stageBounds.yMin + elements[7].height * 0.5 + 10
   sceneGroup:insert(elements[7])

   elements[8] = toggle.new({id=8, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[8].x, elements[8].y = elements[5].x, elements[7].y
   sceneGroup:insert(elements[8])

   elements[9] = toggle.new({id=9, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[9].x, elements[9].y = elements[6].x, elements[7].y
   sceneGroup:insert(elements[9])

   updateOffset(elements[3].stageBounds.yMax + 5)

   elements[10] = display.newText( {text=SceneManager.getRosettaString(rolePrefix.."_feedback_question2"),width=QUESTION_WIDTH,font=GC.APP_FONT,fontSize=13} )
   elements[10]:setFillColor( unpack(MEDIUM_GRAY) )
   elements[10].anchorX, elements[10].anchorY = 0, 0
   elements[10].x, elements[10].y = minX, yOffset
   sceneGroup:insert(elements[10])

   elements[11] = toggle.new({id=11, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[11].x, elements[11].y = elements[4].x, elements[10].stageBounds.yMin + elements[7].height * 0.5 + 10
   sceneGroup:insert(elements[11])

   elements[12] = toggle.new({id=12, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[12].x, elements[12].y = elements[5].x, elements[11].y
   sceneGroup:insert(elements[12])

   elements[13] = toggle.new({id=13, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[13].x, elements[13].y = elements[6].x, elements[11].y
   sceneGroup:insert(elements[13])

   updateOffset(elements[10].stageBounds.yMax + 5)

   elements[14] = display.newText( {text=SceneManager.getRosettaString(rolePrefix.."_feedback_question3"),width=QUESTION_WIDTH,font=GC.APP_FONT,fontSize=13} )
   elements[14]:setFillColor( unpack(MEDIUM_GRAY) )
   elements[14].anchorX, elements[14].anchorY = 0, 0
   elements[14].x, elements[14].y = minX, yOffset
   sceneGroup:insert(elements[14])

   elements[15] = toggle.new({id=15, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[15].x, elements[15].y = elements[4].x, elements[14].stageBounds.yMin + elements[7].height * 0.5 + 10
   sceneGroup:insert(elements[15])

   elements[16] = toggle.new({id=16, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[16].x, elements[16].y = elements[5].x, elements[15].y
   sceneGroup:insert(elements[16])

   elements[17] = toggle.new({id=17, x = 0, y = 0,on = "graphics/radio_on.png", onWidth = RADIO_BUTTON_SIZE, onHeight = RADIO_BUTTON_SIZE,
                  off = "graphics/radio_off.png", offWidth = RADIO_BUTTON_SIZE, offHeight = RADIO_BUTTON_SIZE,
                  state = params.state or false, callback = params.callback or onEventCallback})
   elements[17].x, elements[17].y = elements[6].x, elements[15].y
   sceneGroup:insert(elements[17])

   btnClose = widget.newButton{
      id = "close",
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
   btnClose.x, btnClose.y = bg.stageBounds.xMin + btnClose.width * 0.5 + 10, bg.stageBounds.yMax - btnClose.height * 0.5 - 10
   sceneGroup:insert(btnClose)

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
   btnSubmit.x, btnSubmit.y = bg.stageBounds.xMax - btnSubmit.width * 0.5 - 10, btnClose.y
   sceneGroup:insert(btnSubmit)
   --postFeedback(362,10,48,20)
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      -- Called when the scene is still off screen (but is about to come on screen).
   elseif ( phase == "did" ) then
      _G.overlay = onClose
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
      composer.removeScene("ScenePostFeedback")
      if (updated) then
         parent:update()
      end
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   overlay:removeSelf()
   overlay = nil

   bg:removeSelf()
   bg = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   btnSubmit:removeSelf()
   btnSubmit = nil

   btnClose:removeSelf()
   btnClose = nil

   for i=1,#elements do
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