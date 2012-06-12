// import the Geolqoi Module
var geoloqi = require('ti.geoloqi');

// import the config.js file
Ti.include('config.js');

geoloqi.init({
  clientId: Config.clientId,
  clientSecret: Config.clientSecret,
  pushAccount: "geoloqi@gmail.com",
  pushIcon: "push_icon",
  trackingProfile: "ROUGH"
},{
  onSuccess: function(){
  	Ti.API.info("Session: "+geoloqi.session);
    Ti.API.info("Tracking Profile: " + geoloqi.tracker.getProfile());
    Ti.API.info("Access Token: " + geoloqi.session.getAccessToken());
    Ti.API.info("User ID: " + geoloqi.session.getUserId());
    Ti.API.info("Username: " + geoloqi.session.getUsername());
    Ti.API.info("Anonymous User?: " + geoloqi.session.isAnonymous());
    Ti.App.fireEvent("geoloqi:ready");
    
    if (Ti.Platform.osname !== "android") {
	    Ti.Network.registerForPushNotifications({
	      types:[
	        Titanium.Network.NOTIFICATION_TYPE_ALERT
	      ],
	      callback: function(data){
		      Ti.App.fireEvent("openURL",{url:data.data.geoloqi.link});
		      // Ti.App.fireEvent("refresh");
	        geoloqi.iOS.handlePush(data);
	      },
	      success:function(data){
	        geoloqi.iOS.registerDeviceToken(data.deviceToken, "live");
	      },
	      error: function(data){
	        Ti.API.error("Could Not Register For Push" + data.error + data.type);
	      }
	    });
    }
  },
  onFailure: function(){
    Ti.API.error("Geoloqi init failed or timed out!");
  }
});

var itemOpen = false;
Ti.App.addEventListener('itemClosed', function(){
	itemOpen = false;	
});

var itemView = null;
// Listen for the app event `openURL` and open a new browser window
Ti.App.addEventListener('openURL', function(e){
	args = {};
	e.url.replace(new RegExp("([^?=&]+)(=([^&]*))?", "g"), function($0, $1, $2, $3) { args[$1] = decodeURIComponent($3); });
	// view already exists and is the current window
	if(itemView && itemOpen){
		Ti.App.fireEvent("updateURL", {url:args.url});
	// view already exists but was closed
	}else if(itemView && !itemOpen){
		itemView.open();
		setTimeout(function(){
			Ti.App.fireEvent("updateURL", {url:args.url});
		}, 100);
	//first time opening an item
	} else {
		itemView = Ti.UI.createWindow({
			url: "/ui/windows/browser.js",
			tabBarHidden: true,
			openURL: args.url,
			modal:true,
			barColor: "#15a6e5"
		});
		itemView.open();
	}
	itemOpen = true;
});

Ti.App.addEventListener('openSafari', function(e){
	Ti.Platform.openURL(e.url);
});

if(Ti.Platform.osname === "iphone"){
	Ti.App.launchURL = '';
	Ti.App.pauseURL = '';
	var cmd = Ti.App.getArguments();
	if ( (typeof(cmd) == 'object') && cmd.hasOwnProperty('url') ) {
	  Ti.App.launchURL = cmd.url;
	}
	 
	Ti.App.addEventListener( 'pause', function(e) {
	  Ti.App.pauseURL = Ti.App.launchURL;
	});
	
	Ti.App.addEventListener( 'resumed', function(e) {
	  Ti.App.launchURL = '';
	  cmd = Ti.App.getArguments();
	  if ( (typeof(cmd) == 'object') && cmd.hasOwnProperty('url') ) {
	    if ( cmd.url != Ti.App.pauseURL ) {
	      Ti.App.launchURL = cmd.url;
				Ti.App.fireEvent("openURL", {url: Ti.App.launchURL});
	    }
	  }
	});
}

// create a simple namespace under PonchoApp
var PonchoApp = {
  Windows: {},
  Tabs: {}
};

(function() {
 
  // create a window to hold a webview for recent activity
  PonchoApp.Windows.activity = Ti.UI.createWindow({
    url: "ui/windows/activity.js",
    title: "Weather",
    barColor: "#15a6e5",
    backgroundColor:"#fff",
    Config: Config,
    geoloqi:geoloqi
  });

  // create a window to hold settings
  // PonchoApp.Windows.settings = Ti.UI.createWindow({
    // url: "ui/windows/settings.js",
    // title: "Settings",
    // barColor: "#15a6e5",
		// backgroundColor:"#fff",
    // geoloqi: geoloqi
  // });

  // create a window to hold about section
  PonchoApp.Windows.about = Ti.UI.createWindow({
    url: "ui/windows/about.js",
    title: "About",
    barColor: "#15a6e5",
	backgroundColor:"#fff",
    geoloqi: geoloqi
  });

  // create tab group
  PonchoApp.tabGroup = Ti.UI.createTabGroup();

  // activity view tab
  PonchoApp.Tabs.activity = Ti.UI.createTab({
    title: 'Weather',
    icon: (Ti.Platform.osname === "android") ? Ti.App.Android.R.drawable.tabs_weather_drawable : '/images/tabs_weather.png',
    window: PonchoApp.Windows.activity
  });
  PonchoApp.tabGroup.addTab(PonchoApp.Tabs.activity);
	
  // settings view tab
  /*
  PonchoApp.Tabs.settings = Ti.UI.createTab({
    title: 'Settings',
    icon: (Ti.Platform.osname === "android") ? Ti.App.Android.R.drawable.tabs_activity_drawable : '/images/tabs_activity.png',
    window: PonchoApp.Windows.categories
  });
  PonchoApp.tabGroup.addTab(PonchoApp.Tabs.settings);
  */

  // about view tab
  PonchoApp.Tabs.about = Ti.UI.createTab({
    title: 'About',
    icon: (Ti.Platform.osname === "android") ? Ti.App.Android.R.drawable.tabs_about_drawable : '/images/tabs_about.png',
    window: PonchoApp.Windows.about
  });
  PonchoApp.tabGroup.addTab(PonchoApp.Tabs.about);
	
  // open the activity tab
  PonchoApp.tabGroup.open();

})();