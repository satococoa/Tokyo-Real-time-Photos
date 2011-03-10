(function($){
  function initialize() {
    var latlng = new google.maps.LatLng(35.657872, 139.70232);
    var myOptions = {
      zoom: 10,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    $('#map_canvas').height($(window).height()-20);
    $('#map_canvas').width($(window).width()-20);
    $('#header').width($(window).width()-20);
    var map = new google.maps.Map(document.getElementById('map_canvas'), myOptions);
    $.each(sub, function(){
      var latLng = new google.maps.LatLng(this.lat, this.lng);
      circle = new google.maps.Circle({center: latLng,
                                        fillColor: '#00AAFF',
                                        fillOpacity: 0.7,
                                        map: map,
                                        radius: 5000});
    });
    google.maps.event.addListener(map, 'click', function(event){
      $.post('/admin/subscriptions', {lat: event.latLng.lat(), lng: event.latLng.lng()});
      circle = new google.maps.Circle({center: event.latLng,
                                        fillColor: '#00AAFF',
                                        fillOpacity: 0.7,
                                        map: map,
                                        radius: 5000});
    });
    $('#delete_subs').click(function(){
      $.post('/admin/subscriptions', {_method: 'delete'});
    });
  }

  $(function(){
    if (initialize != undefined && $('#map_canvas').length > 0) {
      initialize();
    }
  });
})(jQuery);
