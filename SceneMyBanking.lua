local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local utils = require("utils")
local alert = require("alertBox")

local MessageX = display.contentCenterX
local MessageY = 360

local INFO_BOX_WIDTH = display.contentWidth
local INFO_BOX_HEIGHT = 140
local SHADOW_SHIFT_AMOUNT = 2

local FIELD_NAMES = {"credit_cards","wired_funds","gbt_rewards"}
local FIELDS = {"creditAmount","wiredAmount","rewardAmount"}

local sceneGroup = nil
local bg = nil
local btnBack = nil
local title = nil
local titleBG = nil
local infoShadow, infoBox = nil, nil
local elements = nil
local btnAddFunds = nil
local btnTransfer = nil

local messageQ = nil

local isCarrier = nil

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then
      showStatus(messageQ)
      messageQ = nil
   end
end

local function addOnComplete( event )
   local i = event.target.id
   if 1 == i then
      -- wire transfer
   elseif 2 == i then
      -- credit card
   end
end

local function onBack()
   SceneManager.goToDashboard()
end

local function onEventCallback(event)
   if (event.target.id == "back") then
      onBack()
   elseif (event.target.id == "transfer") then
      composer.showOverlay("SceneTransfer")
   elseif (event.target.id == "add") then
      alert:show({title = SceneManager.getRosettaString("add_funds"),
         message = SceneManager.getRosettaString("add_funds_message"),
         buttons={SceneManager.getRosettaString("wire_transfer"),
         SceneManager.getRosettaString("credit_cards"),
         SceneManager.getRosettaString("cancel")},
         callback=addOnComplete
      })
   end
end

local function errorOncomplete()
   onBack()
end

local function getBankingDetailsCallback(response)
   if (response == nil or response.actualAmount == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      lblActualBalance = display.newText(sceneGroup,SceneManager.getRosettaString("actual_balance",1)..": "..utils.getCurrencySymbol()..utils.formatMoney(response.actualAmount),0,0,GC.APP_FONT,22)
      lblActualBalance:setFillColor(unpack(GC.DARK_GREEN))
      lblActualBalance.x, lblActualBalance.y = display.contentCenterX,infoBox.stageBounds.yMin + lblActualBalance.height * 0.5 + 10

      if (isCarrier) then
         lblPendingBalance = display.newText(sceneGroup,SceneManager.getRosettaString("pending_balance",1)..": "..utils.getCurrencySymbol()..utils.formatMoney(response.pendingAmount),0,0,GC.APP_FONT,22)
         lblPendingBalance:setFillColor(unpack(GC.DARK_GREEN))
         lblPendingBalance.x, lblPendingBalance.y = display.contentCenterX,lblActualBalance.stageBounds.yMax + lblPendingBalance.height * 0.5 + 10
      else
         elements = {}

         --elements[1] = display.newLine(sceneGroup,0, 0, INFO_BOX_WIDTH - 20, 0)
         --elements[1].strokeWidth = 1
         --elements[1]:setStrokeColor(unpack(GC.MEDIUM_GRAY))
         --elements[1].x, elements[1].y = display.contentCenterX, display.contentCenterY
         local PADDING = 7
         local width = (infoBox.width - PADDING * 4) / 3
         local height = 60

         local x,y = infoBox.stageBounds.xMin + width * 0.5 + PADDING,(infoBox.stageBounds.yMax - lblActualBalance.stageBounds.yMax - height) * 0.5 + lblActualBalance.stageBounds.yMax + height * 0.5
         local index = 1

         for i=1,3 do
            elements[index] = display.newRect( sceneGroup, 0, 0, width, height )
            elements[index].strokeWidth = 2
            elements[index]:setStrokeColor(unpack(GC.DARK_GRAY))
            elements[index].x, elements[index].y = x,y

            elements[index+1] = display.newText(sceneGroup, SceneManager.getRosettaString(FIELD_NAMES[i])..":", 0, 0, GC.APP_FONT, 14)
            elements[index+1]:setFillColor(unpack(GC.DARK_GRAY))
            elements[index+1].x, elements[index+1].y = x,elements[index].stageBounds.yMin + elements[index+1].height * 0.5 + 2

            elements[index+2] = display.newText(sceneGroup, utils.getCurrencySymbol()..utils.formatMoney(response[FIELDS[i]]), 0, 0, GC.APP_FONT, 15)
            elements[index+2]:setFillColor(unpack(GC.DARK_GREEN))
            elements[index+2].x, elements[index+2].y = x,elements[index+1].stageBounds.yMax + elements[index+2].height * 0.5

            x = x + elements[index].width + PADDING
            index = index + 3
         end
      end
   end

   if (messageQ) then
      alert:show({buttonAlign = "horizontal",
      message=SceneManager.getRosettaString(messageQ),
      buttons={SceneManager.getRosettaString("ok")},callback=errorOncomplete})
   end
end

local function getBankingDetails()
   api.getBankingDetails({sid=SceneManager.getUserSID(),callback=getBankingDetailsCallback})
end

function scene:create( event )
   sceneGroup = self.view

   isCarrier = SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("gbt_bank"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
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

   infoShadow = display.newRect( sceneGroup, 0,0, INFO_BOX_WIDTH + SHADOW_SHIFT_AMOUNT, INFO_BOX_HEIGHT + SHADOW_SHIFT_AMOUNT )
   infoShadow:setFillColor(unpack(GC.MEDIUM_GRAY))
   
   infoBox = display.newRect(sceneGroup,0,0,INFO_BOX_WIDTH,INFO_BOX_HEIGHT)
   infoBox:setFillColor(1,1,1)
   infoBox.x, infoBox.y = display.contentCenterX, titleBG.stageBounds.yMax + INFO_BOX_HEIGHT * 0.5 + 0
   infoShadow.x, infoShadow.y = infoBox.x, infoBox.y + SHADOW_SHIFT_AMOUNT

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER) then
      btnAddFunds = widget.newButton{
         id = "add",
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 18,
         label=SceneManager.getRosettaString("add_funds"),
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 120,
         height = 40,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onEventCallback
      }
      btnAddFunds.x, btnAddFunds.y = display.contentCenterX, display.contentHeight - btnAddFunds.height * 0.5 - 10
      btnAddFunds.isVisible = false
      sceneGroup:insert(btnAddFunds)
   end

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER) then
      btnTransfer = widget.newButton{
         id = "transfer",
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 18,
         label=SceneManager.getRosettaString("transfer_funds"),
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 140,
         height = 40,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onEventCallback
      }
      btnTransfer.x, btnTransfer.y = display.contentCenterX, display.contentHeight - btnTransfer.height * 0.5 - 10
      --btnAddFunds.isVisible = false
      sceneGroup:insert(btnTransfer)
   end

   getBankingDetails()
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
      composer.removeScene("SceneMyBanking")
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

   infoShadow:removeSelf()
   infoShadow = nil

   infoBox:removeSelf()
   infoBox = nil

   if (lblPendingBalance) then
      lblPendingBalance:removeSelf()
      lblPendingBalance = nil
   end

   if (elements) then
      for i=1,#elements do
         elements[1]:removeSelf()
         table.remove(elements,1)
      end
      elements = nil
   end

   if(lblActualBalance) then
      lblActualBalance:removeSelf()
      lblActualBalance = nil
   end
   
   if (btnTransfer) then
      btnTransfer:removeSelf()
      btnTransfer = nil
   end

   if (btnAddFunds) then
      btnAddFunds:removeSelf()
      btnAddFunds = nil
   end
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