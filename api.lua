module(..., package.seeall)

local MultipartFormData = require("class_MultipartFormData")
local utils = require("utils")
local url = require("socket.url")
local json = require("json")
local GC = require("AppConstants")
local ProgressDialog = require("progressDialog")
local SceneManager = require("SceneManager")
local apiCallback = nil
local alert = require("alertBox")

local BASE_URL = GC.BASE_URL
local TEST_BASE = "http://defender.moonbeam.co/"
local API_TIMEOUT_MS = 60000

local timedOut
local apiTimer
local pd

local showPD

local isTesting = nil

local attachImage = nil

local trapError

local lastRequest
local lastAPICall
local lastResponse

local function stopTimeout()
	_G.apiCall = false
	if (apiTimer) then
		timer.cancel(apiTimer)
		apiTimer = nil
	end
end

local function handleCallback(event)
	stopTimeout()

	if (pd) then
		pd:dismiss()
		pd = nil
	end
	showPD = true

	-- TODO: handle event.response (should be JSON)
	local response
	if (event) then
		response = event.response
		Log ("response: "..tostring(event.response))
	end

	lastResponse = response

	-- NOTE: We now trap for instances where the web session timed out
	if (apiCallback) then
		if (timedOut) then
			-- Jeffery wants user to not know their server timed out for this request,
			-- so we obscure it.
			local cbResult = apiCallback({error_msg = {errorMessage = "APPLICATION_EXCEPTION"}})
			
			-- We can't stop the other network call, so we do this to not have the app choke
			-- later if it does eventually happen past the API_TIMEOUT_MS period
			apiCallback = nil
		elseif (response) then
			-- TODO: Handle garbled json result
			-- Need this check? response.status ~= 200
			local cbResult = apiCallback(json.decode(response))
		else
			-- TODO: Send error Email
			
			local cbResult = apiCallback({error_msg = {errorMessage = "APPLICATION_EXCEPTION"}})
		end
	end
	
	trapError = true
end

function handleTimeout()
	timedOut = true
	stopTimeout()
   	handleCallback()
end

local function startTimeout()
	timedOut = false
   	stopTimeout()
   	_G.apiCall = true
	apiTimer = timer.performWithDelay(API_TIMEOUT_MS, handleTimeout)
end

local function setCallback(callback)
	attachImage = false

	-- Hack since we are hitting two different URLs for now
	-- Individual command will override this (see getCitiesByState)
	if (callback ~= nil) and (type(callback) == "function") then
		apiCallback = callback
	else
		callback = nil
	end
end

local function resetCallback()
	apiCallback = nil
end

local function sendNetworkRequest(url,command)
	local baseURL = BASE_URL

	if (url) then
		url = url.."&api_key="..(GC.API_KEY or "")
	end

	local isPost = false

	if (command) then
		isPost = true
		--Log ("isPost")
	end

	startTimeout()
	
	if (showPD == nil) then
		showPD = true
	end

	if (showPD) then
		pd = ProgressDialog:new({graphic="graphics/busy.png"})
	end
	
	local request = baseURL

	if (command) then
		lastAPICall = command
		request = request..command.." body: "..url
	else
		request = request..url
		local index = string.find(url,"?")
		if (index) then
			lastAPICall = string.sub(url, 1, index-1)
		end
	end

	lastRequest = request
	
	Log ("GBT (network): "..request)

	-- Comment/Uncomment to do quick toggling when shipping live code
	if (not _G.beta) then
		isTesting = nil
	end

	if (isTesting) then
		Log ("GBT: Test API Call Follows")
		Log ("isTesting: "..tostring(isTesting))
		-- NOTE: For debugging
		--response = '{"user_type":1,"master_role":6,"status_id":18,"user_guid":548,"error_msg":""}'
		--response = '{"user_type":-1,"status_id":-1,"user_guid":-1,"error_msg":"INSUFFICIENT_PARAMETERS"}'
		--response = '{"alias":"GBT","address":"3524 E Nora St","zip":"65809","city":"SPRINGFIELD","state":"MO","phone":"417-501-8919","type":"true","error_msg":""}'
		if (isTesting == "login") then
			response = '{"user":{"userGuid":-1,"statusId":-1,"userType":-1,"masterRole":-1,"identity":-1,"firstName":"","lastName":""},"error_msg":{"errorMessage":"UNKNOWN_USER","error":""}}'
			--response = '{"user":{"userGuid":-1,"statusId":-1,"userType":-1,"masterRole":-1,"identity":-1,"firstName":"","lastName":""},"error_msg":{"errorMessage":"AUTHENTICATION_FAILURE","error":""}}'
			--response = '{"user":{"userGuid":1343,"statusId":18,"userType":1,"masterRole":3,"identity":42578,"firstName":"Old","lastName":"McDonald"},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getMyShipments") then -- My Shipments
			response = '{ "shipments": [ { "loadIdGuid": "381", "postedDate": "06-03-2014 14:51", "fromCityState": "SPRINGFIELD, MO", "toCityState": "MOORE,OK", "autoAccept": "750.00", "bol": "", "pu": "", "po": "" },{ "loadIdGuid": "380", "postedDate": "06-02-2014 11:38", "fromCityState": "SPRINGFIELD, MO", "toCityState": "SPRINGFIELD, MO", "autoAccept": "", "bol": "", "pu": "", "po": "" } ],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{"shipments":[],"user":{"userGuid":1343,"statusId":18,"userType":2,"masterRole":9,"identity":9000231,"firstName":"Jimbo","lastName":"Slice"},"error_msg":{"errorMessage":"","error":""}}'
			--response = '{"error":"getMyCarrierShipments() method not implemented","user":{"userGuid":-1,"statusId":-1,"userType":-1,"masterRole":-1,"identity":-1,"firstName":"","lastName":""},"error_msg":"APPLICATION_EXCEPTION"}'
			-- For testing with location data (matched shipments)
			--response = '{"shipments":[{"loadIdGuid":128,"postedDate":"Feb 6, 2014 11:52:52 AM","fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","autoAcceptAmount":"100.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"635","loadType":8,"latitude":"37.21057","longitude":"-93.23310"},{"loadIdGuid":132,"postedDate":"Feb 6, 2014 3:54:37 PM","fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","autoAcceptAmount":"100.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":0,"tripMiles":"606","loadType":8},{"loadIdGuid":135,"postedDate":"Feb 8, 2014 7:02:52 PM","fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","autoAcceptAmount":"130.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"1213","loadType":8},{"loadIdGuid":137,"postedDate":"Apr 10, 2014 6:51:46 PM","fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","autoAcceptAmount":"100.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":8,"tripMiles":"1","loadType":8},{"loadIdGuid":139,"postedDate":"Feb 9, 2014 10:51:27 AM","fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","autoAcceptAmount":"10.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"1213","loadType":8}],"user":{"userGuid":1168,"statusId":18,"userType":2,"masterRole":9,"identity":9000200,"firstName":"Shipper","lastName":"Feb","referralCode":"S095774A8","loginId":"ShipperFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
			response = '{"status":"true","shipments":[{"loadIdGuid":128,"postedDate":"Feb 6, 2014 11:52:52 AM","fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","autoAcceptAmount":"100.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"637","loadType":8,"hasRequestedAccessorials":false,"releaseCode":"VCY5daLfiMVY"},{"loadIdGuid":132,"postedDate":"Feb 6, 2014 3:54:37 PM","fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","autoAcceptAmount":"100.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":0,"tripMiles":"606","loadType":8,"hasRequestedAccessorials":false,"releaseCode":"JIY8SYdCuWjK"},{"loadIdGuid":135,"postedDate":"Feb 8, 2014 7:02:52 PM","fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","autoAcceptAmount":"130.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"1213","loadType":8,"hasRequestedAccessorials":false,"releaseCode":"H2kPajieFLEG"},{"loadIdGuid":139,"postedDate":"Feb 9, 2014 10:51:27 AM","fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","autoAcceptAmount":"10.00","bol":"","pu":"","po":"","status":26,"shipperId":9000200,"podRequired":"0","stopoffCount":2,"tripMiles":"1214","loadType":8,"hasRequestedAccessorials":true,"releaseCode":"exFU5A2tKyMj"}],"user":{"userGuid":1168,"statusId":18,"userType":2,"masterRole":9,"identity":9000200,"firstName":"Shipper","lastName":"Feb","referralCode":"S095774A8","loginId":"ShipperFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "remove") then -- Delete Shipment
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getShipmentDetails") then
			-- NOTE: Seems matchedAmount, fundedAmount or lowestQuote will show, but not at same time.
			-- Not sure of the logic, but they can decide when to send field in response. (shipment status?)
			response = [[{"status":"true",
				"shipment":{"loadIdGuid": 385, "shipperId": 1336,
				"shipperNote":"if shipment had a note",
				"loadDetail":{"weight":10000,"length":13,"lengthInches":0,"width":100,
				"height":10,"commodity":"Electronics Includes cell phones; computers",
				"specificCommodity":"new tablets","freightClass":50,"cargoValue":100000.01},
				"tripMiles":431, "lowestQuote":555.96,
				"matchedAmount":"", "loadType":9, "exclusiveUse":true,
				"certifications":{"doubleTripleTrailer":true,"hazmat":true, "twikCard":false},
				"coverSelected":true, "coverage":"Either",
				"expedited":false,"maxTrailerLength":100,"crane":true,"dock":true,"forkLift":true,
				"liftGate":false,"rampLoaded":true,"rearLoaded":true,"sideLoaded":true,
				"doubleDropDeck":true,"flatbed":true,"gooseneck":true,"reefer":true,
				"stepDropDeck":true,"van":true,
				"loadEquipment":{"binders":false,"blankets":false,"boomers":false,"chains":true,
				"coilRacks":false,"cradles":false,"dunnage":false,"levelers":false,"liftGate":false,
				"loadBars":false,"lumber":false,"padding":false,"palletJack":true,"ramps":false,
				"pipeStakes":false,"straps":false,"pallets":false,"sideKit":false,"ventedVan":false,
				"sealLockForSecurement":false,"other":"duct tape"},
				"options":{"hardhat":false,"longSleeves":false,"noPassengers":false,"tolls":false,
				"lumpers":false,"layover":false,"safetyGlasses":false,"driverAssist":false,
				"steelToedBoots":false,"storage":false,"fuelSurcharge":true,"noPets":false,
				"airRide":false,"swingDoors":false,"tradeShow":false,"scale":false,
				"other":"elbow grease"}, "numQuotes":"1",
				"packaging":[{"pkgType":"Rolls","pkgValue":5,"pkgPickup":438,"pkgDropoff":426},
				{"pkgType":"Reels","pkgValue":1,"pkgPickup":423,"pkgDropoff":426}],
				"locations":[{"addressGUID":423,"type":11,"alias":"GBT","address1":"3524 E Nora St","address2":"","city":"SPRINGFIELD","state":"MO","zip":"65809","startDate":"08/25/2014","endDate":"08/26/2014","startTime":"03:28 pm EST","stopTime":"04:30 pm EST"},
				{"addressGUID":438,"type":11,"alias":"Moonbeam","address1":"3003 E Chestnut Expy","address2":"STE 575","city":"SPRINGFIELD","state":"MO","zip":"65802","startDate":"09/02/2014","endDate":"09/03/2014"},
				{"addressGUID":426,"type":12,"alias":"TX Office","address1":"925 S. Main St.","address2":"","city":"GRAPEVINE","state":"TX","zip":"76051","startDate":"08/29/2014","endDate":""}],
				"pickup":{ "name":"GBT","address": "3524 E Nora St",
				"city":"SPRINGFIELD","state": "MO", "zip": "65809", "startDate":"08/18/2014",
				"endDate":"08/18/2014"}, "delivery":{ "name":"TX Office",
				"address": "925 S. Main St.", "city": "GRAPEVINE","state": "TX", "zip": "76051",
				"startDate":"08/21/2014","endDate":""}},"error_msg":{"errorMessage":"","error":""}}]]
				response = '{"loadType":8,"van":false,"rampLoaded":false,"sideLoaded":false,"flatbed":false,"rearLoaded":false,"loadPricing":{"paymentId":"0","reserve":"0.00","paymentId2":""},"dock":false,"doubleDropDeck":false,"packaging":[{"pkgValue":5,"pkgDropoff":426,"pkgType":423},{"pkgValue":1,"pkgDropoff":426,"pkgType":0}],"locations":[{"startTime":"","startDate":"2014-08-25","stopDate":"","address":"3524 E Nora St SPRINGFIELD, MO 65809","alias":"GBT","podRequired":false,"type":11,"addressGuid":423,"stopTime":""},{"startTime":"","startDate":"2014-09-02","stopDate":"2014-09-03","address":"3003 E Chestnut Expy SPRINGFIELD, MO 65802","alias":"Moonbeam","podRequired":false,"type":11,"addressGuid":438,"stopTime":""},{"startTime":"","startDate":"2014-08-29","stopDate":"","address":"925 S. Main St. GRAPEVINE, TX 76051","alias":"TX Office","podRequired":false,"type":12,"addressGuid":426,"stopTime":""}],"reefer":false,"gooseneck":false,"pricingOptions":false,"options":{"loadIdGuid":415,"shipperId":9000231,"hardhat":true,"longSleeves":false,"noPassengers":false,"noPets":false,"safetyGlasses":false,"steelToedBoots":false,"driverAssist":false,"tolls":false,"layover":false,"tradeShow":true,"storage":false,"fuelSurcharge":false,"scale":true,"lumpers":true,"airRide":false,"swingDoors":false,"other":"elbow grease","optionsString":"Hard hat, Trade Show / Convention, Scale Tickets, Lumpers, elbow grease"},"publishNow":false,"loadEquipment":{"shipperId":9000231,"loadIdGuid":415,"tarps":0,"chains":0,"ramps":0,"coilRacks":0,"binders":0,"boomers":0,"stopoff":0,"loadBars":0,"nurseryTarps":0,"steelTarps":0,"sealLockForSecurement":0,"dunnage":0,"reeferTemp":0,"liftGate":1,"levelers":0,"cradles":0,"smokeTarp":0,"pallets":0,"straps":0,"palletJack":1,"blankets":0,"padding":0,"lumber":0,"sideKit":0,"pipeStakes":0,"ventedVan":0,"lumberTarps":0,"other":"duct tape","equipmentString":"Lift Gate (1), Pallet Jack, duct tape"},"status":"true","publishLater":false,"scheduledDateStr":"","coolOrFrozen":false,"expedited":false,"maxTrailerLength":100,"liftGate":false,"shipperNote":"","error_msg":{"errorMessage":"","error":""},"forklift":true,"stepDropDeck":false,"certifications":{"loadIdGuid":415,"shipperId":9000231,"alabamaCoil":false,"doubleTripleTrailer":true,"hazmat":true,"twikCard":false,"certificatesString":""},"loadDetail":{"lengthInches":"","height":10,"weight":"40000","commodity":"Electronics Includes cell phones; computers","freightClass":"50","width":100,"length":40,"specificCommodity":"new tablets","cargoValue":"100001.01"},"coverage":"Either","exclusiveUse":false,"crane":false,"user":{"userGuid":1336,"statusId":18,"userType":2,"masterRole":9,"identity":9000231,"firstName":"Mobile","lastName":"Shipper","referralCode":"S36616FCD","loginId":"shippermobile","canRequestAccessorials":""}}'
				--response = '{"status":"false","error_msg":{"errorMessage":"invalid_server_response","error":""}}'
		elseif (isTesting == 'shipmentServices') then
			response = '{"type":"truckLoad","exclusiveUse":false,"expedited":false,"crane":false,"dock":true,"forkLift":true,"liftGate":false,"rampLoaded":false,"rearLoaded":true,"sideLoaded":false,"coverSelected":false,"coverage":"Tarps","error_msg":""}'
			--type, (truckLoad,ltl,overDimensional)
			--coverage, (Tarps,Dry Van,Either)
		elseif (isTesting == 'shipmentTrailers') then
			response = '{"error_msg":"","ddd":false,"flatbed":true,"gooseneck":false,"reefer":false,"stepdropdeck":false,"van":true,"maxLength":0}'
		elseif (isTesting == 'escrowOptions') then
			response = '{"error_msg":""}'
		elseif (isTesting == 'getCompanyAddress') then
			--response = '{"company_address":null,"status":"true","user":{"userGuid":-1,"statusId":-1,"userType":-1,"masterRole":-1,"identity":-1,"firstName":"","lastName":""},"error_msg":{"errorMessage":"UNKNOWN_USER","error":""}}'
			response = '{"company_address":{"alias":"CanadaTest","address":"3882 RUE NINA","zip":"H7P 1G1","city":"Laval","state":"QC","residential":false},"status":"true","user":{"userGuid":1344,"statusId":18,"userType":1,"masterRole":3,"identity":715368,"firstName":"Canada","lastName":"Test"},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == 'getMyQuotes') then
			--response = '{ "quotes": [ { "loadIdGuid": "385", "po":"", "fromCityState": "SPRINGFIELD, MO", "toCityState": "GRAPEVINE, TX", "autoAccept": "0.00", "fundedAmount": "0.00", "lowestQuote": "500.00"}],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{ "quotes": [ { "loadIdGuid": "385", "fromCityState": "SPRINGFIELD, MO", "toCityState": "GRAPEVINE, TX", "quoteAmount": "750.00", "modifiedDate": "06-03-2014 14:51", "quoteStatus": ""}],"error_msg":{"errorMessage":"","error":""}}'
			-- quoteAmount carrier_quote_amount
			-- gbnt_0500_load_quote table
			-- url: https://www.gbthq.com:9443/carrier/quoteManager/actionItems
			-- url: https://www.gbthq.com:9443/shipper/quoteManager/actionItems
			-- quoteStatus status_id (looks like pointer to another table)
			--response = '{ "quotes": [],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{"quotes":[{"loadIdGuid":414,"quoteId":330,"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","quoteAmount":333.73,"modifiedDate":"Oct 29, 2014 4:45:57 PM","statusId":24},{"loadIdGuid":342,"quoteId":328,"fromCityState":"SPRINGFIELD, MO","toCityState":"SCHENECTADY, NY","quoteAmount":555.96,"modifiedDate":"Aug 11, 2014 1:57:21 PM","statusId":24},{"loadIdGuid":318,"quoteId":290,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1455.00,"modifiedDate":"Apr 14, 2014 7:52:28 AM","statusId":24},{"loadIdGuid":318,"quoteId":289,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1400.00,"modifiedDate":"Apr 14, 2014 7:51:17 AM","statusId":24},{"loadIdGuid":318,"quoteId":288,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":1500.00,"modifiedDate":"Apr 14, 2014 7:51:01 AM","statusId":24},{"loadIdGuid":112,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":350.00,"modifiedDate":"Feb 12, 2014 4:06:02 PM","statusId":24},{"loadIdGuid":112,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":600.00,"modifiedDate":"Feb 12, 2014 3:42:01 PM","statusId":24}],"status":"true","user":{"userGuid":1169,"statusId":18,"userType":1,"masterRole":3,"identity":564,"firstName":"Carrier","lastName":"Feb","referralCode":"CF2F932AB","loginId":"CarrierFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
			--response = '{"quotes":[{"loadIdGuid":414,"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","reserve":0.00,"fundedAmount":0.00,"lowestQuote":333.73}],"status":"true","user":{"userGuid":1168,"statusId":18,"userType":2,"masterRole":9,"identity":9000200,"firstName":"Shipper","lastName":"Feb","referralCode":"S095774A8","loginId":"ShipperFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
			response = '{"quotes":[{"loadIdGuid":467,"fromCityState":"NASHVILLE, TN","toCityState":"AUSTIN, TX","reserve":0.00,"fundedAmount":0.00,"lowestQuote":1.44},{"loadIdGuid":461,"fromCityState":"SPRINGFIELD, MO","toCityState":"NASHVILLE, TN","reserve":1300.00,"fundedAmount":1300.00,"lowestQuote":798.29},{"loadIdGuid":429,"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","reserve":0.00,"fundedAmount":0.00,"lowestQuote":6.27},{"loadIdGuid":423,"fromCityState":"BOWLING GREEN, KY","toCityState":"NASHVILLE, TN","reserve":0.00,"fundedAmount":0.00,"lowestQuote":95.00}],"status":"true","user":{"userGuid":1168,"statusId":18,"userType":2,"masterRole":9,"identity":9000200,"firstName":"Shipper","lastName":"Feb","referralCode":"S095774A8","loginId":"ShipperFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
			-- Testing carrier has approved confirm (31)
			--response = '{"quotes":[{"loadIdGuid":112,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":600.00,"modifiedDate":"Dec 29, 2014 3:54:30 PM","statusId":31,"quoteId":111},{"loadIdGuid":112,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","quoteAmount":350.00,"modifiedDate":"Dec 29, 2014 3:53:52 PM","statusId":42,"quoteId":116}],"status":"true","user":{"userGuid":1169,"statusId":18,"userType":1,"masterRole":3,"identity":564,"firstName":"Carrier","lastName":"Feb","referralCode":"CF2F932AB","loginId":"CarrierFeb","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == 'getLoadQuotes') then
			response = '{"quotes":[{"quoteId":330,"carrierQuote":333.73,"shipperQuote":0,"date":"10-29-2014 16:45","carrierId":1169,"feedbackScore":100,"statusId":24}],"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == 'getBankingDetails') then
			response = '{"actualAmount":"3968.11","pendingAmount":"0.00","creditAmount":"1347.00","wiredAmount":"0.00","rewardAmount":"0.00","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == 'getMyTrailers') then
			response = '{ "trailers": [ {"trailerId":"43","trailerType":"Van","length":"other","lengthOther":"53","width":"other","widthOther":"102","maxPayload":"99999"},{"trailerId":"43","trailerType":"Removable Gooseneck","length":"53","width":"102","maxPayload":"99999"}],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{ "trailers": [ {"trailerId":"43","trailerType":"Van","length":"other","lengthOther":"53","width":"other","widthOther":"102","maxPayload":"99999"}],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{ "trailers": [ {"trailerId":"43","trailerType":"Van","length":"other","lengthOther":"53","width":"other","widthOther":"102","maxPayload":"99999"}],"error_msg":{"errorMessage":"","error":""}}'
			-- carrierJan test
			response = '{"trailers":[{"trailerId":102,"trailerType":"Hopper Bottom","maxPayload":"54321","statusId":1}, {"trailerId":100,"trailerType":"Flatbed","length":"48","width":"102","maxPayload":"49000","statusId":1}, {"trailerId":99,"trailerType":"Belt","maxPayload":"44500","statusId":1}, {"trailerId":98,"trailerType":"Reefer","length":"48","width":"102","maxPayload":"42000","statusId":1}, {"trailerId":97,"trailerType":"Step/Drop Deck","length":"53","width":"102","maxPayload":"45000","statusId":1}, {"trailerId":96,"trailerType":"Van","length":"48","width":"102","maxPayload":"42000","statusId":1}, {"trailerId":94,"trailerType":"Van","length":"28","width":"96","maxPayload":"2456","statusId":1}, {"trailerId":93,"trailerType":"Hopper Bottom","maxPayload":"52500","statusId":1}, {"trailerId":92,"trailerType":"Reefer","length":"43","width":"122","maxPayload":"64532","statusId":1}, {"trailerId":91,"trailerType":"Reefer","length":"43","width":"120","maxPayload":"56456","statusId":1}, {"trailerId":90,"trailerType":"Van","length":"40","width":"120","maxPayload":"55555","statusId":1}, {"trailerId":87,"trailerType":"Stretch Trailer","length":"53","width":"102","maxPayload":"43000","statusId":1}, {"trailerId":85,"trailerType":"Curtain Van","length":"53","width":"102","maxPayload":"43000","statusId":1}, {"trailerId":84,"trailerType":"Conestoga","length":"53","width":"102","maxPayload":"44000","statusId":1}, {"trailerId":83,"trailerType":"Pneumatic","maxPayload":"42500","statusId":1}, {"trailerId":82,"trailerType":"Tow Truck","statusId":1}, {"trailerId":81,"trailerType":"Power Only","statusId":1}, {"trailerId":80,"trailerType":"Mobile Home Trailer","statusId":1}, {"trailerId":79,"trailerType":"Driveaway","statusId":1}, {"trailerId":78,"trailerType":"Open","statusId":1}, {"trailerId":77,"trailerType":"Closed","statusId":1}, {"trailerId":76,"trailerType":"Closed","statusId":1}, {"trailerId":75,"trailerType":"Auger","maxPayload":"43000","statusId":1}, {"trailerId":74,"trailerType":"Tanker","maxPayload":"41000","statusId":1}, {"trailerId":73,"trailerType":"Belly Dump","maxPayload":"50000","statusId":1}, {"trailerId":72,"trailerType":"Flatbed","length":"53","width":"102","maxPayload":"48000","statusId":1}, {"trailerId":71,"trailerType":"Van","length":"53","width":"102","maxPayload":"48000","statusId":1}],"status":"true","user":{"userGuid":1384,"statusId":18,"userType":1,"masterRole":3,"identity":259711,"firstName":"Carrier","lastName":"Jan","referralCode":"C82A50758","loginId":"carrierjan","canRequestAccessorials":""},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "remove_trailer") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "addEditTrailer") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "get_locations") then
			response = '{"status":"true","locations":[{"name":"Driver Mobile","userGuid":"1337","latitude":37.21057,"longitude":-93.23310,"modifiedDate":"Jul 25, 2014 4:18:37 PM"},{"name":"Driver Moonbeam","userGuid":"1345"}],"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "send_app") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getFeedbackDetails") then
			--response = '{"status":"true","scores":["100.00","0.00","0.00","0.00","100.00","0.00","0.00","0.00","100.00"],"final":"50.0","shipments":0,"member_since":"2014-07-16 11:17:38.0","error_msg":{"errorMessage":" ","error":""}}'
			response = '{"final":100.0,"member_since":"2014-04-25 11:33:23.0","scores":[100.10,100.99,100.99,0.00,0.00,0.00,0.00,0.00,0.00],"status":"true","shipments":1009,"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "postFeedback") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getDriverLoads") then
			--response = '{"status":"true","shipments": [],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{ "status": "true", "shipments": [ { "loadIdGuid": "385", "pickUpDate": "06-03-2014 14:51", "pickup":{ "name":"GBT","address": "3524 E Nora St", "cityState": "SPRINGFIELD, MO", "zip": "65809", "reference": { "bol": "", "pu": "", "po": "" } }, "delivery":{ "name":"TX Office", "address": "925 S. Main St.", "cityState": "GRAPEVINE, TX", "zip": "76051", "reference": { "bol": "", "pu": "", "po": "" } }, "shipperId": "1336", "amount": "750.00", "accessorials": false, "podRequired": true, "status": "38" } ], "error_msg":{"errorMessage":"","error":""}}'
			-- New response
			--response = '{"status":"true","shipments":{"shipment1":{"dropoffDate":"10\/03\/2014","loadType":"9","status":26,"lowestQuote":"","address1":{"zip":"65807","cityState":"SPRINGFIELD, SPRINGFIELD, MO","address":"314 w walnut ","name":"Shipper Reward","reference":{"bol":"","pu":"3456EGTRH,SDGF4563","po":"3456EGFTRH"}},"bol":"","address2":{"zip":"78710","cityState":"AUSTIN, AUSTIN, TX","address":"314 w walnut ","name":"Shipper Reward","reference":{"bol":"92136D2716","pu":"GF2345","po":"2346FHS"}},"poNumber":"","address3":{"zip":"65802","cityState":"SPRINGFIELD, SPRINGFIELD, MO","address":"314 w walnut lawn ","name":"Address 100","reference":{"bol":"E82ED419FB","pu":"57689TH","po":"34576GFS,GFH236ITYU8"}},"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","tripMiles":"1214","shipperScore":"","amount":"","pieces":"","stops":"1","postedDate":"2014-07-31 10:38:58.0","commodity":"","autoAcceptAmount":"1500.00","loadIdGuid":397,"pickupDate":"10\/03\/2014","accessorials":"false","pu":"","podRequired":"false","shipperId":9000204}},"user":{"userGuid":1350,"statusId":18,"userType":1,"masterRole":6,"identity":75840,"firstName":"Jim","lastName":"Bob","referralCode":"C32C78CAF","loginId":"TestDriver","canRequestAccessorials":"true"},"error_msg":{"errorMessage":"","error":""}}'
			response = '{"status":"true","shipments2":{"shipment1":{"dropoffDate":"10\/03\/2014","loadType":"9","status":26,"lowestQuote":"","address1":{"type":"11","addressGuid":"438","zip":"65807","cityState":"SPRINGFIELD, SPRINGFIELD, MO","address":"314 w walnut ","name":"Shipper Reward","reference":{"bol":"","pu":"3456EGTRH,SDGF4563","po":"3456EGFTRH"}},"bol":"","address2":{"type":"11","addressGuid":"419","zip":"78710","cityState":"AUSTIN, AUSTIN, TX","address":"314 w walnut ","name":"Shipper Reward","reference":{"bol":"92136D2716","pu":"GF2345","po":"2346FHS"}},"poNumber":"","address3":{"type":"12","addressGuid":"111","zip":"65802","cityState":"SPRINGFIELD, SPRINGFIELD, MO","address":"314 w walnut lawn ","name":"Address 100","reference":{"bol":"E82ED419FB","pu":"57689TH","po":"34576GFS,GFH236ITYU8"}},"fromCityState":"SPRINGFIELD, MO","toCityState":"SPRINGFIELD, MO","tripMiles":"1214","shipperScore":"","amount":"","pieces":"","stops":"1","postedDate":"2014-07-31 10:38:58.0","commodity":"","autoAcceptAmount":"1500.00","loadIdGuid":397,"pickupDate":"10\/03\/2014","accessorials":"false","pu":"","podRequired":"false","shipperId":9000204}},"user":{"userGuid":1350,"statusId":18,"userType":1,"masterRole":6,"identity":75840,"firstName":"Jim","lastName":"Bob","referralCode":"C32C78CAF","loginId":"TestDriver","canRequestAccessorials":"true"},"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "referColleague") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getCitiesByState") then
			--response = '{"status":"true","cityList":"Acornridge:Adair:Adrian:Advance:Affton","error_msg":{"errorMessage":"","error":""}}'
			response = '{"status":"true","cities":["Acornridge","Adair","Adrian","Advance","Affton","Brighton","Camden","Springfield"],"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "findFreight") then
			response = '{"status":"true","shipments":[{"loadIdGuid":"367","shipperId":"1336","shipperScore":"100.0","autoAccept":false,"fromCityState":"SPRINGFIELD, MO","toCityState":"AUSTIN, TX","stops":"1","pieces":"3","weight":"13000","commodity":"Agricultural - Mulch","tripMiles":"606","pickUpDate":"10/03/2014","deliveryDate":"11/01/2014","lowestQuote":"300.00","loadType":"8"}],"error_msg":{"errorMessage":"","error":""}}'
			--response = '{"status":"true","shipments":[],"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getShipperInfo") then
			response = '{"status":"true","companyStatus":"18","ein":"5252","companyName":"Shipper Reward","address":"314 w walnut SPRINGFIELD MO 65807","phoneNumber":"417-655-5555","emailAddress":"madams@gobytruck.com","contactPerson":"Shipper Reward","memberSince":"2014-02-09 15:19:28.0","loadsThroughGbt":"39","disputes":"0","tonu":"0","q1Satisfied":"0.00","q1Neutral":"0.00","q1Unsatisfied":"0.00","q2Satisfied":"0.00","q2Neutral":"0.00","q2Unsatisfied":"0.00","q3Satisfied":"0.00","q3Neutral":"0.00","q3Unsatisfied":"0.00","feedbackScore":"100","mostRecentNote":"","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "sendPod") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "sendClaimPhoto") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getDetailsForPOD") then
			response = '{"status":"true","bol":"ADD6AD2D01","driver":"Mobile Driver","truck":"","trailer":"","locations":[{"addressGuid":"111","type":"11","alias":"GBT","phoneNumber":"777-777-7777","address":"6565 N. MacArthur","city":"EULESS","state":"TX","zip":"76039","startDate":"09/30/2014","endDate":""},{"addressGuid":"438","type":"12","alias":"123","phoneNumber":"444-555-6666","address":"1234 My Street","city":"SPRINGFIELD","state":"MO","zip":"65803","startDate":"09/26/2014","endDate":""}],"shipper":{"shipperId":9999,"companyName":"Go By Truck","address":"3524 e Nora","city":"SPRINGFIELD","state":"MO","zip":"65803","phoneNumber":"417-501-8919","contactEmail":"drauhoff@gobytruck.com","contactName":"John Doe"},"carrier":{"MCNumber":"2000000","companyName":"Go By Truck","address":"3524 e Nora","city":"SPRINGFIELD","state":"MO","zip":"65803","phoneNumber":"417-501-8919","contactEmail":"jheine@gobytruck.com","contactName":"John Doe"},"packaging":[{"pkgValue":2,"hazmat":"false","pkgType":"Bundles","pkgPickup":"111"}],"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getLocations") then
			response = '{"status":"true","locations":[{"addressGuid":438,"alias":"Moonbeam","address1":"3003 E Chestnut Expy","address2":"STE 575","city":"SPRINGFIELD","state":"MO","zip":"65802","phoneNumber":"417-501-6682","contactEmail":"support@moonbeam.co","contactName":"MoonbeamDev"},{"addressGuid":426,"type":12,"alias":"TX Office","address1":"925 S. Main St.","address2":"","city":"GRAPEVINE","state":"TX","zip":"76051","startDate":"08/29/2014","endDate":""}],"error_msg":{"errorMessage":"","error":""}}​​'
		elseif (isTesting == "addEditShipment") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "submitQuote") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "removeQuote") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "declineQuote") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "counterQuote") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "outstandingCharges") then
			response = '{"status":"true","result":"yes","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getPaymentOptions") then
			response = '{"status":"true","options":[{"id":334,"label":"Jefferys American Express | ...0005 | AMERICAN EXPRESS"},{"id":336,"label":"Jefferys 2nd American Express | ...8431 | AMERICAN EXPRESS"},{"id":335,"label":"Jefferys Visa.......................... | ...1111 | VISA"}],"gbtBalance":623,"ccFeePct":2.59,"isNoCCFees":false,"error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "acceptQuote") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "fundLoad") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "requestAccessorials") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "checkSessionId") then
			response = '{"sessionvalid":"true"}'
		elseif (isTesting == "sendErrorEmail") then
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "getNotificationsByUser") then
			-- Error
			response = '{"status":"false","error_msg":{"errorMessage":"INSUFFICIENT_PARAMETERS","error":""}}'
			-- Success
			-- NOTE: Not sure of 'mobileAppOs'???
			--response = '{"status":"true", "notifications": [], "error_msg":{"errorMessage":"","error":""}}'
			response = '{"status":"true", "notifications": [{"notificationId":"394", "type":"quote", "body":"A carrier has submitted a quote in the amount of $1099.33 for shipment #490.", "mobileAppOs":"1", "read":"0"}], "error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "markNotifcationAsRead") then
			-- Error
			response = '{"status":"false","error_msg":{"errorMessage":"INSUFFICIENT_PARAMETERS","error":""}}'
			-- Success
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		elseif (isTesting == "deleteNotification") then
			-- Error
			response = '{"status":"false","error_msg":{"errorMessage":"INSUFFICIENT_PARAMETERS","error":""}}'
			-- Success
			response = '{"status":"true","error_msg":{"errorMessage":"","error":""}}'
		end

		lastResponse = response

		isTesting = nil

		Log ("API response: "..tostring(response))

		-- NOTE: Below just for testing
		--if (isTesting ~= "login") then
			stopTimeout()
			if (pd) then
				pd:dismiss()
				pd = nil
			end
			
			if (apiCallback) then
				local cbResult = apiCallback(json.decode(response))
			end
		--end
	else
		if (not isPost) then
			network.request(baseURL..url, "GET", handleCallback )
		elseif attachImage == false then
			local headers = {}

			headers["Content-Type"] = "application/x-www-form-urlencoded"
			headers["Accept-Language"] = "en-US"

			local params = {}
			params.headers = headers

			params.body = url

			local POST_URL = baseURL
			Log ("post follows")

				POST_URL = POST_URL..command
			Log ("url: "..POST_URL)
			Log ("command: "..json.encode(params))
			network.request( POST_URL, "POST", handleCallback, params)
			
		elseif attachImage == true then

		local mime = require "mime";
		--GC.IMAGE_FILENAME = "globalIdGuid=469"..GC.IMAGE_FILENAME
		--GC.IMAGE_FILENAME = "sid=1385image.png"
		print("	******** GC.IMAGE_FILENAME = "..tostring(GC.IMAGE_FILENAME))
		local filename = GC.IMAGE_FILENAME
		--local filename = GC.globalGUID.."&"..GC.IMAGE_FILENAME
		local path = system.pathForFile( filename, system.DocumentsDirectory );
		
		-- Open
		local fileHandle = io.open( path, "rb" );
	
		-- If we have a path to the file, upload file

		local function handleCallback1(event)
		
			if ( event.isError ) then
				print( "Network error!" )
			else
				print ( "RESPONSE: " .. event.response )
			end
		end
		
		if fileHandle then
		fileHandlepost = 1
			local function networkListener( event )
			
				if ( event.isError ) then
					print( "Network error!" )
				else
					print ( "Upload complete!" )
					fileHandlepost = fileHandlepost+1
					stopTimeout()
					if (pd) then
						pd:dismiss()
						pd = nil
					end
					if fileHandlepost == 2 then 
					alert:show({
						message = SceneManager.getRosettaString("upload_successful"),
						buttons={SceneManager.getRosettaString("ok")}
					})
					else
					end
				end
			end
			
			print("	GBT CALLING FILEHANDLE HERE")
			-- Encode the file
			
			local fileEncoded = mime.b64( fileHandle:read( "*a" ));
			
			--------------------------
			--GBT specific commands--
			--------------------------
			local headers = {}

			headers["Content-Type"] = "application/x-www-form-urlencoded"
			headers["Accept-Language"] = "en-US"
			local params = {}
			params.headers = headers
			-----------------------------
			--END GBT specific commands--
			print("URL = "..tostring(url))
			-----------------------------
			
			-- Params (file, filename, progress and time out)
			local params = {};
			print("	filename = "..tostring(filename))
			params.body = "fileBinary=" .. fileEncoded .. "&fileName="..filename;
			--params.body = "fileBinary=" .. fileEncoded .. "&sid="..GC.globalSID.."&loadIdGuid="..GC.globalGUID.."&fileName="..filename;
			params.progress = "upload";
			params.timeout = uploadTimeout;
			
			-- Get the file size for progress bar
			fileSize = string.len(fileEncoded);
			
			-- Set up the progress bar
			
			local BASE_URL_TEST = "http://moonbeam.co/processupload.aspx"	
			
			-- Clean up
			io.close( fileHandle );
			print("	GBT CALLING PRE-POST HERE")
			-- Make the POST
			network.request( BASE_URL_TEST, "POST", networkListener,  params);
			--network.request( POST_URL, "POST", handleCallback, params) -- GBT post method
			print("	GBT CALLING POST-POST HERE")
		end
			--end
			
		end
	end
end

function login(params)
	setCallback(params.callback)
	local queryString = nil
	-- TODO: This should be some kind of global
	-- Look for apiTimeout and showPD=false in other files (shipments, quotes, etc...)
	if (params.showPD ~= nil) then
		showPD = params.showPD
	end
	--isTesting = "login"

	if (params.sid) then
		queryString = "sid="..params.sid
	else
		queryString = "id="..url.escape(params.id).."&pw="..url.escape(params.password)
	end
	sendNetworkRequest("login?"..queryString)
end

function checkSessionId(params)
	setCallback(params.callback)

	if (params.showPD ~= nil) then
		showPD = params.showPD
	end

	SceneManager.setLastSessionCheck(os.time())
	isTesting = "checkSessionId"
	sendNetworkRequest("jsessionidcheck?jsessionid="..params.sessionId)
end

function getCompanyAddress(params)
	setCallback(params.callback)
	--isTesting = "getCompanyAddress"
	sendNetworkRequest("getCompanyAddress?sid="..params.sid)
end

function getMyShipments(params)
	setCallback(params.callback)
	--isTesting = "getMyShipments"
	sendNetworkRequest("getMyShipments?sid="..params.sid.."&t="..params.type)
end

-- Reference: https://www.gbthq.com:9443/driver/loadManager​
function getDriverLoads(params)
	setCallback(params.callback)
	--isTesting = "getDriverLoads"
	sendNetworkRequest("getDriverLoads?sid="..params.sid)
end

function getShipmentDetails(params)
	setCallback(params.callback)
	--isTesting = "getShipmentDetails"
	-- TODO: The below URL needs to become an API call.
	--sendNetworkRequest("loadDetailsPrint?loadIdGuid=304")
	sendNetworkRequest("getShipmentDetails?sid="..params.sid.."&id="..params.id)
end

function addEditShipment(params)
	setCallback(params.callback)
	--isTesting = "addEditShipment"
	local loadIdGuid = params.loadIdGuid or ""
	if (params.shipment.stopDate ~= params.shipment.endDate) then
		params.shipment.endDate = params.shipment.stopDate
	end
	sendNetworkRequest("sid="..params.sid.."&loadIdGuid="..params.loadIdGuid.."&shipment="..json.encode(params.shipment),"addEditShipment")
end

function removeShipment(params)
	setCallback(params.callback)
	isTesting = "remove"
	sendNetworkRequest("removeShipment?sid="..params.sid.."&id="..params.id)
end

function getLocations(params)
	setCallback(params.callback)
	--isTesting = "getLocations"
	sendNetworkRequest("getLocations?sid="..params.sid)
end

function getCitiesByState(params)
	setCallback(params.callback)
	--isTesting = "getCitiesByState"
	sendNetworkRequest("getCitiesByState?sid="..params.sid.."&state="..params.state)
end

function getDriverLocations(params)
	setCallback(params.callback)
	--isTesting = "get_locations"
	sendNetworkRequest("getDriverLocations?sid="..params.sid)
end

function requestAccessorials(params)
	setCallback(params.callback)
	isTesting = "requestAccessorials"
	sendNetworkRequest(utils.tableToQueryString(params.form,"requestAccessorials"))
end

function getMyTrailers(params)
	-- NOTE widthUom and lengthUom have been added (Unit of measure). For now in and ft
	setCallback(params.callback)
	isTesting = "getMyTrailers"
	sendNetworkRequest("getMyTrailers?sid="..params.sid)
end

function addEditTrailer(params)
	setCallback(params.callback)
	--isTesting = "addEditTrailer"

	if (tonumber(params.trailer.width) == nil) then 
		params.trailer.width = params.trailer.widthOther
		params.trailer.widthOther = nil
	end
	if (tonumber(params.trailer.length) == nil) then
		params.trailer.length = params.trailer.lengthOther
		params.trailer.lengthOther = nil
	end
	sendNetworkRequest("addEditTrailer?sid="..params.sid.."&"..utils.tableToQueryString(params.trailer))
end

function removeTrailer(params)
	setCallback(params.callback)
	--isTesting = "remove_trailer"
	sendNetworkRequest("removeTrailer?sid="..params.sid.."&trailerId="..params.id)
end

-- Post calls
-- NOTE: They are working on a different version, so coming back later
function getShipmentServices(params)
	setCallback(params.callback)
	isTesting = "shipmentServices"
	sendNetworkRequest("getShipmentServices?sid="..params.sid.."&id="..params.id)
end

function getShipmentTrailers(params)
	setCallback(params.callback)
	--isTesting = "shipmentTrailers"
	sendNetworkRequest("getShipmentTrailers?sid="..params.sid.."&id="..params.id)
end

function getShipmentEscrowOptions(params)
	setCallback(params.callback)
	isTesting = "escrowOptions"
	sendNetworkRequest("getShipmentEscrowOptions?sid="..params.sid.."&id="..params.id)
end

function getFeedbackDetails(params)
	setCallback(params.callback)
	--isTesting = "getFeedbackDetails"
	sendNetworkRequest("getFeedbackDetails?sid="..params.sid)
end

function postFeedback(params)
	setCallback(params.callback)
	--isTesting = "postFeedback"
	sendNetworkRequest("postFeedback?sid="..params.sid.."&id="..params.id.."&question1Status="..params.status1.."&question2Status="..params.status2.."&question3Status="..params.status3)
end

function getBankingDetails(params)
	setCallback(params.callback)
	--isTesting = "getBankingDetails"
	sendNetworkRequest("getBankingDetails?sid="..params.sid)
end

function getMyQuotes(params)
	setCallback(params.callback)
	--isTesting = "getMyQuotes"
	local queryString = "sid="..params.sid
	if (params.type ~= nil) then
		queryString = queryString.."&s="..params.type
	end
	sendNetworkRequest("getMyQuotes?"..queryString)
end

function getLoadQuotes(params)
	setCallback(params.callback)
	isTesting = "getLoadQuotes"
	sendNetworkRequest("getLoadQuotes?sid="..params.sid.."&loadIdGuid="..params.id)
end

-- Ex: Carrier doing a re-quote (newQuote)
function submitQuote(params)
	setCallback(params.callback)
	isTesting = "submitQuote"
	params.type = params.type or "newQuote" -- More types to follow later
	sendNetworkRequest("submitQuote?sid="..params.sid.."&id="..params.id.."&type="..params.type.."&amount="..params.amount)
end

function acceptQuote(params)
	setCallback(params.callback)
	isTesting = "acceptQuote"
	sendNetworkRequest("acceptQuote?sid="..params.sid.."&id="..params.id.."&quoteId="..params.quoteId)
end

function getPaymentOptions(params)
	setCallback(params.callback)
	isTesting = "getPaymentOptions"
	sendNetworkRequest("getPaymentOptions?sid="..params.sid)
end

function fundLoad(params)
	setCallback(params.callback)
	isTesting = "fundLoad"
	sendNetworkRequest("fundLoad?sid="..params.sid.."&id="..params.id.."&amount="..params.amount.."&gbtBalance="..params.gbtBalance.."&paymentId="..params.paymentId.."&paymentId2="..params.paymentId2)
end

function outstandingCharges(params)
	setCallback(params.callback)
	isTesting = "outstandingCharges"
	sendNetworkRequest("outstandingCharges?sid="..params.sid.."&id="..params.id.."&quoteAmount="..params.quoteAmount)
end

function counterQuote(params)
	setCallback(params.callback)
	isTesting = "counterQuote"
	sendNetworkRequest("counterQuote?sid="..params.sid.."&loadIdGuid="..params.id.."&quoteId="..params.quoteId.."&amount="..params.amount.."&fee="..params.fee.."&pay="..params.pay)
end

function declineQuote(params)
	setCallback(params.callback)
	isTesting = "declineQuote"
	sendNetworkRequest("declineQuote?sid="..params.sid.."&quoteId="..params.quoteId.."&type="..params.type)
end

function removeQuote(params)
	setCallback(params.callback)
	isTesting = "removeQuote"
	sendNetworkRequest("removeQuote?sid="..params.sid.."&id="..params.id)
end

function sendDriverApp(params)
	setCallback(params.callback)
	--isTesting = "send_app"
	sendNetworkRequest("sendDriverApp?sid="..params.sid)
end

function referColleague(params)
	setCallback(params.callback)
	--isTesting = "referColleague"
	local customerName = ""
	if (params.customerName ~= nil) then
		customerName = params.customerName
	end

	--local page = SceneManager.getFullWebview("colleagueReferral",nil,true)
	--print ("page: "..page)
	--print ("params: &customerName="..url.escape(customerName).."&customerEmail="..params.customerEmail.."&emailCount="..params.emailCount.."&customerType="..params.customerType)
	sendNetworkRequest("sid="..params.sid.."&customerName="..url.escape(customerName).."&customerEmail="..params.customerEmail.."&emailCount="..params.emailCount.."&customerType="..params.customerType,"referColleague")
end

-- Reference: https://www.gbthq.com:9443/carrier/search
function findFreight(params,callback)
	setCallback(callback)
	--isTesting = "findFreight"
	sendNetworkRequest("findFreight?"..utils.tableToQueryString(params))
	--sendNetworkRequest("findFreight?destinationCity=&destinationState=0&originCity=Springfield&originRadius=0&originState=MO&trailerId=55&weight=99999&destinationRadius=0&length=53&width=96&sid=1330")
end

-- Reference: https://www.gbthq.com:9443/carrier/search (View Shipper's Profile)
-- Incomplete change to PRE-REGISTRATION
function getShipperInfo(params)
	setCallback(params.callback)
	--isTesting = "getShipperInfo"
	sendNetworkRequest("getShipperInfo?sid="..params.sid.."&shipperId="..params.shipperId)
end

function sendClaimPhoto(params)
	setCallback(params.callback)
	--isTesting = "sendClaimPhoto"
	attachImage = true
	print(" sendNetworkRequest call")
	print("---------------------------------------------------")
	print("params.sid = "..tostring(params.sid))
	print("params.loadIdGuid = "..tostring(params.loadIdGuid))
	print("GC.IMAGE_TYPE_CLAIM_PHOTO = "..tostring(GC.IMAGE_TYPE_CLAIM_PHOTO))
	print("---------------------------------------------------")
	sendNetworkRequest("sid="..params.sid.."&loadIdGuid="..params.loadIdGuid.."&t="..GC.IMAGE_TYPE_CLAIM_PHOTO,"sendImage")
	print(" sendNetworkRequest finish")
end

function sendPod(params)
	setCallback(params.callback)
	--isTesting = "sendPod"
	attachImage = true
	sendNetworkRequest("sid="..params.sid.."&id="..params.loadIdGuid,"sendPod")
end

function getDetailsForPOD(params)
	setCallback(params.callback)
	--isTesting = "getDetailsForPOD"
	--params.sid = 1405
	--params.loadIdGuid = 414
	--params.addressGuid = 183
	sendNetworkRequest("getDetailsForPOD?sid="..params.sid.."&id="..params.loadIdGuid.."&aid="..params.addressGuid)
end

-- New API calls for push notification management (MLH)
function getNotificationsByUser(params)
	setCallback(params.callback)
	--isTesting = "getNotificationsByUser" -- unremark for testing

	sendNetworkRequest("getNotificationsByUser?sid="..params.sid)
end

function markNotificationAsRead(params)
	setCallback(params.callback)
	--isTesting = "markNotifcationAsRead" -- unremark for testing

	sendNetworkRequest("markNotificationAsRead?sid="..params.sid.."&notificationId="..params.notificationId)
end

function deleteNotification(params)
	setCallback(params.callback)
	--isTesting = "deleteNotification" -- unremark for testing

	sendNetworkRequest("deleteNotification?sid="..params.sid.."&notificationId="..params.notificationId)
end

function sendErrorEmail(params)
	resetCallback()
	--isTesting = "sendErrorEmail"
	trapError = false -- Don't want recursion
	-- sid [optional]
	-- recoverable (boolean) [required]
	-- subject [optional] Note: "GBT Mobile Error - " pre-pended before sending email
	-- body [required]
	local sid = SceneManager.getUserSID() or ""
	local recoverable = true
	if (params.recoverable ~= nil) then
		recoverable = params.recoverable
	end

	local networkRequest = ""

	-- Let's not only obscure things, but save us 9 characters, since this is a GET request
	local body = string.gsub( params.body or "", ".lua:", ":")
	body = utils.urlencode(string.gsub(body,"/GBT/",""))
	networkRequest = "sendErrorEmail?sid="..sid.."&recoverable="..tostring(recoverable).."&subject="..utils.urlencode(params.subject or "").."&body="
	
	local presentCallLength = string.len(BASE_URL..networkRequest.."&api_key="..(GC.API_KEY or ""))
	local clipLength = (255 - (presentCallLength + string.len(body)))

	if (clipLength < 0) then
		body = string.sub( body, 1, string.len(body) + clipLength )
	end

	networkRequest = networkRequest..body

	--sendNetworkRequest("sid="..sid.."&recoverable="..tostring(recoverable).."&subject="..url.escape(params.subject or "").."&body="..url.escape(params.body or ""),"sendErrorEmail")
	sendNetworkRequest(networkRequest)
end

function sendAPIError(params)
	-- Builds out for above based on a specific API call error sent

	local subject = "api error"
	local sid = SceneManager.getUserSID() or "n/a"
	local scene = params.scene or "n/a"
	local apiCall = lastAPICall or "n/a"
	local reason = params.reason or "n/a"
	local recoverable = true
	if (params.recoverable == false) then
		recoverable = false
	end

	local body = "Scene: "..scene.."<br/>SID: "..sid.."<br/>API: "..apiCall.."<br/>err: "..reason

	sendErrorEmail({subject=subject,body=body,recoverable=recoverable})
end
