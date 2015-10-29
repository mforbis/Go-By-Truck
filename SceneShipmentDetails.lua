local composer = require( "composer" )
local scene = composer.newScene()
local SceneManager = require("SceneManager")
local widget = require("widget-v1")
local widgetNew = require("widget")
local GC = require("AppConstants")
local status = require("status")
local utils = require("utils")

local MessageX = display.contentCenterX
local MessageY = 360

local PADDING = 10

-- NOTE: Maybe drop the shipment from the returned JSON

local bg = nil
local title = nil
local titleBG = nil
local btnClose = nil
local btnEdit = nil
local btnMap = nil
local subTitle = nil
local scrollBG = nil
local webView = nil
local shipment = nil

local callback = nil

local TRAILER_TYPES = {"doubleDropDeck","flatbed","gooseneck","reefer","stepDropDeck","van"}
local LOADING_TYPES = {"crane","dock","forklift","rampLoaded","rearLoaded","sideLoaded"}
local EQUIPMENT_TYPES = {"binders","blankets","boomers","chains","coilRacks","cradles","dunnage",
"levelers","liftGate","loadBars","lumber","padding","palletJack","ramps","pipeStakes","straps",
"pallets","sideKit","ventedVan","sealLockForSecurement","nurseryTarps","smokeTarp","steelTarps",
"lumberTarps"}
local REQUIREMENT_TYPES = {"hardhat","longSleeves","noPassengers","noPets","safetyGlasses",
"steelToedBoots","driverAssist","tolls","layover","tradeShow","storage","fuelSurcharge",
"scale","lumpers","airRide","swingDoors"}

local DETAILS_TEMPLATE = [[
<!DOCTYPE html>
<html xmlns="www.w3.org/1999/xhtml">
<head>    
<title>Go By Truck - Shipment Details</title>
<meta charset="utf-8" />
<meta content="width=device-width, initial-scale=1.0, maximum-scale=1" name="viewport" />
<style>
body {
margin: 0;
font-family: 'Open Sans', Arial, Helvetica, san-serif;
font-size: 14px;
font-weight: 300;
line-height: 20px;
color: #444444;
background-color: #ffffff;
}
.content { margin: 10px;}
.group {
   width: 100%;
   border: 1px solid #eeeeee;
   border-spacing: 0px;
}
.group td {
   padding: 4px;
}
.group tr:nth-child(even) {background: #eeeeee}
.group tr:nth-child(odd) {background: #ffffff}
.group th {
   background: #aaaaaa;
   color: #ffffff;
   text-align: left;
   padding: 4px;
}
h2 {
color: #ef6028;
font-size: 10pt;
margin: 20px 0 0 0;
padding: 0 0 10px 0;
}
</style>
<body>
<div class="content">
<h2>{fromTo}</h2>
{content}
</center>
</div>
</body>
</html>
]]

local TABLE_TEMPLATE = [[
<table class="group">
{rows}
</table>
]]

local HEADER1_TEMPLATE = [[
<tr><th>{value}</th></tr>
]]

local ROW1_TEMPLATE = [[
<tr><td><strong>{id}: </strong>{value}</td></tr>
]]

local ROW2_TEMPLATE = [[
<tr><td><strong>{value}</strong></td></tr>
]]

local function buildHeader2(value)
   return "<h2>"..value.."</h2>"
end

local function getLocations(type,limit)
   local limit = limit or -1
   local locations = {}

   for i = 1, #shipment.locations do
      if tostring(shipment.locations[i].type) == tostring(type) then
         table.insert( locations, i )
      end
      if (#locations == limit) then
         return locations
      end
   end
   
   return locations
end

local function getPickupLocations(limit)
   return getLocations(GC.LOCATION_TYPE_PICKUP,limit)
end

local function getDropoffLocations(limit)
   return getLocations(GC.LOCATION_TYPE_DROPOFF,limit)
end

local function getPickupDate()
   local which = 1
   local pickups = getPickupLocations()

   if (#pickups > 1) then
      -- TODO: Sort by earliest
   end
   
   return utils.formatDate(shipment.locations[pickups[which]].startDate)
end

local function getDropoffDate()
   local which = 1
   local dropoffs = getDropoffLocations()

   if (#dropoffs > 1) then
      -- TODO: Sort by earliest
   end

   return utils.formatDate(shipment.locations[dropoffs[which]].startDate)
end

local function getCityState(address)
   local cityState = ""
   local count = 0
   local first,last = 0,0

   local idx = #address
   for i=1,#address do
      if string.sub( address, idx , idx ) == " " then
         count = count + 1
         if count == 1 then
            last = idx
         end
         if count == 3 then
            first = idx
         end
      end
      idx = idx - 1
   end

   if first ~= 0 and last ~= 0 then
      cityState = string.sub(address, first, last)
      zip = string.sub(address,last+1)
   end

   return cityState
end

local function getCityStateZip(address)
   local cityStateZip,newAddress = "",""
   local count = 0
   local first,last = 0,0

   local idx = #address
   for i=1,#address do
      if string.sub( address, idx , idx ) == " " then
         count = count + 1
         if count == 1 then
            last = idx
         end
         if count == 3 then
            first = idx
         end
      end
      idx = idx - 1
   end

   if first ~= 0 and last ~= 0 then
      cityStateZip = string.sub(address, first)
      newAddress = string.sub(address,1,first-1)
   end

   return newAddress,cityStateZip
end

-- NOTE: Could change, but using first found pickup/dropoff
local function getToFrom()
   local pickup = shipment.locations[getPickupLocations(1)[1]]
   local dropoff = shipment.locations[getDropoffLocations(1)[1]]

   return getCityState(pickup.address).." -> "..getCityState(dropoff.address)
end

local function buildHeaderRow(value)
   return string.gsub(HEADER1_TEMPLATE,"{value}",value or "", 1)
end

local function buildTableRow1(id,value)
   local row = string.gsub(ROW1_TEMPLATE,"{id}",id or "",1)

   return string.gsub(row,"{value}",value or "", 1)
end

local function buildTableRow2(value)
   return string.gsub(ROW2_TEMPLATE,"{value}",value or "", 1)
end

local function getCertifications()
   local certs = ""

   if (shipment.certifications.doubleTripleTrailer) then
      certs = SceneManager.getRosettaString("double_triple_trailer")
   end

   if (shipment.certifications.hazmat) then
      if (certs ~= "") then certs = certs.." - " end
      certs = certs..SceneManager.getRosettaString("hazmat")
   end

   if (shipment.certifications.twikCard) then
      if (certs ~= "") then certs = certs.." - " end
      certs = certs..SceneManager.getRosettaString("twik_card")
   end

   return certs
end

local function getCargoInformation()
   local info = ""

   info = SceneManager.getRosettaString("length")..": "..shipment.loadDetail.length.." ft. "..shipment.loadDetail.lengthInches.." in.; "
   info = info..SceneManager.getRosettaString("width")..": "..shipment.loadDetail.width.." in.; "
   info = info..SceneManager.getRosettaString("height")..": "..shipment.loadDetail.height.." in.; "
   info = info..SceneManager.getRosettaString("weight")..": "..shipment.loadDetail.weight.." lbs.;"

   return info
end

local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

local function getTypesFromArray(array,values)
   local types = ""

   for i = 1, #values do
      if (array[values[i]] == true) then
         if (types ~= "") then types = types..", " end
         types = types..SceneManager.getRosettaString(values[i])
      end
   end

   return types
end

local function getTypesFromArray2(array,values)
   local types = ""
   local key

   for i = 1, #values do
      key = values[i]
      if (array[key] == nil) then
         -- Try the first letter uppercase. Somehow this freaking bug keeps coming back, 
         -- so I'm not trusting the returned data anymore
         key = firstToUpper(key)
      end

      if (array[key] > 0) then
         if (types ~= "") then types = types..", " end
         types = types..SceneManager.getRosettaString(key).."("..array[key]..")"
      end
   end

   return types
end

local function getSpecialEquipment()
   local equipment = getTypesFromArray2(shipment.loadEquipment,EQUIPMENT_TYPES)

   if (shipment.loadEquipment.other and shipment.loadEquipment.other ~= "") then
      if (equipment ~= "") then equipment = equipment..", " end
      equipment = equipment..shipment.loadEquipment.other
   end

   return equipment
end

local function getRequirements()
   local requirements = getTypesFromArray(shipment.options,REQUIREMENT_TYPES)

   if (shipment.options.other and shipment.options.other ~= "") then
      if (requirements ~= "") then requirements = requirements..", " end
      requirements = requirements..shipment.options.other
   end

   return requirements
end

local function getHowLoaded()
   local how = getTypesFromArray(shipment,LOADING_TYPES)

   local maxLength

   if (shipment.maxTrailerLength ~= 100) then
      maxLength = shipment.maxTrailerLength.. " ft."
   else
      maxLength = SceneManager.getRosettaString("none")
   end

   if (how ~= "") then how = how..", " end
   how = how..SceneManager.getRosettaString("max_trailer_length")..": "..maxLength

   return how
end

local function getStops()
   local pickups = getPickupLocations()
   local dropoffs = getDropoffLocations()
   
   return (#pickups + #dropoffs) - 2
end

local function getInsurance()
   local label = "cargo_under_100k"

   local cargoValue = tonumber(shipment.loadDetail.cargoValue) or 0

   if (cargoValue > 100000) then
      label = "cargo_over_100k"
   end

   return SceneManager.getRosettaString(label)
end

local function buildDetailsTable()
   local t = TABLE_TEMPLATE

   local rows = buildTableRow1(SceneManager.getRosettaString("shipment"),shipment.loadIdGuid)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("stops"),getStops())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("pieces"),#shipment.packaging)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("weight"),#shipment.loadDetail.weight)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("commodity"),shipment.loadDetail.commodity)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("pickup"),getPickupDate())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("dropoff"),getDropoffDate())
   rows = rows..buildTableRow2(SceneManager.getRosettaString(utils.getTrailerTypeLabel(shipment.loadType)))

   t = string.gsub(t, "{rows}",rows,1)

   return t
end

local function buildGeneralTable()
   local t = TABLE_TEMPLATE

   local rows = buildTableRow1(SceneManager.getRosettaString("commodity"),shipment.loadDetail.commodity)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("applicable_certificates"),getCertifications())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("coverage"),shipment.coverage)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("expedited"),utils.boolToString(shipment.expedited))
   rows = rows..buildTableRow1(SceneManager.getRosettaString("cargo_information"),getCargoInformation())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("how_loaded"),getHowLoaded())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("allowable_trailer_types"),getTypesFromArray(shipment,TRAILER_TYPES))
   rows = rows..buildTableRow1(SceneManager.getRosettaString("insurance"),getInsurance())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("special_equipment"),getSpecialEquipment())
   rows = rows..buildTableRow1(SceneManager.getRosettaString("requirements"),getRequirements())
   
   t = string.gsub(t, "{rows}",rows,1)

   return t
end

local function findLocationById(id)
   local location = nil

   if (id ~= 0) then
      for i = 1, #shipment.locations do
         if shipment.locations[i].addressGuid == id then
            location = shipment.locations[i]
         end
      end
   end

   return location
end

local function buildPackagingTable(which)
   local t = TABLE_TEMPLATE

   local location = findLocationById(shipment.packaging[which].pkgPickup)
   local sLocation = ""

   if location then
      sLocation = location.alias.." - "..location.address
   end

   local rows = buildTableRow1(SceneManager.getRosettaString("pickup_location"),sLocation)

   rows = rows..buildTableRow1(SceneManager.getRosettaString("packaging_type"),shipment.packaging[which].pkgType)

   rows = rows..buildTableRow1(SceneManager.getRosettaString("quantity"),shipment.packaging[which].pkgValue)

   sLocation = ""

   location = findLocationById(shipment.packaging[which].pkgDropoff)
   
   if location then
      sLocation = location.alias.." - "..location.address
   end

   rows = rows..buildTableRow1(SceneManager.getRosettaString("dropoff_location"),sLocation)

   t = string.gsub(t, "{rows}",rows,1)

   return t
end

local function buildPackagingTables()
   local t = ""

   for i = 1, #shipment.packaging do
      t = t..buildPackagingTable(i)
   end

   return t
end

local function buildCompanyTable()
   local t = TABLE_TEMPLATE

   local rows = buildHeaderRow(SceneManager.getRosettaString("shipper_information",1))
   rows = rows..buildTableRow1(SceneManager.getRosettaString("shipper_id"),shipment.shipperId)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("company_name"),shipment.shipperId)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("address"),shipment.shipperId)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("phone_number"),shipment.shipperId)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("email_address"),shipment.shipperId)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("contact_person"),shipment.shipperId)

   t = string.gsub(t, "{rows}",rows,1)

   return t
end

local function buildLocationRows(location)
   local rows = buildTableRow1(SceneManager.getRosettaString("business_name"),location.alias)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("contact"),location.contactPerson)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("email"),location.contactEmail)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("phone_number"),location.phoneNumber)
   local address, cityStateZip = getCityStateZip(location.address)
   
   rows = rows..buildTableRow1(SceneManager.getRosettaString("address"),address)
   
   rows = rows..buildTableRow1(SceneManager.getRosettaString("city_state_zip"),cityStateZip)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("note"),location.contactPerson)
   rows = rows..buildTableRow1(SceneManager.getRosettaString("pickup_date"),utils.formatDate(location.startDate))
   rows = rows..buildTableRow1(SceneManager.getRosettaString("pickup_time"),location.startTime)

   return rows   
end

local function buildLocationTable()
   local t = TABLE_TEMPLATE

   local rows = buildHeaderRow(SceneManager.getRosettaString("pickup_information",1))

   local locations = getPickupLocations()
   for i=1, #locations do
      rows=rows..buildLocationRows(shipment.locations[locations[i]])
   end

   rows = rows..buildHeaderRow(SceneManager.getRosettaString("dropoff_information",1))

   locations = getDropoffLocations()
   for i=1, #locations do
      rows=rows..buildLocationRows(shipment.locations[locations[i]])
   end
      
   t = string.gsub(t, "{rows}",rows,1)

   return t
end

local function buildDetails()
   local content
   local details = string.gsub(DETAILS_TEMPLATE, "{fromTo}", getToFrom(),1)

   content = buildDetailsTable()
   
   content = content..buildHeader2(SceneManager.getRosettaString("general_information",1))
   content = content..buildGeneralTable()

   content = content..buildHeader2(SceneManager.getRosettaString("packaging_information",1))
   content = content..buildPackagingTables()

   -- Company Information
   --content = content..buildHeader2(SceneManager.getRosettaString("company_information",1))
   --content = content..buildCompanyTable()

   -- Location Information
   content = content..buildHeader2(SceneManager.getRosettaString("location_information",1))
   content = content..buildLocationTable()

   details = string.gsub(details, "{content}", content, 1)

   fileio.write(details,GC.DETAILS_FILENAME)
end

local function showDetails()
   buildDetails()

   webView:request(GC.DETAILS_FILENAME,system.DocumentsDirectory)
end

local function onClose()
   composer.hideOverlay(GC.OVERLAY_ACTION_DISMISS,GC.SCENE_TRANSITION_TIME_MS)
end

local function onEventCallback(event)
   if (callback) then
      callback(event)
   end
end

function scene:create( event )
	local sceneGroup = self.view

   if event.params and event.params.callback and type(event.params.callback) then
      callback = event.params.callback
   end

   bg = display.newRect( sceneGroup,0, 0, 360, 570 )
   bg:setFillColor(unpack(GC.DEFAULT_BG_COLOR))
   bg.x, bg.y = display.contentCenterX, display.contentCenterY

   titleBG = display.newRect( sceneGroup, 0, 0, display.contentWidth, GC.TITLE_BG_HEIGHT )
   titleBG:setFillColor(unpack(GC.TITLE_BG_COLOR))
   titleBG.x, titleBG.y = display.contentCenterX, titleBG.height * 0.5

   title = display.newText(sceneGroup, SceneManager.getRosettaString("shipment_details"), 0, 0, GC.SCREEN_TITLE_FONT, GC.SCREEN_TITLE_SIZE)
   title.x, title.y = titleBG.x, titleBG.y

   btnClose = widget.newButton{
      id = "close",
      defaultColor = defaultColor,
      overColor = overColor,
      font = GC.BUTTON_FONT,
      fontSize = 18,
      label=SceneManager.getRosettaString("close",1),
      labelColor = { default=GC.BUTTON_ACTION_TEXT_COLOR, over=GC.BUTTON_ACTION_TEXT_COLOR_OVER },
      width = 130,
      height = GC.BUTTON_ACTION_HEIGHT,
      cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
      strokeColor = GC.DARK_GRAY,
      strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
      onRelease = onClose
   }
   btnClose.x, btnClose.y = display.contentCenterX, display.contentHeight - btnClose.height * 0.5 - 10
   sceneGroup:insert(btnClose)

   shipment = {loadIdGuid="377",fromCityState="SPRINGFIELD, MO",toCityState="SPRINGFIELD, MO"}
   -- For testing
   local json = require("json")
   shipment = json.decode('{"loadType":8,"van":true,"rampLoaded":false,"sideLoaded":false,"flatbed":false,"rearLoaded":false,"loadPricing":{"paymentId":"0","reserve":"0.00","paymentId2":""},"dock":false,"doubleDropDeck":false,"packaging":[{"pkgValue":5,"pkgDropoff":426,"pkgPickup":423,"pkgType":"Pallets 48x40"},{"pkgValue":1,"pkgDropoff":426,"pkgPickup":438,"pkgType":"Reels"}],"locations":[{"startTime":"","startDate":"2014-08-25","stopDate":"","address":"3524 E Nora St SPRINGFIELD, MO 65809","alias":"GBT","podRequired":false,"type":11,"addressGuid":423,"stopTime":""},{"startTime":"","startDate":"2014-09-02","stopDate":"2014-09-03","address":"3003 E Chestnut Expy SPRINGFIELD, MO 65802","alias":"Moonbeam","podRequired":false,"type":11,"addressGuid":438,"stopTime":""},{"startTime":"","startDate":"2014-08-29","stopDate":"","address":"925 S. Main St. GRAPEVINE, TX 76051","alias":"TX Office","podRequired":false,"type":12,"addressGuid":426,"stopTime":""}],"reefer":false,"gooseneck":false,"pricingOptions":false,"options":{"loadIdGuid":415,"shipperId":9000231,"hardhat":true,"longSleeves":false,"noPassengers":false,"noPets":false,"safetyGlasses":false,"steelToedBoots":false,"driverAssist":false,"tolls":false,"layover":false,"tradeShow":true,"storage":false,"fuelSurcharge":false,"scale":true,"lumpers":true,"airRide":false,"swingDoors":false,"other":"elbow grease","optionsString":"Hard hat, Trade Show / Convention, Scale Tickets, Lumpers, elbow grease"},"publishNow":false,"loadEquipment":{"tarps":0,"chains":0,"ramps":0,"coilRacks":0,"binders":0,"boomers":0,"stopoff":0,"loadBars":0,"nurseryTarps":0,"steelTarps":0,"sealLockForSecurement":0,"dunnage":0,"reeferTemp":0,"liftGate":1,"levelers":0,"cradles":0,"smokeTarp":0,"pallets":0,"straps":0,"palletJack":1,"blankets":0,"padding":0,"lumber":0,"sideKit":0,"pipeStakes":0,"ventedVan":0,"lumberTarps":0,"other":"duct tape","equipmentString":"Lift Gate (1), Pallet Jack, duct tape"},"status":"true","publishLater":false,"scheduledDateStr":"","coolOrFrozen":false,"expedited":false,"maxTrailerLength":100,"liftGate":false,"shipperNote":"","error_msg":{"errorMessage":"","error":""},"forklift":true,"stepDropDeck":false,"certifications":{"loadIdGuid":415,"shipperId":9000231,"alabamaCoil":false,"doubleTripleTrailer":true,"hazmat":true,"twikCard":false,"certificatesString":""},"loadDetail":{"lengthInches":"","height":10,"weight":"40000","commodity":"Electronics Includes cell phones; computers","freightClass":"50","width":100,"length":40,"specificCommodity":"new tablets","cargoValue":"100001.01"},"coverage":"Either","exclusiveUse":false,"crane":false,"user":{"userGuid":1336,"statusId":18,"userType":2,"masterRole":9,"identity":9000231,"firstName":"Mobile","lastName":"Shipper","referralCode":"S36616FCD","loginId":"shippermobile","canRequestAccessorials":""}}')
   shipment.loadIdGuid = shipment.options.loadIdGuid

   if (event.params and event.params.shipment) then
      shipment = event.params.shipment
   else
      -- No Details
      event.params = {}
      event.params.canEdit = true
   end
--https://localhost/gbtspring/mobile/getShipmentDetails?sid=1336&id=415
--options, 
 --"shipperId": 9034386,

    --"loadIdGuid": 460,

   if (shipment) then
      subTitle = display.newText(sceneGroup, SceneManager.getRosettaString("shipment_details_sub",1).. " #"..shipment.loadIdGuid, 0, 0, GC.APP_FONT, 16)
      subTitle:setFillColor(unpack(GC.DARK_GRAY))
      subTitle.anchorX = 0
      subTitle.x, subTitle.y = PADDING * 2, titleBG.stageBounds.yMax + subTitle.height * 0.5 + PADDING
      --[[
      if (event.params.canEdit) then
         btnEdit = widget.newButton{
            id = "edit",
            defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
            overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
            font = GC.BUTTON_FONT,
            fontSize = 18,
            label=SceneManager.getRosettaString("edit_shipment",1),
            labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
            width = 130,
            height = GC.BUTTON_ACTION_HEIGHT,
            cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
            strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
            strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
            onRelease = onEventCallback
         }
         btnEdit.x, btnEdit.y = display.contentWidth - btnEdit.width * 0.5 - PADDING * 2, btnClose.y
         btnClose.x = btnClose.width * 0.5 + PADDING * 2
         sceneGroup:insert(btnEdit)
      end
      ]]--
      -- NOTE: This has been temporarily moved to My Shipments, since we can't call an overlay
      -- while displaying another.
      --[[
      if (shipment.toCityState ~= "" and shipment.fromCityState ~= "") then
         btnMap = widget.newButton{
            id = "map",
            defaultColor = GC.BUTTON_ACTION_BACKGROUND_COLOR,
            overColor = GC.BUTTON_ACTION_BACKGROUND_COLOR_OVER,
            font = GC.BUTTON_FONT,
            fontSize = 18,
            label=SceneManager.getRosettaString("view_map",1),
            labelColor = { default=GC.BUTTON_TEXT_COLOR, over=GC.BUTTON_TEXT_COLOR_OVER },
         width = 100,
            height = GC.BUTTON_ACTION_HEIGHT,
            cornerRadius = GC.BUTTON_ACTION_RADIUS_SIZE,
            strokeColor = GC.BUTTON_ACTION_BORDER_COLOR,
            strokeWidth = GC.BUTTON_ACTION_BORDER_WIDTH,
            onRelease = onEventCallback
         }
         btnMap.x, btnMap.y = display.contentWidth - btnMap.width * 0.5 - PADDING * 2, btnEdit.y
         sceneGroup:insert(btnMap)
      end
      ]]--
      local contentWidth = display.contentWidth
      local contentHeight = display.contentHeight - subTitle.stageBounds.yMax - btnClose.height - PADDING * 4

      scrollBG = display.newRect( sceneGroup, 0, 0, contentWidth, contentHeight)
      scrollBG:setFillColor(1,1,1)
      scrollBG.strokeWidth = 1
      scrollBG:setStrokeColor(unpack(GC.DARK_GRAY))
      scrollBG.x, scrollBG.y = display.contentCenterX, subTitle.stageBounds.yMax + contentHeight * 0.5 + PADDING
      sceneGroup:insert(scrollBG)

      webView = native.newWebView( 0, 0, scrollBG.width, scrollBG.height )
      webView.x, webView.y = scrollBG.x, scrollBG.y
      sceneGroup:insert(webView)

      showDetails()
   end
end

function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
   elseif ( phase == "did" ) then
      _G.overlay = onClose
   end
end

function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase

   if ( phase == "will" ) then
      status.removeStatusMessage()
      _G.overlay = nil
   elseif ( phase == "did" ) then
      -- Called immediately after scene goes off screen.
      composer.removeScene("SceneShipmentDetails",false)
   end
end

-- Called prior to the removal of scene's "view" (display group)
function scene:destroy( event )
   bg:removeSelf()
   bg = nil

   btnClose:removeSelf()
   btnClose = nil

   titleBG:removeSelf()
   titleBG = nil

   title:removeSelf()
   title = nil

   if (btnEdit) then
      btnEdit:removeSelf()
      btnEdit = nil
   end

   if (shipment) then
      subTitle:removeSelf()
      subTitle = nil

      scrollBG:removeSelf()
      scrollBG = nil

      webView:removeSelf()
      webView = nil

      if (btnMap) then
         btnMap:removeSelf()
         btnMap = nil
      end
   end

   shipment = nil
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