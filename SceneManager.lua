module(..., package.seeall)
local composer = require("composer")
local GC = require("AppConstants")
local GGData = require("ggdata")
local rosetta = require("rosetta").new()
local db = require("db")
local zip = require("plugin.zip")
local fileio = require("fileio")
local utils = require("utils")

local SETTINGS_NRUNS_KEY = "nRuns"
local SETTINGS_AUTOMATIC_LOGIN_KEY = "automaticLogin"
local SETTINGS_USER_ID_KEY = "userID"
local SETTINGS_USER_PHONE_KEY = "userPhone"
local SETTINGS_USER_PASS_KEY = "colors"
local SETTINGS_USER_SID_KEY = "userSID"
local SETTINGS_LANGUAGE_KEY = "language"
local SETTINGS_REFERRAL_KEY = "referralCode"
local SETTINGS_LOCATION_KEY = "location"
local SETTINGS_SESSION_ID_KEY = "jsessionid"
local SETTINGS_LAST_LOGIN_KEY = "lastLogin"
local SETTINGS_LAST_SESSION_CHECK_KEY = "sessionCheck"

SETTINGS_NOTIFICATION_HAS_REGISTERED = "hasRegistered"
SETTINGS_NOTIFICATION_DEVICE_TOKEN = "deviceToken"

local settings = nil

local nRuns = 0
local appLoad = nil
local automaticLogin = nil

local location = nil
-- Same as masterRole in API
local userRole = nil
-- shipper, carrier, driver
local userRoleType = nil
local userSID = nil
local referralCode = nil
local requestAccessorial = nil
local userFirstname = "Driver"
local userLastname = "Mobile"

--local WEB_BASE_URL = "https://www.gbthq.com:8443"
local WEB_BASE_URL = GC.MAIN_URL

local SESSION_TIMEOUT_MS = 6 * 60 * 1000 -- 6 Minutes
local sessionTimer

local sessionId

function getLastSessionCheck()
	return getSetting(SETTINGS_LAST_SESSION_CHECK_KEY,0)
end

function setLastSessionCheck(timeStamp)
	setSetting(SETTINGS_LAST_SESSION_CHECK_KEY,timeStamp)
end

function setLastLogin(timeStamp)
	Log("timeStamp: "..timeStamp)
	setSetting(SETTINGS_LAST_LOGIN_KEY,timeStamp)
end

function getLastLogin()
	return getSetting(SETTINGS_LAST_LOGIN_KEY,0)
end

function getSessionId()
	return sessionId
end

-- This should be saved to the device because SID only logins don't have it returned
function setSessionId(id)
	Log("setSessionId: "..tostring(id))
	sessionId = id
	setSetting(SETTINGS_SESSION_ID_KEY,id)
end

function readSessionId()
	sessionId = getSetting(SETTINGS_SESSION_ID_KEY,nil)
	Log("readSessionId: "..tostring(sessionId))
	return sessionId
end

function resetSession()
	sessionId = nil
end

local function hasSessionId()
	return sessionId ~= nil
end

local function onAlertComplete(event)
	goToLoginScene()
end

local function sessionTimedOut()
	resetSession()

	-- TODO: Show alert, callback returns user to the login scene.
	native.showAlert(getRosettaString("timed_out"), getRosettaString("timed_out_msg"),{getRosettaString("OK")},onAlertComplete)
end

local function stopSessionTimer()
	if (sessionTimer) then
		timer.cancel( sessionTimer )
		sessionTimer = nil
	end
end

-- TODO: Need to change this, so it just does an api call here to validate the current sessionId
-- "https://www.gbthq.com:8443/mobile/jsessionidcheck?jsessionid="..sessionId
-- returns validsession="true"
local function startSessionTimer()
	--stopSessionTimer()

	--sessionTimer = timer.performWithDelay(SESSION_TIMEOUT_MS, sessionTimedOut)
end

function getPageSessionDetails()
	return "webview=true&jsessionid="..getSessionId()
end

function getBaseWebUrl(hideRole)
	local url = WEB_BASE_URL.."/"

	if (hideRole ~= true) then
		url = url..getUserRoleType().."/"
	end

	return url
end

function getMobileAPIUrl(command)
	return WEB_BASE_URL.."/mobile/"..command.."?"..getPageSessionDetails()
end

function getFullWebview(page,params,hideRole)
	--/carrier/test?jsessionid=E9521BB32D4FEBE7C50472927B37D9CC&webview=true
	local qString = utils.tableToQueryString(params)
	if (qString) then
		qString = "&"..qString
	else
		qString = ""
	end

	local url = getBaseWebUrl(hideRole)

	return (url..page.."?"..getPageSessionDetails()..qString)
end

local function zipListener( event )
   if ( event.isError ) then 
      print( "Unzip error" )
   else
      --print( "event.name:" .. event.name )
      --print( "event.type:" .. event.type )
      if ( event.response and type(event.response) == "table" ) then
         for i = 1, #event.response do
            --print( event.response[i] )
         end
      end    
   end
end

local function installFramework()
	if (not fileio.fileExists("framework.txt")) then
		local options = {
	        zipFile = "framework.zip",
	        zipBaseDir = system.ResourceDirectory,
	        dstBaseDir = system.DocumentsDirectory,
	        listener = zipListener,
		}

		zip.uncompress( options )
	end
end

function isAndroid()
	return "Android" == system.getInfo("platformName")
end

function isIphone5()
	return (1136 == display.pixelHeight)
end

function getSetting(key,default)
	local setting = settings:get(key)

	if setting == nil then
		setSetting(key,default)
		setting = default
	end

	return setting
end

function setSetting(key,value)
	settings:set(key,value)
	settings:save()
end

function handleUserLogin()
	startSessionTimer()
end

function hasAutomaticLogin()
	return automaticLogin
end

function setAutomaticLogin(state)
	automaticLogin = state
	setSetting(SETTINGS_AUTOMATIC_LOGIN_KEY,state)
end

function getLocationState()
	return location
end

function setLocationState(state)
	location = state
	setSetting(SETTINGS_LOCATION_KEY,state)
end

function toggleLocationState()
	location = not location
	setLocationState(location)
end

function setUserFirstname(first)
	userFirstname = first
end

function getUserFirstname()
	return userFirstname
end

function setUserLastname(last)
	userLastname = last
end

function getUserFullname()
	return userFirstname.." "..userLastname
end

function getUserLastname()
	return userLastname
end

function getUserRole()
	return userRole
end

function setUserRole(role)
	userRole = role
end

function getUserRoleType()
	return userRoleType
end

function setUserRoleType(roleType)
	userRoleType = roleType
end

function getUserID()
	-- TODO: Need to decrypt this value
	return getSetting(SETTINGS_USER_ID_KEY,"")
end

function setUserID(id)
	-- TODO: Need to encrypt this value
	setSetting(SETTINGS_USER_ID_KEY,id)
end

function getUserPhoneID()
	-- TODO: Need to decrypt this value
	return getSetting(SETTINGS_USER_PHONE_KEY,"")
end

function setUserPhoneID(id)
	-- TODO: Need to encrypt this value
	setSetting(SETTINGS_USER_PHONE_KEY,id)
end

function setUserTag(id)
	_G.setTag(id)
end

function getUserPass()
	return getSetting(SETTINGS_USER_PASS_KEY,"")
end

function setUserPass(pass)
	setSetting(SETTINGS_USER_PASS_KEY,pass)
end

function setUserSID(sid)
	userSID = sid
	setSetting(SETTINGS_USER_SID_KEY,sid)
end

function getUserSID()
	return userSID
end

function setReferralCode(code)
	referralCode = code
	setSetting(SETTINGS_REFERRAL_KEY,referralCode)
end

function getReferralCode()
	return referralCode--"S36616FCD"
end

function setAccessorialState(state)
	requestAccessorial = state
end

function getRequestAccessorial()
	return requestAccessorial
end

function isAppLoad()
	return appLoad
end

function setAppLoad(state)
	appLoad = state
end

function getNRuns()
	return nRuns
end

function showDebugMessage(message)
	native.showAlert( "Information", message, { "OK" })
end

function loadUpgradeKey()
	local upgradeState = getSetting(GC.SETTINGS_HASUPGRADE)
	if upgradeState ~= nil then
		setUpgrade(upgradeState)
	else
		setUpgrade(hasUpgrade)
	end
	hasUpgrade = false
end

function getRosettaString(key,case)
	local str = rosetta:getString(key)
	
	if (case == 0) then
		str = string.lower( str )
	elseif (case == 1) then
		str = string.upper( str )
	end 

	return str
end

function rateApp()
	local options = {
		iOSAppId = GC.APP_ID,
		nookAppEAN = GC.NOOK_APP_EAN,
		supportedAndroidStores = GC.SUPPORTED_STORES
	}

	native.showPopup("rateApp", options )
end

function init()
	rosetta:initiate()
	-- set current language for the app
	-- "en" default as defined in language.txt
	--if (system.getPreference("ui", "language") == "ar") then
	--	rosetta:setCurrentLanguage("ar") -- Use "ar" for Arabic
	--end
	
	installFramework()

	-- TODO: Finish database for app
	db.init()

	--db.insertMessage(1330,385,"quote","Your quote was countered")
	--local results = db.getMessages(1330,"quote")

	appLoad = true

	settings = GGData:new("settings")

	rosetta:setCurrentLanguage(getSetting(SETTINGS_LANGUAGE_KEY,"en"))
	
	automaticLogin = getSetting(SETTINGS_AUTOMATIC_LOGIN_KEY,false)
	userSID = getSetting(SETTINGS_USER_SID_KEY,"")
	
	location = getSetting(SETTINGS_LOCATION_KEY,false)
	
	--hasSound = getSetting("hasSound",true)
	--hasMusic = getSetting("hasMusic",true)
	
	nRuns = getSetting(SETTINGS_NRUNS_KEY, 0)

	nRuns = nRuns + 1
	setSetting(SETTINGS_NRUNS_KEY,nRuns)

	
end

local function go(scene,params)
	composer.gotoScene(scene,{effect=GC.SCENE_TRANSITION_TYPE,time=GC.SCENE_TRANSITION_TIME_MS,params=params})
end

function goTo(scene,params,isOverlay,onComplete)
	local payload = {}
	payload.scene = scene
	payload.extra = params
	payload.isOverlay = isOverlay or false
	payload.onComplete = onComplete

	if (isOverlay == true) then
		composer.showOverlay("SceneWebview", {effect = GC.OVERLAY_ACTION_SHOW,time=GC.SCENE_TRANSITION_TIME_MS, isModal=true, params = payload})
	else
		composer.gotoScene("SceneWebview",{effect=GC.SCENE_TRANSITION_TYPE,time=GC.SCENE_TRANSITION_TIME_MS,params=payload})
	end
end

local function back(scene)
	composer.gotoScene(scene,"slideRight",GC.SCENE_TRANSITION_TIME_MS)
end

function showOverlay(scene,params)
	composer.showOverlay(scene, {effect = GC.OVERLAY_ACTION_SHOW,time=GC.SCENE_TRANSITION_TIME_MS, isModal=true, params = params})
end

function goToHomeScene()
	composer.gotoScene("SceneChooser")
end

function goToLoginScene()
	composer.gotoScene("SceneLogin")
end

function goToDriverLoginScene()
	composer.gotoScene("SceneDriverLogin")
end

function goToRegistration()
	composer.gotoScene("SceneRegistration")
end

function goToDashboard()
	go("SceneDashboard")
end

function goToSelectShipmentTemplate()
	go("SceneShipmentTemplates")
end

function goToPostShipment(params)
	go("ScenePostShipment",params)
end

function showPackaging(params)
	composer.showOverlay("ScenePackaging", {effect = "zoomOutInFade",time=200, isModal=true, params = params})
end

function showLocation(params)
	composer.showOverlay("SceneLocation", {effect = "zoomOutInFade",time=200, isModal=true, params = params})
end

function showLoadQuotes(params)
	composer.showOverlay("SceneLoadQuotes", {effect="",time=0, isModal = true, params = params})
end

function goToMyFeedback()
	go("SceneMyFeedback")
end

function goToMyShipments()
	go("SceneMyShipments")
end
function goToPODShipments()
	go("ScenePODShipments")
end
function showShipmentDetails(params)
	showOverlay("SceneShipmentDetails",params)
	--go("SceneShipmentDetails")
end

function goToFindFreight()
	-- delete it ourself, so we can easily tweak search criteria after each search
	composer.removeScene("SceneFindFreight")
	go("SceneFindFreight")
end

function goToFindFreightResults(params)
	go ("SceneFindFreightResults",params)
end

function showFindFreightResults(params)
	showOverlay("SceneFindFreightResults",params)
end

function goToMyQuotes()
	go("SceneMyQuotes")
end

function showReQuote(params)
	composer.showOverlay("SceneReQuote", {effect = GC.OVERLAY_ACTION_SHOW,time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function goToMyBanking()
	go("SceneMyBanking")
end

function goToMyTrailers()
	go("SceneMyTrailers")
end

function goToLocateDrivers()
	go("SceneLocateDrivers")
end

function goToMessageCenter()
	go("SceneMessageCenter")
end

function goToLocateShipment()
	go("SceneLocateShipment")
end

function showClaimPhoto(params)
	composer.showOverlay("SceneClaimPhoto", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function showPODPhoto(params)
	go("ScenePODUpload",params)
	--composer.showOverlay("ScenePODUpload", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function showReferGBT()
	composer.showOverlay("SceneReferColleague", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function showMap(params)
	composer.showOverlay("SceneMap", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function goToAddEditTrailer(params)
	composer.showOverlay("SceneAddEditTrailer", {effect = "zoomOutInFade",time=200, isModal=true,params=params})
end

function showRequestAccessorials(params)
	composer.showOverlay("SceneRequestAccessorials", {effect = "zoomOutInFade",time=200, isModal=true,params=params})
end

function showRequestedAccessorials()
	composer.showOverlay("SceneRequestedAccessorials", {effect = GC.OVERLAY_ACTION_SHOW,time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function goToPostFeedback(params)
	composer.showOverlay("ScenePostFeedback", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true,params=params})
end

function showSplash()
	composer.showOverlay("SceneSplash", {effect = "",time=GC.SCENE_TRANSITION_TIME_MS, isModal=true})
end