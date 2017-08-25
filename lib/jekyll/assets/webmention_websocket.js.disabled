(function(window, JekyllWebmentionIO){
  'use strict';

  // prerequisites
  if ( ! ( 'WebSocket' in window ) ){ return; }
  
  if ( ! ( 'JekyllWebmentionIO' in window ) ){ window.JekyllWebmentionIO = {}; }
  
  var ws = new WebSocket('wss://webmention.io:8080');

  ws.onopen = function(){
    // Send the current window URL to the server to register to receive notifications about this URL
    ws.send( window.location );
  };

  ws.onmessage = function( event ){
    data = JSON.parse( event.data );
    console.log( data );
  };

}(this, window.JekyllWebmentionIO));