module(..., package.seeall)

LOCATION_TEMPLATE = [[
<html>
<title>Map</title>
<meta name="viewport" content="initial-scale=1.0, user-scalable=no">
<meta charset="utf-8">
<style>
html, body, #map-canvas {
	margin: 0;
	padding: 0;
	height: 100%;
}
.driverLabel {
	color: white;
	background-color: #3c3c3b;
	font-family: "Lucida Grande", "Arial", sans-serif;
	font-size: 10px;
	text-align: center;
	padding: 5px;
	white-space: nowrap;
}
</style>
<script type="text/javascript" src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"></script>
<script type="text/javascript" src="infobox.js"></script>
<script type="text/javascript" src="markerwithlabel.js"></script>

<script type="text/javascript">
// Version 1.0
var map;
var directionsDisplay;
var directionsService;

var poiLat;
var poiLon;
var centerLat;
var centerLon;
var name;

var USER_LOCATION = 0;
var MARKER_LOCATION = 2;

var TRUCK = "greentruck_v2_32.png";

function buildMarker(info,kind)
{
	var marker;
	var markerClass;
	
	if (kind == MARKER_LOCATION) {
		marker = new MarkerWithLabel ({
			position: new google.maps.LatLng(info.lat, info.lon),
			zIndex: 4,
			map: map,
			icon: new google.maps.MarkerImage(TRUCK, null, null, null, new google.maps.Size(32, 32))
		});
	}
	
	return marker;
}

function updateMarkerLocation()
{
	var marker = {};
	marker.name = name;
	marker.lat = poiLat;
	marker.lon = poiLon;
	markerLocation = buildMarker(marker,MARKER_LOCATION);
	map.setCenter(markerLocation.getPosition());
}

function getQueryVariable(variable)
{
       var query = window.location.search.substring(1);
       var vars = query.split("&");
       for (var i=0;i<vars.length;i++) {
               var pair = vars[i].split("=");
               if(pair[0] == variable){return decodeURIComponent(pair[1]);}
       }
       return(false);
}

function calcRoute(start,end) {
  //var start = document.getElementById('start').value;
  //var end = document.getElementById('end').value;
  var request = {
      origin:start,
      destination:end,
      travelMode: google.maps.TravelMode.DRIVING
  };
  directionsService.route(request, function(response, status) {
    if (status == google.maps.DirectionsStatus.OK) {
      directionsDisplay.setDirections(response);
    }
  });
}

function initialize() {
	var sAddr = "{sAddr}";
	var dAddr = "{dAddr}";
	poiLat = {poiLat};
	poiLon = {poiLon};

	if (poiLat && poiLon) {
		console.log("location");
		centerLat = poiLat;
		centerLon = poiLon;

		//-34.397, 150.644
		if (!poiLat || !poiLon || !centerLat || !centerLon) {
			// Error
		} else {
			var mapOptions = {
		    	zoom: 10,
		    	center: new google.maps.LatLng(centerLat, centerLon),
		    	mapTypeId: google.maps.MapTypeId.ROADMAP
		  	};
		  	map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
		  	//map.setCenter(new google.maps.LatLng(currPoint.lat,currPoint.lon));
		  	updateMarkerLocation();
		}
	} else {
		// Driving directions
		directionsDisplay = new google.maps.DirectionsRenderer();
		directionsService = new google.maps.DirectionsService();
		var mapOptions = {
			//zoom:2,
			//center: sAddr
		}
		//console.log("sAddr: " + sAddr + ", dAddr: " + dAddr);
		map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);
		directionsDisplay.setMap(map);
		//directionsDisplay.preserveViewport = true;
  		calcRoute(sAddr, dAddr);
	}
}

</script>
</head>
<body onLoad="javascript:initialize();">
<div id="map-canvas"></div>
</body>
</html>
]]