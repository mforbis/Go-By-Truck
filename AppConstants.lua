module(..., package.seeall)

-------------------------------------------------
---------- MAIN APPLICATION CONFIG --------------
-------------------------------------------------
APP_FONT = "Open Sans Light" --native.systemFontBold
IS_DEV = true
SHOW_SPLASH_MS = 3000

local port = 8443
API_KEY = "m00nBeamSpringfieldMo!"

if (IS_DEV) then
	BASE_URL = "https://www.gbthq.com:"..port.."/mobile/"
	MAIN_URL = "https://www.gbthq.com:"..port
else
	BASE_URL = "https://www.gobytruck.com/mobile/"
	MAIN_URL = "https://www.gobytruck.com"
end
-- iTunes App Id for rating and such
APP_ID ="817786975"
APP_NAME ="Go By Truck"
NOOK_APP_EAN =""
APP_VERSION = "1.0"

-- Colors
DARK_GREEN = {81/255,122/255,1/255}
LIGHT_GREEN = {136/255,187/255,0/255}
DARK_BLUE = {69/255,161/255,189/255}
LIGHT_BLUE = {83/255,185/255,215/255}
LIGHT_GRAY = {245/255,245/255,245/255}
LIGHT_GRAY2 = {230/255,230/255,230/255}
MEDIUM_GRAY = {172/255,172/255,172/255}
MEDIUM_GRAY2 = {163/255,163/255,163/255}
MEDIUM_GRAY3 = {113/255,104/255,102/255}
DARK_GRAY = {68/255,68/255,68/255}--{66/255,66/255,66/255}
DARK_GRAY2 = {0.4,0.4,0.4}
DARK_GRAY3 = {0.3,0.3,0.3}
ORANGE = {239/255,96/255,40/255}--233/255,78/255,27/255--{242/255,139/255,36/255}
ORANGE2 = {192/255,65/255,23/255}
ORANGE_OVER = {189/255,63/255,22/255}
WHITE = {1,1,1}
BLACK = {0,0,0}
RED = {1,0,0}

COLOR_LIGHT_YELLOW = {1,247/255,200/255}
COLOR_DARK_PURPLE = {45/255,31/255,44/255}
COLOR_WHITE = {1,1,1}
COLOR_GRAY = {200/255,200/255,200/255}
COLOR_ORANGE = {242/255,139/255,36/255}
COLOR_RED = {227/255,46/255,43/255}
COLOR_DARK_RED = {128/255,36/255,32/255}
BLUE_OVER = {0,140/255,163/255}
COLOR_YELLOW_GREEN = {199/255,217/255,43/255}
COLOR_SKY_BLUE = {31/255,130/255,229/255}


DEFAULT_BG_COLOR = {239/255,239/255,239/255}
DEFAULT_TEXT_COLOR = {.25,.27,.3}

HINT_TEXT_COLOR = {255,255,255}
HINT_FONT_TYPE = APP_FONT
HINT_FONT_SIZE = 18

INPUT_FIELD_BG_COLOR = {1,1,1}
INPUT_FIELD_BORDER_COLOR = {.5,.5,.5}
INPUT_FIELD_BORDER_WIDTH = 1
INPUT_FIELD_TEXT_SIZE = 20
INPUT_FIELD_TEXT_COLOR = {0,0,0}

-- Header/Dashboard
HEADER_HEIGHT = 50
HEADER_COLOR = DARK_GRAY--{42/255,47/255,52/255}
HEADER_LOGO_WIDTH = 130
HEADER_LOGO_HEIGHT = 27
HEADER_BUTTON_SIZE = 35
DASHBOARD_BAR_HEIGHT = 50
DASHBOARD_TOP_COLOR = {90/255,100/255,110/255}
DASHBOARD_BOTTOM_COLOR = {42/255,47/255,52/255}
DASHBOARD_BAR_BUTTON_WIDTH = 40
DASHBOARD_BAR_BUTTON_HEIGHT = 40
DASHBOARD_BAR_BUTTON_DEFAULT_COLOR = {1,1,1,0.001}
DASHBOARD_BAR_BUTTON_OVER_COLOR = {1,1,1,.001}
DASHBOARD_BAR_BUTTON_ICON_SIZE = 24
DASHBOARD_BAR_BUTTON_PADDING = 4

TITLE_BG_HEIGHT = 45
TITLE_BG_COLOR = HEADER_COLOR
SCREEN_TITLE_FONT = APP_FONT
SCREEN_TITLE_COLOR = {1,1,1}
SCREEN_TITLE_SIZE = 21

-- setting global constats to be set in sceneClaimPhoto, which will then be called by the multipart form.
globalSID = 0
globalGUID = 469
GOT_LIST = false
LISTWIDGET_HOLDER = 0
LISTMENU_HOLDER = 0
TOOLS_OVERLAY = false
BACKPRESS = false


--IMAGE_FILENAME = "globalIdGuid=469image.png"
--IMAGE_FILENAME = "globalIdGuid=123image.png"
IMAGE_FILENAME = "image.png"
--testLine = globalGUID.."image.png"
--IMAGE_FILENAME = "globalIdGuid="..testLine
--IMAGE_FILENAME = tostring(IMAGE_FILENAME)
PODFORM_FILENAME = "podForm.html"
DETAILS_FILENAME = "details.html"
LOCATION_FILENAME = "location.html"

-- NOTE: change for each store. Corona gets confused on which, so use only 1
-- possible values (amazon, google, nook, samsung)
SUPPORTED_STORES = {"google"}

MAIN_SCREEN_WIDTH = 320
MAIN_SCREEN_HEIGHT = 480

SCENE_TRANSITION_TYPE = "fade"
SCENE_TRANSITION_TIME_MS = 250

OVERLAY_ACTION_SHOW = "fade"--"slideUp"
OVERLAY_ACTION_DISMISS = "fade"--"slideDown"

if (display.contentHeight > display.contentWidth) then
	BACKGROUND_SIZE = display.contentHeight
else
	BACKGROUND_SIZE = display.contentWidth
end

API_ERROR = -1

USER_ROLE_TYPE_CARRIER = "carrier"
USER_ROLE_TYPE_DRIVER = "driver"
USER_ROLE_TYPE_SHIPPER = "shipper"

DRIVER_LOCATION = 0
SHOW_DIRECTIONS = 1
SHIPMENT_LOCATION = 2

-- API defines
API_USER_APPROVED = 18

API_ROLE_MASTER_CARRIER_ADMIN = 3
API_ROLE_CARRIER_ADMIN = 4
API_ROLE_DISPATCH = 12 -- Type of Carrier
API_ROLE_DRIVER = 6
API_ROLE_MASTER_SHIPPER_ADMIN = 9
API_ROLE_SHIPPER_ADMIN = 10
API_ROLE_CLERK = 11 -- Type of Shipper
API_ROLE_SHIPPER_ACCOUNTING = 23

-- Image Types
IMAGE_TYPE_CLAIM_PHOTO = 219

-- Load Types
TRUCKLOAD = 8
LESS_THAN_TRUCKLOAD = 9
OVER_DIMENSIONAL = 94

LOCATION_TYPE_PICKUP = 11
LOCATION_TYPE_DROPOFF = 12

ESCROW_TYPE_FAST = "fastSelected"
ESCROW_TYPE_MANUAL = "manualSelected"

-- Shipping
-- Points to proper table based on user role
SHIPPER_SHIPMENT_TYPES = {"actionItems","posted","matched","incomplete","cancelled","released","arbitration"}
CARRIER_SHIPMENT_TYPES = {"matched","released","arbitration","cancelled"}

STATUS_REQUESTED = 45

SHIPMENT_STATUS_CREATED = 16
SHIPMENT_STATUS_MATCHED = 26
SHIPMENT_STATUS_POSTED = 34
SHIPMENT_STATUS_RELEASED = 41

MESSAGE_TYPE_ACCESSORIAL = "accessorial"
MESSAGE_TYPE_FEEDBACK = "feedback"
MESSAGE_TYPE_BANKING = "banking"
MESSAGE_TYPE_SHIPMENT = "shipment"
MESSAGE_TYPE_QUOTE = "quote"
MESSAGE_TYPE_UNREAD = 0

EQUIPMENT_OPTIONS = {"binders","blankets","boomers","chains","coilRacks","cradles",
"dunnage","levelers","liftGate","loadBars","lumber","padding","palletJack","ramps",
"pipeStakes","straps","pallets","sideKit","ventedVan","sealLockForSecurement"}

PACKAGING_OPTIONS = {"Bags","Bales","Boxes","Bundles","Carpets","Coils","Crates", "Cylinders",
"Drums","Pails","Pallets 48x40","Pallets 48x48","Pallets 60x40","Pieces","Reels","Rolls","Totes",
"Tubes or Pipes"}

REQUIREMENTS_OPTIONS = {"hardhat","longSleeves","noPassengers","tolls","lumpers",
"layover","safetyGlasses","driverAssist","steelToedBoots","storage","fuelSurcharge",
"noPets","airRide","swingDoors","tradeShow","scale"}

QUOTE_TYPES = {"actionItems","quoted","countered","lost_quote","denied"}
QUOTE_LABELS = {"actionItems","quoting","countered","lost_quote","denied"}

QOUTE_TYPE_DENIED = 17
QUOTE_TYPE_APPROVED = 18
QUOTE_TYPE_QUOTED = 24
QUOTE_TYPE_LOST_QUOTE = 28
QUOTE_TYPE_CANCELLED = 29
QUOTE_TYPE_COUNTERED = 30
QUOTE_TYPE_PENDING_APPROVED = 31
QUOTE_TYPE_PENDING_DECLINED = 32
QUOTE_TYPE_SHIPPER_COUNTER = 42
QUOTE_TYPE_CARRIER_COUNTER = 43
QUOTE_TYPE_COUNTER_DENIED = 44

QUOTE_DEFINITIONS = {
	{status=24,label="quoted"},
	{status=30,label="countered"},
	{status=17,label="denied"},
	{status=28,label="lost_quote"}
}

ACCESSORIALS = {
   {id="bridges_tolls",label="Bridges / Tolls",qLabel="bridgesTolls",help="Compensation to the Driver for toll and bridge charges they may incur in transit.\nIndustry Standard Rate: $100-$300"},
   {id="detention",label="Detention",help="A shipper or receiver delay in loading/unloading a truck. (Only applicable when the shipper/receiver are at fault for the delay (not when a carrier is late).\n* Industry Standard Rate: $45 - $550 (Applies To LTL When Over 45 Min & TL When Over 2 Hrs.)"},
   {id="excess_mileage",qLabel="excessMileage",label="Excess Mileage",help="If a shipment requires the driver to incur more mileage than the original shipment detailed.\n* Industry Standard Rate: $1.55 per mile."},
   {id="haz_mat",qLabel="hazmat",label="HAZ MAT",help="A shipment that is flammable, poisonous, radioactive, or explosive and could be a danger or threat to the environment if released.\nIndustry Standard Rate: $50 for Less Than Truckload and $100 for Truckload"},
   {id="inside_pickup_delivery",qLabel="insidePickupDelivery",label="Inside Pick Up / Delivery",help="If the driver is required to go inside (beyond the front door or loading dock), to pick up or deliver a shipment.\n* Industry Standard Rate: $100 (+ $40 For Stairs)"},
   {id="lay_over",qLabel="layOver",label="Lay Over",help="Anytime a Driver unexpectedly waits for a Shipper's FULL TRUCKLOAD shipment to be ready to load/unload.\nIndustry Standard Rate: $350 min /  $500 max"},
   {id="lift_gate",qLabel="liftGate",label="Lift Gate",help="Assists a Driver when the shipping or receiving address does not have a loading dock.\nIndustry Standard Rate: $145"},
   {id="driver_assist_tail_gate",qLabel="driverAssistTailgate",label="Driver Assist or Tail Gate",help="Driver Assist = Driver must help load/unload freight.\nTail Gate = Freight transferred form the nose to the tail of the trailer.\nIndustry Standard Rate: $75 first hour, $50 each additional hour"},
   {id="misrepresented_shipment",qLabel="misrepresented",label="Misrepresented Shipment",help="Any commodity that is misrepresented upon listing causing the carrier to agree to a lower price for transport.\n* Industry Standard Rate: At Carrier's Discretion"},
   {id="new_york_pickup_delivery",qLabel="newYorkPickupDelivery",label="New York City / Long Island NY -",label2="Pick Up / Delivery",help="Surcharge for shipments in and around New York City or Long Island for congestion, tolls and bridges.\n* Industry Standard Rate: $100"},
   {id="reconsignment",label="Reconsignment",help="If the pick-up/delivery location is changed while the driver is in route. \n* Industry Standard Rate: $50 Min / $150 Max"},
   {id="redelivery",label="Redelivery",help="When a shipment has to be re-delivered to a location.\n* Industry Standard Rate: $100"},
   {id="residential_trade_show",qLabel="residentialTradeShow",label="Residential / Trade Show /",label2="Convention",help="A pick up or delivery made at a residential, trade show or convention location.\n* Industry Standard Rate: $100"},
   {id="scale_tickets",qLabel="scaleTickets",label="Scale Tickets (Empty/Loaded)",help="When the Driver is required to provide an empty or loaded scale ticket to the Shipper to verify the weight loaded on a trailer.\nIndustry Standard Rate: $75 each"},
   {id="stop_off",qLabel="stopOff",label="Stop Off",help="Stops in route for FULL TRUCKLOADS for additional loading or unloading.\nIndustry Standard Rate: $50 per stop off"},
   {id="storage",label="Storage",help="When storage of your cargo will be required at any point during delivery.\nIndustry Standard Rate: $120 per day"},
   {id="tarp",label="Tarp",help="When a shipment requires full/partial tarp coverage.\nIndustry Standard Rate: $75"},
   {id="lumper",label="Lumper",help="Third party help for loading/unloading freight.\nIndustry Standard Rate: $75 first hour, $50 each additional hour"},
   {id="other",label="Other",help="Used for any accessorial item not listed. Please enter the amount allotted."}
}

PACKAGING_OPTIONS = {"Bags","Bales","Boxes","Bundles","Carpets","Coils","Crates", "Cylinders",
"Drums","Pails","Pallets 48x40","Pallets 48x48","Pallets 60x40","Pieces","Reels","Rolls","Totes",
"Tubes or Pipes"}

TITLE_FONT = APP_FONT
TITLE_TEXT_COLOR = {5/255,5/255,1}
TITLE_TEXT_COLOR_OVER = {.8,.8,.8}
TITLE_FONT_SIZE = 55

-- Forms
FORM_PADDING_LEFT = 20
FORM_PADDING_TOP = 10
FORM_NEW_LINE_HEIGHT = 10
FORM_PADDING_BETWEEN = 5
FORM_LINE_HEIGHT = 30
FORM_LINE_PADDING = 20
FORM_WORD_PADDING = 10
FORM_CHAR_PADDING = 5
FORM_DIVIDER_COLOR = {0.8,0.8, 0.8}

TRAILER_MISSING_ATTRIBUTE_TEXT = "- - -"

--[[
Note: Some of the below values are only
relevant if you use the older widget
library (widget-v1).
]]--

function isIPad()
	return string.sub(system.getInfo("model"),1,4) =="iPad"
end

BG_TOP_COLOR = COLOR_WHITE
BG_BOTTOM_COLOR = COLOR_WHITE

BUTTON_FONT = APP_FONT
BUTTON_TEXT_COLOR = {1,1,1}
BUTTON_TEXT_COLOR_OVER = {1,1,1}
BUTTON_FONT_SIZE = 25
BUTTON_BACKGROUND_COLOR = {14/255,39/255,65/255}
BUTTON_BORDER_COLOR = {0/255,0/255,0/255}
BUTTON_BACKGROUND_COLOR_OVER = {5/255,116/255,169/255} --{90,147,58}

BUTTON_RADIUS_SIZE = 2
BUTTON_BORDER_WIDTH = 1
BUTTON_ACTION_HEIGHT = 35
-- Some displays buttons are too small. Not 100% yet
if (display.contentHeight > 480 and system.getInfo("platformName") == "Android") then
	BUTTON_ACTION_HEIGHT = 35
end

BUTTON_ACTION_TEXT_COLOR = DARK_GRAY
BUTTON_ACTION_TEXT_COLOR_OVER = WHITE
BUTTON_ACTION_BACKGROUND_COLOR = ORANGE--{1,.6,0}
BUTTON_ACTION_BACKGROUND_COLOR_OVER = ORANGE_OVER --{.96,.45,0}
BUTTON_ACTION_BORDER_COLOR = ORANGE_OVER --{.96,.45,0}
BUTTON_ACTION_BORDER_WIDTH = 0
BUTTON_ACTION_RADIUS_SIZE = 8
ACTION_BUTTON_ICON_SIZE = 15
BUTTON_SETTINGS_TEXT_COLOR = {255,255,255}
BUTTON_SETTINGS_TEXT_COLOR_OVER = {57,107,161}
BUTTON_SETTINGS_FONT_SIZE = 18
BUTTON_SETTINGS_BACKGROUND_COLOR = {57,107,161}
BUTTON_SETTINGS_BACKGROUND_COLOR_OVER = {255,255,255}
BUTTON_SETTINGS_BORDER_COLOR = {.96,.45,0}
BUTTON_SETTINGS_RADIUS_SIZE = 10
BUTTON_SETTINGS_BORDER_WIDTH = 2


TEXT_SETTINGS_RADIUS_SIZE = 8

if (isIPad()) then
	BG_TOP_COLOR = COLOR_WHITE
	BG_BOTTOM_COLOR = COLOR_WHITE

	TITLE_TEXT_COLOR = {106,73,80}
	SUBTITLE_TEXT_COLOR = COLOR_GREEN
end

-- Different formats for platforms
if (system.getInfo("platformName") =="Android") then
	MUSIC_EXT =".ogg"
	
	-- Corona doesn't support retina for Android in the config file, so
	-- we kind of add that ourselves.
	IMAGE_EXT ="@2x"
else
	MUSIC_EXT =".caf"
	IMAGE_EXT =""
end