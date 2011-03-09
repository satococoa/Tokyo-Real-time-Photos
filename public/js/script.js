(function($){
  function initialize() {
    var latlng = new google.maps.LatLng(35.657872, 139.70232);
    var myOptions = {
      zoom: 10,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    var map = new google.maps.Map(document.getElementById('map_canvas'), myOptions);
    return map;
  }
  $(function(){
    var map;
    if (initialize != undefined && $('#map_canvas').length > 0) {
      map = initialize();
    }
    var pusher = new Pusher(window.pusher_key);
    pusher.bind('pusher:connection_established', function(event){
      socket_id = event.socket_id;
    });

    // Enable pusher logging - don't include this in production
    Pusher.log = function() {
      if (window.console) window.console.log.apply(window.console, arguments);
    };
    // Flash fallback logging - don't include this in production
    WEB_SOCKET_DEBUG = true;

    pusher.subscribe('tokyo-realtime-photos');

    pusher.bind('get_photo', function(data) {
      console.log(data);
    });
  });
})(jQuery);
