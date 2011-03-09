(function($){
  function initialize() {
    var latlng = new google.maps.LatLng(35.657872, 139.70232);
    var myOptions = {
      zoom: 13,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    var map = new google.maps.Map(document.getElementById('map_canvas'), myOptions);
    return map;
  }
  $(function(){
    $('#map_canvas').height($(window).height()-20);
    $('#map_canvas').width($(window).width()-20);
    $('#header').width($(window).width()-20);
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
      var latLng = new google.maps.LatLng(data['lat'], data['lng']);
      var marker = new google.maps.Marker({
        position: latLng,
        icon: data['thumbnail'],
        title: data['name'],
        map: map
      });
      map.setCenter(latLng);
    });
  });
})(jQuery);
