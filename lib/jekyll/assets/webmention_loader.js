// @ts-check
(function(window, document){
  
  // prerequisites
  if ( ! ( 'querySelectorAll' in document ) ){ return; }

  if ( ! ( 'JekyllWebmentionIO' in window ) ){ window.JekyllWebmentionIO = {}; }
  
  var targets = [],
      $redirects = document.querySelector('meta[property="webmention:redirected_from"]'),
      redirects,
      base_url = window.location.origin,
      $script;
  
  targets.push( base_url + window.location.pathname );
  if ( $redirects )
  {
    redirects = $redirects.getAttribute('content').split(',');
    redirects.forEach(function( value ){
      targets.push( 
        value.indexOf('//') < 0 ? base_url + value : value
      );
    });
    redirects = false;
  }

  // Load up any unpublished webmentions on load
  $script = document.createElement('script');
  $script.async = true;
  $script.src = 'https://webmention.io/api/mentions?' +
                'jsonp=window.JekyllWebmentionIO.processWebmentions&target[]=' +
                targets.join( '&target[]=' );
  document.querySelector('head').appendChild( $script );
  
}(this, this.document));