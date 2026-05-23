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

  // Load up any unpublished webmentions on load. The API base is injected at
  // build time (see CompileJS#add_config); fall back to webmention.io.
  $script = document.createElement('script');
  $script.async = true;
  $script.src = ( window.JekyllWebmentionIO.api_base || 'https://webmention.io/api' ) +
                '/mentions?' +
                'jsonp=window.JekyllWebmentionIO.processWebmentions&target[]=' +
                targets.join( '&target[]=' );
  document.querySelector('head').appendChild( $script );
  
}(this, this.document));