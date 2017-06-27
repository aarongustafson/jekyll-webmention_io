/**
 *  WebMentions.io JS
 *  A re-tooling of Aaron Parecki’s recommended JS for using the WebMention.io API
 * 
 *  Updates Webmentions on a static site immediately when the page is loaded and
 *  in real-time (using WebSockets) as the user engages with the page.
 * 
 * To inform the JavaScript of additional URLs to check (e.g. when the current page 
 * receives redirects from old URLs), use the following meta element:
 * 
 *  <meta property="webmention:redirected_from" content="URL_1,URL_2">
 * 
 * The content should be a single URL or multiple, separated by commas.
 */
    
;(function( window, document ){
  'use strict';
  
  if ( ! ( 'querySelectorAll' in document ) ||
       ! ( 'content' in document.createElement('template') ) ){ return; }
  
  if ( ! ( 'JekyllWebmentionIO' in window ) ){ window.JekyllWebmentionIO = {}; }
  
  if ( ! window.location.origin )
  {
    window.location.origin = window.location.protocol + '//' + window.location.host;
  }

  var $webmention_counts = document.querySelectorAll( '.webmention-count' ),
      counter_update_event,
      $webmentions_groups = document.querySelectorAll( '.webmentions' ),
      w = $webmentions_groups.length,
      $webmentions_group,
      type,
      $templates = document.querySelectorAll( 'template' ),
      t = $templates.length,
      $template,
      templates = [],
      months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
      ],
      json_webmentions,
      targets = [],
      $none = false,
      $redirects = document.querySelector('meta[property="webmention:redirected_from"]'),
      redirects,
      complete_urls = [],
      base_url = window.location.origin,
      $existing_webmentions = document.querySelectorAll( '[id^=webmention-]' ),
      existing_webmentions = [],
      e = $existing_webmentions.length;

  //
  // Counters
  //
  if ( $webmention_counts.length )
  {
    counter_update_event = new Event('JekyllWebmentionIO:update_counters');
    document.addEventListener('JekyllWebmentionIO:update_counters', updateCounts, false);
    function updateCounts(){
      var len = $webmention_counts.length,
          $counter,
          t,
          type,
          count;
      while ( len-- )
      {
        $counter = $webmention_counts[len];
        // limited scope?
        if ( 'webmentionTypes' in $counter.dataset )
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
  }
  
  //
  // Webmentions Lists
  //

  // Set up the targets array
  targets.push( window.location.origin + window.location.pathname );
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

  // Extract templates
  while ( t-- )
  {
    $template = $templates[t];
    if ( $template.content.querySelector('ol').length > 0 )
    {
      templates[$template.id] = $template.content.querySelector('ol');
    }
    else
    {
      templates[$template.id] = $template.content;
    }
  }
  $template = null;

  // Assign the type & template if we can determine it
  while ( w-- )
  {
    $webmentions_group = $webmentions_groups[w];

    if ( $webmentions_group.className.indexOf('webmentions--') > -1 )
    {
      type = $webmentions_group.className.match(/webmentions\-\-(.*)/)[1];
      $webmentions_groups[w].type = type;
      if ( templates['webmention-' + type] )
      {
        $webmentions_groups[w].template = templates['webmention-' + type];
      }
    }
  }
  $webmentions_group = null;

  // Capture all existing webmentions
  while ( e-- )
  {
    existing_webmentions.push(
      $existing_webmentions[e]
          .getAttribute( 'id' )
          .replace( 'webmention-', '' )
    );
  }
  $existing_webmentions = null;
  window.JekyllWebmentionIO.existing_webmentions = existing_webmentions;
  
  function addWebmentionsToGroup( mentions, $webmention_group )
  {
    if ( ! $webmention_group.template )
    {
      console.error( 'No template found for this webmention group', $webmention_group );
      return;
    }

    if ( ! ( 'Liquid' in window ) )
    {
      console.error( 'Liquid parsing engine is not available' );
      return;
    }

    var $list = $webmention_group.querySelector('.webmentions__list'),
        template = $webmention_group.template,
        mode = 'append';

    // Already working with a list
    if ( $list.length == 1 )
    {
      template = template.innerHTML;
    }
    // Need a list
    else
    {
      template = template.outerHTML;
      mode = 'replace';
    }
      //console.log(mention);
      var streaming = !( 'data' in mention ),
          data = streaming ? mention : mention.data,
          id = streaming ? mention.element_id : mention.id,
          is_tweet = false,
          is_gplus = false;

      // make sure the id is a string
      id = id.toString();

      // Tweets gets handled differently
      if ( data.url && data.url.indexOf( 'twitter.com/' ) > -1 )
      {
          is_tweet = true;
          // Unique tweets gets unique IDs
          if ( data.url.indexOf( '#favorited-by' ) == -1 )
          {
              id = data.url.replace( /^.*?status\/(.*)$/, '$1' );
          }
      }
      
      // No need to replace
      //console.log( existing_webmentions, id, existing_webmentions.indexOf( id ) );
      if ( existing_webmentions.indexOf( id ) > -1 )
      {
          return;
      }
      
      // Google Plus gets handled differently
      if ( data.url.indexOf( '/googleplus/' ) )
      {
          is_gplus = true;
      }
      
      var $item = elements.li.cloneNode( true ),
          $mention = elements.article.cloneNode( true ),
          $author = elements.author.cloneNode( true ),
          $author_name = elements.author_name.cloneNode( true ),
          $author_link = elements.author_link.cloneNode( true ),
          $author_photo = elements.photo.cloneNode( true ),
          $meta = elements.meta.cloneNode( true ),
          $pubdate = elements.time.cloneNode( true ),
          $block,
          $link,
          title = data.name,
          link_title = false,
          content = data.content,
          url = data.url || mention.source,
          type = mention.activity.type,
          author = data.author ? data.author.name : false,
          author_photo = data.author ? data.author.photo : false,
          pubdate,
          display_date = '';
      
      $item.id = 'webmention-' + id;
      $item.appendChild( $mention );

      // no data, skip it
      if ( ! title && ! content )
      {
          return;
      }
      
      ////
      // Authorship
      ////
      if ( author )
      {
          if ( author_photo )
          {
              $author_photo.src = author_photo;
              $author_link.appendChild( $author_photo );
          }
          else
          {
              $mention.className += ' webmention--no-photo';
          }
          $author_name.appendChild( document.createTextNode( author ) );
          if ( data.author.url )
          {
              $author_link.href = data.author.url;
              $author_link.appendChild( $author_name );
              $author.appendChild( $author_link );
          }
          else
          {
              $author.appendChild( $author_name );
          }
          $mention.appendChild( $author );
      }
      else
      {
          $mention.className += ' webmention--no-author';
      }

      ////
      // Content
      ////
      if ( ! type )
      {
          // Trap Google Plus from Bridgy
          if ( is_gplus )
          {
              if ( url.indexOf( '/like/' ) > -1 )
              {
                  type = 'like';
              }
              else if ( url.indexOf( '/repost/' ) > -1 )
              {
                  type = 'repost';
              }
              else if ( url.indexOf( '/comment/' ) > -1 )
              {
                  type = 'reply';
              }
              else
              {
                  type = 'link';
              }
          }
          // Default
          else
          {
              type = 'post';
          }
      }
      
      // more than likely the content was pushed into the post name
      if ( title && title.length > 200 )
      {
          title = false;
      }
      
      // TODO: Google Plus masked by Bridgy
      // Ruby Code:
      // if is_gplus and url.include? 'brid-gy'
      //     # 
      //     status = `curl -s -I -L -o /dev/null -w "%{http_code}" --location "#{url}"`
      //     if status == '200'
      //         # Now get the content
      //         html_source = `curl -s --location "#{url}"`
      // 
      //         if ! html_source.valid_encoding?
      //             html_source = html_source.encode('UTF-16be', :invalid=>:replace, :replace=>"?").encode('UTF-8')
      //         end
      // 
      //         matches = /class="u-url" href=".+">(https:.+)</.match( html_source )
      //         if matches
      //             url = matches[1].strip
      //         end
      //     else
      //         url = false
      //     end
      // end
      
      // Posts (but not tweeted links)
      if ( type == 'post' ||
            ( type == 'link' && ! is_tweet && ! is_gplus ) )
      {
          link_title = title;
          
          // No title - Async update
          if ( ! title && url )
          {
              readWebPage( url, function( html_source ){
                  if ( html_source )
                  {
                      linkTitle( $item, url, html_source );
                  }
              });
          }    
      }
      // Likes & Shares
      else if ( type == 'like' || type == 'repost' )
      {
          // new Twitter faves are doing something weird
          if ( type == 'like' && is_tweet )
          {
              link_title = author + ' favorited this.';
          }
          else if ( type == 'repost' && is_tweet )
          {
              link_title = author + ' retweeted this.';
          }
          else
          {
              link_title = title;
          }
          $mention.className += ' webmention--author-starts';
      }
      
      // Published info
      if ( data.published_ts )
      {
          pubdate = new Date(0);
          pubdate.setUTCSeconds( data.published_ts );
      }
      else if ( data.published || mention.verified_date )
      {
          pubdate = new Date( data.published || mention.verified_date );
      }
      if ( pubdate )
      {
          $pubdate.setAttribute( 'datetime', pubdate.toISOString() );
          display_date += pubdate.getUTCDate() + ' ';
          display_date += months[ pubdate.getUTCMonth() ] + ' ';
          display_date += pubdate.getUTCFullYear();
          $pubdate.appendChild( document.createTextNode( display_date ) );
          $meta.appendChild( $pubdate );
      }
      
      if ( ! link_title )
      {
          if ( pubdate && url )
          {
              $meta.appendChild( document.createTextNode( ' | ' ) );
          }
          if ( url )
          {
              $link = elements.permalink.cloneNode( true );
              $link.href = url;
              $meta.appendChild( $link );
          }
      }
      
      if ( author &&
            $mention.className.indexOf( 'webmention--author-starts' ) == -1 &&
            ( ( title && title.indexOf( author ) == '0' ) ||
              ( content && content.indexOf( author ) == '0' ) ) )
      {
          $mention.className += ' webmention--author-starts';
      }

      if ( link_title )
      {
          $mention.className += ' webmention--title-only';

          link_title = link_title.replace( 'reposts', 'reposted' );

          if ( url )
          {
              $link = elements.a.cloneNode( true );
              $link.href = url;
              $link.appendChild( document.createTextNode( link_title ) );
          }
          else
          {
              $link = document.createTextNode( link_title );
          }

          $block = elements.title.cloneNode( true );
          $block.appendChild( $link );
          $mention.appendChild( space.cloneNode( true ) );
          $mention.appendChild( $block );
      }
      else
      {
          $mention.className += ' webmention--content-only';
          $block = elements.content.cloneNode( true );
          $block.innerHTML = content;
          $mention.appendChild( $block );
      }

      if ( $meta.children.length > 0 )
      {
          $mention.appendChild( $meta );
      }
      
      if ( !! $none )
      {
          $none.parentNode.replaceChild( $webmentions_list, $none );
          $none = false;
      }
      $webmentions_list.appendChild( $item );
      
      // Store the id
      existing_webmentions.push( id );
      
      // Release
      $item = null;
      $mention = null;
      $author = null;
      $author_name = null;
      $author_link = null;
      $author_photo = null;
      $block = null;
      $link = null;
      $meta = null;
      $pubdate = null;
      
  }
  
  window.JekyllWebmentionIO.processWebmentions = function( data ){
      if ( data &&
            ! ( 'error' in data ) )
      {
          data.links.reverse();
          data.links.forEach( addMention );
          updateCount();
      }
  };

  // Update the webmentions count
  function updateCount() {
      var $webmentions_link = document.querySelector( '.entry__jump--webmentions a' ),
          webmentions_count = document.querySelectorAll( '.webmentions__item' ).length;
      
      $webmentions_link.innerHTML = webmentions_count + ' webmentions';
  }
  
  // Synchromous XHR proxied through whateverorigin.org
  function readWebPage( uri, callback )
  {
      if ( 'XMLHttpRequest' in window )
      {
          var XHR = new XMLHttpRequest();
          readWebPage = function( uri, callback ){
              var done = false;
              uri = '//whateverorigin.org/get?url=' + encodeURIComponent( uri );
              XHR.onreadystatechange = function() {
                  if ( this.readyState == 4 && ! done ) {
                      done = true;
                      callback( XHR.responseText );
                  }
              };
              xhr.onabort = function() {
                  if ( ! done )
                  {
                      done = true;
                      callback( false );
                  }
              };
              XHR.onerror = XHR.onabort;
              XHR.open( 'GET', uri );
              XHR.send( null );
          };
      }
      else
      {
          readWebPage = function( uri, callback ){
              callback( false );
          };
      }
      return readWebPage( uri, callback );
  }
  
  // Async update of the title
  function updateTitle( $item, url, html_source )
  {
      var $current_title = $item.querySelector( '.webmention__title' ),
          matches = /<title>\s*(.*)\s*<\/title>/.match( html_source ),
          title = '',
          $link_title;
      
      if ( matches )
      {
          title = matches[1];
      }
      else
      {
          matches = /<h1>\s*(.*)\s*<\/h1>/.match( html_source );
          if ( matches )
          {
              title = matches[1];
          }
          else
          {
              title = 'No title available';
          }
      }
      
      if ( title )
      {
          $link_title = elements.a.cloneNode( true );
          $link_title.href = url;
          $link_title.appendChild( document.createTextNode( title ) );
          // clear and replace title contents
          $current_title.innerHTML = '';
          $currentTitle.appendChild( $link_title );
      }
  }
  
  // Load up any unpublished webmentions on load
  json_webmentions = document.createElement('script');
  json_webmentions.async = true;
  json_webmentions.src = '//webmention.io/api/mentions?jsonp=window.AG.processWebmentions&target[]=' +
                          targets.join( '&target[]=' );
  document.getElementsByTagName('head')[0].appendChild( json_webmentions );
  
  // Listen for new ones
  if ( $webmentions_list.length &&
        'WebSocket' in window )
  {
      var ws = new WebSocket('ws://webmention.io:8080');
      
      ws.onopen = function(){
          // Send the current window URL to the server to register to receive notifications about this URL
          ws.send( window.location );
      };
      ws.onmessage = function( event ){
          addMention( JSON.parse( event.data ) );
          updateCount();
      };
  }
    
}(this,this.document));