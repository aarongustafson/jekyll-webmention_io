// @ts-check
;(function(window, document, JekyllWebmentionIO){
  'use strict';
  
  // prerequisites
  if ( ! ( 'querySelectorAll' in document ) ){ return; }
  
  if ( ! ( 'JekyllWebmentionIO' in window ) ){ window.JekyllWebmentionIO = {}; }
  
  var $webmention_counts = document.querySelectorAll( '.webmention-count' ),
      event_name = 'JekyllWebmentionIO:update_counters';
  
  function updateCounts(){
    var w = $webmention_counts.length,
        $counter,
        types, t, type,
        count;
    
    while ( w-- )
    {
      $counter = $webmention_counts[w];
      // limited scope?
      if ( 'dataset' in $counter &&
           'webmentionTypes' in $counter.dataset )
      {
        types = $counter.dataset.webmentionTypes.split(',');
        t = types.length;
        count = 0;
        while ( t-- )
        {
          type = JekyllWebmentionIO.types[types[t]];
          count += document.querySelectorAll( '.webmention.webmention--' + type ).length;
        }
        $counter.innerText = count;
      }
      else
      {
        $counter.innerText = document.querySelectorAll( '.webmention' ).length;
      }
    }
  }

  if ( $webmention_counts.length )
  {
    JekyllWebmentionIO.counter_update_event = new Event(event_name);
    document.addEventListener(event_name, updateCounts, false);
  }

}(this, this.document, this.JekyllWebmentionIO));