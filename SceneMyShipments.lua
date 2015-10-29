local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local newWidget = require("widget")
local GC = require("AppConstants")
local API = require("api")
local status = require("status")
local alert = require("alertBox")
local utils = require("utils")

-- TODO: Handle successful uploads (pod). Message sent back via _G.messageQ)
-- NOTE: claim photos will allow multiples, so we don't just close like the pod above

local MessageX = display.contentCenterX
local MessageY = 360

local BUTTON_OFFSET = 10

local sceneGroup = nil

local bg = nil
local btnBack = nil
local btnHome = nil
local title = nil
local titleBG = nil
local lblNoShipments = nil
local btnEdit = nil
local btnRefresh = nil
local btnFilter = nil
local divider = nil
local count = nil

local lvListBGColor = {1,1,1}
local lvListHighlightBGColor = GC.MEDIUM_GRAY
local lvListRowHeight = 80

local PADDING_LEFT = 10
local PADDING_RIGHT = 10
local PADDING_TOP = 5
local PADDING_BOTTOM = 5

local list = nil
local listTop = nil

local currShipmentIndex = nil
local currListRow = nil

local shipments = nil

local isEditing = nil

local showingOverlay = nil
local showingToast = nil
local shipmentType = nil

local API_TIMEOUT_MS = 10000
local apiTimer = nil
local messageQ = nil

local isDriver = nil

local SHIPMENT_TYPES = nil
local shipmentOptions = nil

local dropOffIndex = nil

local detailsCommand = nil

local onComplete = nil

local function setCount(value)
   if (count) then
      if (tonumber(value)) then
         count.text = " ("..value..")"
      else
         count.text = value
      end

      title.x = display.contentCenterX - count.width * 0.5
      count.x = title.stageBounds.xMax + count.width * 0.5
   end
end

local function getLocationsByType(type,lTable)
   local locations = {}
   for i = 1, #lTable do
      if (tostring(lTable[i].type) == tostring(type)) then
         table.insert(locations,i)
      end
   end

   return locations
end

local function showStatus(text_id)
   status.showStatusMessage(SceneManager.getRosettaString(text_id),MessageX,MessageY,2000)
end

local function showMessage()
   if (messageQ) then

      if (messageQ == "invalid_server_response") then
         local scene = "MyShipments"
         if (isDriver) then
            scene = "MyLoads"
         end

         api.sendAPIError({scene=scene,reason="Invalid JSON"})
      end

      alert:show({
         title = SceneManager.getRosettaString("error"),
         message = SceneManager.getRosettaString(messageQ),
         buttons={SceneManager.getRosettaString("ok")}
      })
      messageQ = nil
   end
end

local function showToast(text)
   --showingToast = true
   --composer.removeScene("toast")
   --local options = {isModal = true, params = {message = text}}
   --composer.showOverlay("toast", options)
end

local function hideToast()
   if (showingToast) then
      composer.hideOverlay("toast")
      showingToast = false
   end
end

local function updateCountLabel()
   if (#shipments > 0) then
      setCount(#shipments)
   else
      setCount("")
   end
end

local function stopTimeout()
   if (apiTimer) then
      timer.cancel(apiTimer)
      apiTimer = nil
   end
end

local function handleTimeout()
   stopTimeout()
   hideToast()
   showStatus("server_timeout")
end

local function startTimeout()
   stopTimeout()
   apiTimer = timer.performWithDelay(API_TIMEOUT_MS, handleTimeout)
end

local function getRowOffset(index)
   local row = list._view._rows[index]._view
   local offset = PADDING_LEFT
   if isEditing then
      offset = offset + row.delete.stageBounds.xMax
   end
   return offset
end

local function reloadData()
   for i = 1, #list._view._rows do
      if (list._view._rows[i]) then
         local row = list._view._rows[i]._view
         row.delete.isVisible = isEditing
         row.number.x = getRowOffset(i)
         row.locations.x = row.number.x
      end
   end
end

local function toggleEdit()
   isEditing = not isEditing

   if (isEditing) then
      btnEdit:setLabel(SceneManager.getRosettaString("done",1))
   else
      btnEdit:setLabel(SceneManager.getRosettaString("edit",1))
   end
   
   if (list:getNumRows() > 0) then
      reloadData()
   end
end

local function removeShipmentCallback(response)
   hideToast()
   stopTimeout()
   
   if (response == nil or response.status == nil) then
      messageQ = "invalid_server_response"
   elseif (response.status == "true") then
      -- NOTE: Can't remove from table, since Corona doesn't update the row index after removing
      --table.remove(shipments,currShipmentIndex)
      list:deleteRow(currListRow)
      if (list:getNumRows() == 0) then
         setCount("")
         list.isVisible = false
         lblNoShipments.isVisible = true
         --toggleEdit()
         btnEdit.isVisible = false
      else
         setCount(list:getNumRows())
      end
   else
      messageQ = "could_not_remove"
   end

   showMessage()
end

local function removeShipment()
   showToast()
   startTimeout()
   api.removeShipment({sid=SceneManager.getUserSID(),id=shipments[currShipmentIndex].loadIdGuid,showPD=false,callback=removeShipmentCallback})
   GC.GOT_LIST = false
   GC.LISTWIDGET_HOLDER = nil
end

local function removeOnComplete( event )
   --if "clicked" == event.action then
      local i = event.target.id --event.index
      if 1 == i then
         removeShipment()
      end
   --end
end

local function showRemovePrompt()
	GC.GOT_LIST = true
    alert:show({title = SceneManager.getRosettaString("remove"), buttonAlign = "horizontal",
      message = SceneManager.getRosettaString("remove_shipment_question"),
            buttons={SceneManager.getRosettaString("yes"),
            SceneManager.getRosettaString("no")},
            callback=removeOnComplete})
   --local alert = native.showAlert( SceneManager.getRosettaString("remove"), SceneManager.getRosettaString("remove_shipment_question"), 
   --   { SceneManager.getRosettaString("yes"), SceneManager.getRosettaString("no") }, removeOnComplete )
end

local function findShipmentIndexById(id)
   local index = nil

   for i=1,#shipments do
      if shipments[i].loadIdGuid == id then
         index = i
      end
   end

   return index
end

local function showPODForm()
   SceneManager.goTo("sign_pod",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid,aid=shipments[currShipmentIndex].locations[dropOffIndex].addressGuid,sid=SceneManager.getUserSID()},true,nil)
end

local function detailsCallback(event)
   --showingOverlay = false
      
   local id = event.target.id
   if (id == "edit") then
      -- TODO: go to post shipment
      --SceneManager.goToPostShipment({id=shipments[currShipmentIndex].loadIdGuid})
      SceneManager.goTo("post_shipment",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},false,onComplete)
   elseif (id == "map") then
      -- Old Way of using built-in browser
      system.openURL("http://maps.google.com/maps?saddr="..utils.fixSpaces(shipments[currShipmentIndex].fromCityState).."&daddr="..utils.fixSpaces(shipments[currShipmentIndex].toCityState).."")
   end
end

local function getDetailsCallback(response)
   hideToast()
   stopTimeout()

   if (response == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      --showingOverlay = true
      canEdit =   (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER and
                  SHIPMENT_TYPES[shipmentType] == "incomplete")
      response.loadIdGuid = response.loadIdGuid or response.options.loadIdGuid
      
      if (response.forkLift == nil and response.forklift) then
         response.forkLift = response.forklift
         response.liftgate = nil
      end

      if (detailsCommand == "show") then
         SceneManager.showShipmentDetails({shipment = response,role=SceneManager.getUserRoleType(),canEdit=canEdit,callback=detailsCallback})
      else
         SceneManager.goToPostShipment(response)
      end
      detailsCommand = nil
   end

   if (messageQ) then
      alert:show({buttonAlign = "horizontal",
      message=SceneManager.getRosettaString(messageQ),
      buttons={SceneManager.getRosettaString("ok")},callback=errorOncomplete})
   end
end

local function getDetails()
   showToast()
   startTimeout()
   api.getShipmentDetails({sid=SceneManager.getUserSID(),id=shipments[currShipmentIndex].loadIdGuid,showPD=false,callback=getDetailsCallback})
end

local function getLocationOptions(t)
   local aliases = {}

   for i = 1, #t do
      table.insert(aliases,shipments[currShipmentIndex].locations[t[i]].name.." - "..shipments[currShipmentIndex].locations[t[i]].address)
   end

   return aliases
end

local function locationComplete(event,value)
   dropOffIndex = value
   showPODForm()
end

local function shipmentComplete(event,value)
   local id = value
   --print ("value: "..tostring(event.id))
   if (id == "details") then
      --detailsCommand = "show"
      --getDetails()
       SceneManager.goTo("shipment_details",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},true,nil)
   elseif (id == "delete") then
      showRemovePrompt()
   elseif (id == "edit") then
      --detailsCommand = "addEdit"
      --getDetails()
      --SceneManager.goToPostShipment({id=shipments[currShipmentIndex].loadIdGuid})
      SceneManager.goTo("post_shipment",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},true,onComplete)
   elseif (id == "view_accessorials") then
      SceneManager.goTo("view_accessorials",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},true,onComplete)
   elseif (id == "carrier_requested") then
      SceneManager.goTo("carrier_requested",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},true,onComplete)
   elseif (id == "request_accessorials") then
      -- TODO: Get details first, and then show. Reason: We need addresses
       --SceneManager.showRequestAccessorials({loadIdGuid=shipments[currShipmentIndex].loadIdGuid})
       SceneManager.goTo("request_accessorials",{loadIdGuid=shipments[currShipmentIndex].loadIdGuid},true,onComplete)
   elseif (id == "release_amount") then
      -- TODO: Check out site to get a clue as to how this is supposed to work
      SceneManager.goTo("release_amount",{releaseCode=shipments[currShipmentIndex].releaseCode},true,onComplete)
   elseif (id == "view_map") then
      -- View Map
      -- NOTE: Temporary
      -- NOTE: This has been temporarily moved here, since we can't call an overlay
      -- while displaying another.
      -- TODO: Once the getMyShipments API call matches getDriverLoads this
      -- will be deprecated.
      SceneManager.showMap({type=GC.SHOW_DIRECTIONS,data={sAddr=shipments[currShipmentIndex].fromCityState or shipments[currShipmentIndex].pickup.cityState,dAddr=shipments[currShipmentIndex].toCityState or shipments[currShipmentIndex].delivery.cityState}})
   elseif (id == "view_ref_numbers") then
      -- TODO: It seems there can be multiple numbers for some
      -- Not 100% sure if this is for both the to and from locations.
      alert:show({title = SceneManager.getRosettaString("view_ref_title"),
         subTitle = SceneManager.getRosettaString("shipment",1).." #"..shipments[currShipmentIndex].loadIdGuid,
         message = "PO Number(s)\n"..tostring(shipments[currShipmentIndex].po).."\nPU Number(s)\n"..tostring(shipments[currShipmentIndex].pu).."\nBOL Number\n"..tostring(shipments[currShipmentIndex].bol),messageAlign = "left",
         buttons={SceneManager.getRosettaString("ok")}})
   elseif (id == "sign_pod") then
      -- TODO: Finish
      local dropoffs = getLocationsByType(GC.LOCATION_TYPE_DROPOFF,shipments[currShipmentIndex].locations)
      if (#dropoffs == 0) then
         alert:show({title = SceneManager.getRosettaString("error"),
            message = "Couldn't find any dropoff locations for this shipment.",
            buttons={SceneManager.getRosettaString("ok")}})
      elseif (#dropoffs > 1) then
         -- show alert
         local options = getLocationOptions(dropoffs)

         alert:show({title = SceneManager.getRosettaString("select_location"),
            list = {options = options,radio = false},ids = dropoffs,
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=locationComplete})
      else
         dropOffIndex = dropoffs[1]
         showPODForm()
      end
   elseif (id == "claim_photos") then
      -- NOTE: Probably need a way to know if we have already uploaded photos
      -- for the currently selected load
      SceneManager.showClaimPhoto({shipment=shipments[currShipmentIndex]})
   end

end

-- handles individual row rendering
local function onRowRender( event )
   local row = event.row
   
   -- in graphics 2.0, the group contentWidth / contentHeight are initially 0, and expand once elements are inserted into the group.
   -- in order to use contentHeight properly, we cache the variable before inserting objects into the group

   local groupContentHeight = row.contentHeight
   local groupContentWidth = row.contentWidth

   local rowHeight = (lvListRowHeight - PADDING_TOP * 4) / 3
   local yOffset = rowHeight * 0.5 + PADDING_TOP

   -- LOOK:
   -- Shipment #
   -- Date/Time Posted, Auto Accept Amount:
   -- Centered to the right a view ref # button
   
   row.delete = display.newImageRect(row, "graphics/delete.png", 24, 24)
   row.delete.x, row.delete.y = PADDING_LEFT + row.delete.width * 0.5, groupContentHeight * 0.5
   row.delete.isVisible = isEditing
   
   local hasRequestedAccessorials = shipments[row.index].accessorialStatus == GC.STATUS_REQUESTED or shipments[row.index].hasRequestedAccessorials == true
   
   row.id = shipments[row.index].loadIdGuid
   
   local offset = getRowOffset(row.index)

   row.number = display.newText(row,SceneManager.getRosettaString("shipment").." #: "..shipments[row.index].loadIdGuid,0,0,GC.APP_FONT, 16)
   row.number:setFillColor(unpack(GC.DARK_GRAY))
   row.number.anchorX = 0
   row.number.x, row.number.y = offset, yOffset

   -- Show status
   local statusText = nil

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER and SHIPMENT_TYPES[shipmentType] == "actionItems") then
 print(shipments[row.index].status)
     if (tostring(shipments[row.index].status) == tostring(GC.SHIPMENT_STATUS_MATCHED)) then
         statusText = "matched"
      elseif (tostring(shipments[row.index].status) == tostring(GC.SHIPMENT_STATUS_RELEASED)) then
         statusText = "closed"
      end
   end

   if (statusText) then
      row.status = display.newText(row,SceneManager.getRosettaString(statusText),0,0,GC.APP_FONT, 12)
      row.status:setFillColor(unpack(GC.DARK_GRAY))

      row.status.x, row.status.y = groupContentWidth - row.status.width * 0.5 - PADDING_RIGHT, yOffset
   end

   yOffset = yOffset + rowHeight + PADDING_TOP

   -- TODO: Once the getMyShipments API call matches getDriverLoads this
   -- will be deprecated.
   -- NOTE: Might have to format separate elements later (ie. add zip)
   local fromCityState = shipments[row.index].fromCityState
   local toCityState = shipments[row.index].toCityState
   --[[
	print(shipments[row.index].postedDate)
	print("**********************")
    for j, vaj in pairs(shipments[row.index]) do
        print(j, shipments[row.index][j])
    end
	]]
	if (fromCityState == nil) then
      fromCityState = shipments[row.index].pickup.cityState
      toCityState = shipments[row.index].delivery.cityState
   end

   row.locations = display.newText(row,fromCityState.." ----> "..toCityState,0,0,GC.APP_FONT, 12)
   row.locations:setFillColor(unpack(GC.DARK_GRAY))
   row.locations.anchorX = 0
   row.locations.x, row.locations.y = offset, yOffset
   
   yOffset = yOffset + rowHeight + PADDING_TOP

   local strDateTitle = "posted"
   if (isDriver) then
      strDateTitle = "pick_up"
   end

   if (isDriver) then
	row.date = display.newText(row,SceneManager.getRosettaString(strDateTitle)..": "..(shipments[row.index].pickupDate or shipments[row.index].pickUpDate),0,0,GC.APP_FONT, 11)
   else
	row.date = display.newText(row,SceneManager.getRosettaString(strDateTitle)..": "..(shipments[row.index].postedDate or shipments[row.index].pickUpDate),0,0,GC.APP_FONT, 11)
   end
   row.date:setFillColor(unpack(GC.DARK_GRAY))
   row.date.anchorX = 0
   row.date.x, row.date.y = offset, yOffset

   local infoText = nil

   if (hasRequestedAccessorials) then
      infoText = "carrier_requested_accessorials"
   end

   if (infoText) then
      row.info = display.newText(row,SceneManager.getRosettaString(infoText),0,0,GC.APP_FONT, 11)
      row.info:setFillColor(unpack(GC.DARK_GRAY))

      row.info.x, row.info.y = groupContentWidth - row.info.width * 0.5 - PADDING_RIGHT, yOffset
   end
end

local function getShipmentOptions()
   shipmentOptions = {}
   shipmentIds = {}

   local status = shipments[currListRow].status

   table.insert(shipmentOptions,SceneManager.getRosettaString("shipment_details"))
   table.insert(shipmentIds, "details")

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER and
      SHIPMENT_TYPES[shipmentType] == "incomplete") then
      table.insert(shipmentOptions,SceneManager.getRosettaString("edit"))
      table.insert(shipmentIds, "edit")
   end

   if (SceneManager.getUserRoleType() ~= GC.USER_ROLE_TYPE_DRIVER and SHIPMENT_TYPES[shipmentType] == "incomplete") then
      table.insert(shipmentOptions,SceneManager.getRosettaString("delete"))
      table.insert(shipmentIds, "delete")
   end

   if (status ~= GC.SHIPMENT_STATUS_CREATED and status ~= GC.SHIPMENT_STATUS_POSTED) then
      if (shipments[currListRow].hasRequestedAccessorials == true) then
         table.insert(shipmentOptions,SceneManager.getRosettaString("view_requested_accessorials"))
         table.insert(shipmentIds, "carrier_requested")
      else
         table.insert(shipmentOptions,SceneManager.getRosettaString("view_accessorials"))
         table.insert(shipmentIds, "view_accessorials")
      end
   end

   if (tostring(shipments[currListRow].status) == tostring(GC.SHIPMENT_STATUS_MATCHED)) then
      if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_CARRIER or
         (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_DRIVER and 
         SceneManager.getRequestAccessorial() == true)) then
         table.insert(shipmentOptions,SceneManager.getRosettaString("request_accessorials"))
         table.insert(shipmentIds, "request_accessorials")
      end
      
      if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER and  utils.isValidParameter(shipments[currShipmentIndex].releaseCode)) then
         table.insert(shipmentOptions,SceneManager.getRosettaString("release_amount"))
         table.insert(shipmentIds, "release_amount")
      end
   end

   -- TODO: Find out if shipment state changes when POD signing shows up
   -- TODO: Only show for certain loads (status, and podRequired)
   if (isDriver) then
      table.insert(shipmentOptions,SceneManager.getRosettaString("sign_pod"))
      table.insert(shipmentIds, "sign_pod")
      -- NOTE: This is remarked out for now. There is a known issue in regards to Lua
      -- messing up Base64 with images once uploaded. 05/26/2015 MLH
      --table.insert(shipmentOptions,SceneManager.getRosettaString("claim_photos"))
      --table.insert(shipmentIds, "claim_photos")
   end

   table.insert(shipmentOptions,SceneManager.getRosettaString("view_map"))
   table.insert(shipmentIds, "view_map")
   --table.insert(shipmentOptions,SceneManager.getRosettaString("view_ref_numbers"))
   --table.insert(shipmentIds, "view_ref_numbers")
   
   return shipmentOptions, shipmentIds
end

-- handles row presses/swipes
local function onRowTouch( event )
   local row = event.target
   local rowSelected = false
   local textColor = nil

   if event.phase == "press" then
      rowSelected = true
      textColor = GC.WHITE
   elseif event.phase == "release" then
      textColor = GC.DARK_GRAY
      currListRow = row.index
      currShipmentIndex = findShipmentIndexById(row.id)
      if (isEditing) then
         showRemovePrompt()
      elseif (not showingOverlay) then
         local options, ids = getShipmentOptions()
         alert:show({title = SceneManager.getRosettaString("please_select"),
            list = {options = options,radio = false},ids = ids,
            buttons={SceneManager.getRosettaString("cancel")}, cancel = 1,
            callback=shipmentComplete})
      end
   elseif event.phase == "swipeLeft" then
   elseif event.phase == "swipeRight" then
   else
      -- Cancelled
      textColor = GC.DARK_GRAY
   end

   if (textColor) then
      row.locations:setFillColor(unpack(textColor))
      row.date:setFillColor(unpack(textColor))
      row.number:setFillColor(unpack(textColor))
      
      if (row.info) then
         row.info:setFillColor(unpack(textColor))
      end

      if (row.status) then
         row.status:setFillColor(unpack(textColor))
      end
   end
end

local function populateList()
   if (#shipments > 0) then
      local top = btnRefresh.stageBounds.yMax + 10
      lblNoShipments.isVisible = false
      if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER) then
         --btnEdit.isVisible = SHIPMENT_TYPES[shipmentType] == "incomplete"
      end
      list = newWidget.newTableView {
         top = listTop,
         height = display.contentHeight - listTop,
         width = display.contentWidth,
         hideBackground = true,
         onRowRender = onRowRender,
         onRowTouch = onRowTouch,
         noLines = true
         --maskFile = "graphics/"..lvListMaskFileName
      }
      sceneGroup:insert(list)
		GC.LISTWIDGET_HOLDER = list

      -- insert rows into list (tableView widget)
      local colors = {GC.LIGHT_GRAY2,GC.WHITE}

      for i=1,#shipments do
         list:insertRow{
            rowHeight = lvListRowHeight,
            rowColor = {default=colors[(i%2)+1],over=GC.ORANGE}
         }
      end
   else
      lblNoShipments.isVisible = true
      btnEdit.isVisible = false
   end
   updateCountLabel()
end

local function getShipmentsCallback(response)
   hideToast()
   stopTimeout()
   
   if (response == nil or response.shipments == nil) then
      messageQ = "invalid_server_response"
   elseif (response.error_msg.errorMessage ~= "") then
      messageQ = response.error_msg.errorMessage or "server_error"
   else
      -- Should have data now
      -- TODO: Somebody thought it was a good idea to not follow the service
      -- request for the API, so the format of getMyShipments doesn't match getDriverLoads
      -- We now need to format the shipments, so they match from here on out
      if (isDriver) then
         shipments = {}
         for key, value in pairs(response.shipments) do
            -- turn address1..address2..addressn into locations table
            value.locations = {}
            local i = 1
            while (value["address"..i]) do
               table.insert(value.locations,value["address"..i])
               i = i + 1
            end
            table.insert( shipments, value )
         end
      else
         shipments = response.shipments
      end

      populateList()
   end

   showMessage()
end

local function getShipments()
   if (isEditing) then
      toggleEdit()
   end
   if (list) then
      list:removeSelf()
      list = nil
   end

   --showToast()
   --startTimeout()

   if (isDriver) then
      api.getDriverLoads({sid=SceneManager.getUserSID(),showPD=false,callback=getShipmentsCallback})
   else
      api.getMyShipments({sid=SceneManager.getUserSID(),type=SHIPMENT_TYPES[shipmentType],showPD=false,callback=getShipmentsCallback})
   end
end

onComplete = getShipments

local function onBack()
   SceneManager.goToDashboard()
end

-- NOTE: Alex
local function filterOnComplete1(event,value)
	print("PRESS CANCEL START")
	if GC.GOT_LIST == true and GC.BACKPRESS == true then
		return true
	elseif GC.GOT_LIST == true and GC.BACKPRESS == false then
		if (not event.target and value ~= shipmentType) then
			print("PRESS CANCEL COMPLETE")
			shipmentType = value
			_G.shipmentTypeState = shipmentType
			
			btnFilter:setLabel(SceneManager.getRosettaString(SHIPMENT_TYPES[shipmentType]))
			getShipments()
		end
	end
end

local function filterOnComplete(event,value)
   if (event and not event.target and value ~= shipmentType) then
      shipmentType = value
      _G.shipmentTypeState = shipmentType
      
      btnFilter:setLabel(SceneManager.getRosettaString(SHIPMENT_TYPES[shipmentType]))
      getShipments()
   end
end

local function getFilterButtons()
   local buttons = {}
   for i=1, #SHIPMENT_TYPES do
      table.insert(buttons,SceneManager.getRosettaString(SHIPMENT_TYPES[i]))
   end
   return buttons
end

-- TODO: These can change based on userRoleType
local function showFilterOptions()
   alert:show({title = SceneManager.getRosettaString("choose_shipment_type"),
      list = {options = getFilterButtons(),selected = shipmentType,listRows=6},
      buttons={SceneManager.getRosettaString("cancel")}, callback=filterOnComplete})
end

local function onEventCallback(event)
   if (event.target.id == "back")then
      onBack()
   elseif (event.target.id == "edit") then
      toggleEdit()
   elseif (event.target.id == "filter") then
      showFilterOptions()
   elseif (event.target.id == "refresh") then
      getShipments()
	end
end

function scene:create( event )
	sceneGroup = self.view

   shipmentType = _G.shipmentTypeState or 1
  

   if (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_DRIVER) then
      -- No types just loads assigned
   elseif (SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_SHIPPER) then
      SHIPMENT_TYPES = GC.SHIPPER_SHIPMENT_TYPES
   else
      SHIPMENT_TYPES = GC.CARRIER_SHIPMENT_TYPES
   end

   isEditing = false
   showingOverlay = false

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   listTop = titleBG.stageBounds.yMax

   isDriver = SceneManager.getUserRoleType() == GC.USER_ROLE_TYPE_DRIVER

   local label = "my_shipments"
   if (isDriver) then
      label = "my_loads"
   end

   title = display.newText(sceneGroup, SceneManager.getRosettaString(label), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   count = display.newText(sceneGroup,"",0,0,GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   count.x, count. y = display.contentWidth - 25, titleBG.y

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

   btnEdit = widget.newButton{
      id = "edit",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("edit",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      width = 60,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   btnEdit.x, btnEdit.y = display.contentWidth - btnEdit.width * 0.5 - 5 , titleBG.y
   btnEdit.isVisible = false
   sceneGroup:insert(btnEdit)

   btnRefresh = widget.newButton{
      id = "refresh",
      defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
      overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("refresh",1),
      labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
      icon = {default="graphics/refresh.png",width=GC.ACTION_BUTTON_ICON_SIZE,height=GC.ACTION_BUTTON_ICON_SIZE,align="left"},
      width = 140,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onEventCallback
   }
   if (isDriver) then
      btnRefresh.x = display.contentCenterX
   else
      btnRefresh.x = display.contentWidth - btnRefresh.width * 0.5 - BUTTON_OFFSET
   end
   btnRefresh.y = titleBG.stageBounds.yMax + btnRefresh.height * 0.5 + 10
   sceneGroup:insert(btnRefresh)

   if (not isDriver) then
      btnFilter = widget.newButton{
         id = "filter",
         icon = {default="graphics/dropdown.png",width=16,height=12,align="right",matchTextColor=true},
         labelAlign="left",xOffset = 10,
         defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
         overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
         font = GC.BUTTON_FONT,
         fontSize = 18,
         label=SceneManager.getRosettaString(SHIPMENT_TYPES[shipmentType]),
         labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 140,
         height = GC.BUTTON_ACTION_HEIGHT,
         cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
         strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
         strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
         onRelease = onEventCallback
      }
      btnFilter.x, btnFilter.y = btnFilter.width * 0.5 + BUTTON_OFFSET, titleBG.stageBounds.yMax + btnFilter.height * 0.5 + 10
      sceneGroup:insert(btnFilter)
   end
   
   divider = display.newRect( 0, 0, display.contentWidth, 2 )
   divider.anchorY = 0
   divider:setFillColor(unpack(GC.DARK_GRAY))
   divider.x, divider.y = display.contentCenterX, btnRefresh.stageBounds.yMax + 10
   sceneGroup:insert(divider)

   listTop = divider.stageBounds.yMax
   
   lblNoShipments = display.newText(sceneGroup, SceneManager.getRosettaString("no_results_found"), 0, 0, GC.APP_FONT, 24)
   lblNoShipments:setFillColor(unpack(GC.DARK_GRAY))
   lblNoShipments.isVisible = false
   lblNoShipments.x, lblNoShipments.y = display.contentCenterX, display.contentCenterY

   getShipments()
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
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
      -- Called immediately after scene goes off screen.
      if (not showingOverlay and not showingToast) then
         composer.removeScene("SceneMyShipments")
      end
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

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   lblNoShipments:removeSelf()
   lblNoShipments = nil
   
   if (list) then
      list:removeSelf()
      list = nil
  end

   count:removeSelf()
   count = nil

   btnEdit:removeSelf()
   btnEdit = nil

   btnRefresh:removeSelf()
   btnRefresh = nil

   if (btnFilter) then
      btnFilter:removeSelf()
      btnFilter = nil
   end

   divider:removeSelf()
   divider = nil
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
