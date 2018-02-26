// @ts-check
(function(window, document){
  
  // prerequisites
  if ( ! ( 'querySelectorAll' in document ) ||
       ! ( 'filter' in [] ) ||
       ! ( 'content' in document.createElement('template') ) ){ return; }

  if ( ! ( 'JekyllWebmentionIO' in window ) ){ window.JekyllWebmentionIO = {}; }

  //
  // Public Properties
  //
  JekyllWebmentionIO.existing_webmentions = [];

  //
  // Public Methods
  //

  JekyllWebmentionIO.processWebmentions = function( data ){
    // console.log( 'incoming webmentions', data.links );
    if ( data && ! ( 'error' in data ) )
    {
      var webmentions = data.links.reverse();
      
      webmentions = rationalizeIds( webmentions );
      
      webmentions = removeDuplicates( webmentions );

      // We may not need to proceed if we had them all
      if ( webmentions.length )
      {
        webmentions = addMetadata( webmentions );

        // hande them out
        doleOutWebmentions( webmentions );

        // reset the counters
        if ( this.counter_update_event )
        {
          document.dispatchEvent( this.counter_update_event );
        }
      }
      else
      {
        // console.log( 'no new webmentions to add' );
      }
    }
  };

  //
  // Private Properties
  //

  var webmention_receivers = {},
      templates = {};

  //
  // Private Methods
  //

  // Gathers embewdded templates
  function collectTemplates()
  {
    var $templates = document.querySelectorAll( 'template[id^=webmention-]' ),
        t = $templates.length,
        $template;
    
    while ( t-- )
    {
      $template = $templates[t];
      // We only need the list (if one exists)
      if ( $template.content.querySelector('ol') )
      {
        templates[$template.id] = $template.content.querySelector('ol');
      }
      else
      {
        templates[$template.id] = $template.content;
      }
    }
    $template = null;
  }

  // Collects webmentions that are already on the page
  function collectExistingWebmentions()
  {
    var $existing_webmentions = document.querySelectorAll( '[id^=webmention-]' ),
        e = $existing_webmentions.length;
    
    while ( e-- )
    {
      JekyllWebmentionIO.existing_webmentions.push(
        $existing_webmentions[e]
            .getAttribute( 'id' )
            .replace( 'webmention-', '' )
      );
    }

    $existing_webmentions = null;
  }

  function identifyWebmentionCollections()
  {
    var $webmention_collections = document.querySelectorAll( '.webmentions' ),
        w = $webmention_collections.length,
        $webmention_collection,
        type,
        types, t;

    // Assign the type & template if we can determine it
    while ( w-- )
    {
      $webmention_collection = $webmention_collections[w];

      // Assign the type
      type = 'webmentions'; // Generic
      if ( $webmention_collection.className.indexOf('webmentions--') > -1 )
      {
        type = $webmention_collection.className.match(/webmentions\-\-(.*)/)[1];
      }
      $webmention_collection.type = type;
      
      // Assign the template
      if ( templates['webmention-' + type] )
      {
        $webmention_collection.template = templates['webmention-' + type];
      }
      
      // Add to the queues
      if ( 'dataset' in $webmention_collection &&
          'webmentionTypes' in $webmention_collection.dataset )
      {
        types = $webmention_collection.dataset.webmentionTypes.split(',');
      }
      else
      {
        types = [ type ];
      }
      t = types.length;
      while (t--)
      {
        type = types[t];
        if ( ! ( type in webmention_receivers ) )
        {
          webmention_receivers[type] = [];
        }
        webmention_receivers[type].push( $webmention_collection );
      }
    }
    
    $webmention_collection = null;
  }

  // Divvies up the webmentions and populate the lists
  function doleOutWebmentions( webmentions )
  {
    var i = 0, j,
        webmention,
        incoming = {},
        queue_keys = Object.keys( webmention_receivers ),
        plural_type,
        typeFilter = function(key) {
          return JekyllWebmentionIO.types[key] === this.type;
        },
        typeFilterLoop;
    
    // set up the queues
    i = queue_keys.length;
    while( i--)
    {
      incoming[queue_keys[i]] = [];
    }

    // Assign the webmentions to their respective queues
    i = webmentions.length;
    
    while ( i-- )
    {
      webmention = webmentions[i];
      // reverse lookup to get the plural from the singular
      typeFilterLoop = typeFilter.bind(webmention);
      plural_type = Object.keys(JekyllWebmentionIO.types)
                          .filter(typeFilterLoop)[0];
      
      // Is there a specific queue requesting this?
      if ( queue_keys.indexOf( plural_type ) > -1 )
      {
        incoming[plural_type].push( webmention );
      }
      
      // If there’s a generic, add it there too
      if ( incoming.webmentions )
      {
        incoming.webmentions.push( webmention );
      }
    }
    
    // Now hand them out
    i = queue_keys.length;
    while( i-- )
    {
      j = webmention_receivers[queue_keys[i]].length;
      while ( j-- )
      {
        // No point passing nothing
        if ( incoming[queue_keys[i]].length > 0 )
        {
          addWebmentionsToCollection( incoming[queue_keys[i]], webmention_receivers[queue_keys[i]][j] );
        }
      }      
    }

  }

  function addWebmentionsToCollection( mentions, $webmention_collection )
  {
    if ( mentions.length < 1 )
    {
      console.warn( 'No webmentions to add, check your application code' );
      return;
    }

    if ( ! $webmention_collection.template )
    {
      console.error( 'No template found for this webmention group', $webmention_collection );
      return;
    }

    if ( ! ( 'Liquid' in window ) )
    {
      console.error( 'Liquid parsing engine is not available' );
      return;
    }

    var $list = $webmention_collection.querySelector('.webmentions__list'),
        template = $webmention_collection.template,
        mode = 'append',
        html;

    // Already working with a list
    if ( $list )
    {
      template = Liquid.parse( template.innerHTML );
    }
    // Need a list
    else
    {
      template = Liquid.parse( template.outerHTML );
      mode = 'replace';
    }

    // append
    html = template.render({ 'webmentions': mentions });
    if ( mode == 'append' )
    {
      $list.innerHTML += html;
    }
    else
    {
      $webmention_collection.innerHTML = html;
    }

    // console.log( 'Successfully added', mentions.length );
  }
    
  // Uses the ID attribute for everything except tweets
  function rationalizeIds( webmentions )
  {
    // console.log( 'rationizing IDs' );
    var i = webmentions.length,
        id,
        url;

    while ( i-- )
    {
      id = webmentions[i].id;
      url = webmentions[i].data.url || webmentions[i].source;
      if ( url && url.indexOf( 'twitter.com/' ) > -1 )
      {
        // Unique tweets gets unique IDs
        if ( url.indexOf( '#favorited-by' ) < 0 )
        {
          id = url.replace( /^.*?status\/(\d+)$/, '$1' );
        }
      }
      // coerce to a string
      webmentions[i].id = id + '';
    }

    //console.log( webmentions.length, 'IDs rationalized' );
    return webmentions;
  }

  // Removes duplicate webmentions
  function removeDuplicates( webmentions )
  {
    // console.log( 'removing duplicates' );
    // going backwards, so reverse things to start out
    webmentions.reverse();

    var unique_webmentions = [],
        i = webmentions.length,
        id;
    
    while ( i-- )
    {
      if ( JekyllWebmentionIO.existing_webmentions.indexOf( webmentions[i].id ) < 0 )
      {
        unique_webmentions.push(webmentions[i]);
        JekyllWebmentionIO.existing_webmentions.push(webmentions[i].id);
      }
    }

    // console.log( 'removed', webmentions.length - unique_webmentions.length, 'duplicates', unique_webmentions );
    return unique_webmentions;
  }

  // Adds the necessary metadata to each webmention object for the liquid templates
  function addMetadata( webmentions )
  {
    // console.log( 'adding metadata' );
    // going backwards, so reverse things to start out
    webmentions.reverse();

    var i = webmentions.length,
        webmention,
        webmention_object,
        uri,
        source,
        pubdate,
        type,
        title,
        content,
        read = function( html_source ){
          if ( html_source )
          {
            updateTitle( this.id, this.uri, html_source );
          }
        },
        loop_read;

    while ( i-- )
    {
      webmention = webmentions[i];

      uri = webmention.data.url || webmention.source;

      source = false;
      if ( uri.indexOf('twitter.com/') )
      {
        source = 'twitter';
      }
      else if ( uri.indexOf('/googleplus/') > -1 )
      {
        source = 'googleplus';
      }

      pubdate = webmention.data.published_ts;
      if ( ! pubdate && webmention.verified_date )
      {
        pubdate = webmention.verified_date;
      }
      if ( pubdate )
      {
        pubdate = (new Date(pubdate)).getTime();
      }
      
      webmention_object = {
        id:      webmention.id,
        url:     uri,
        source:  source,
        pubdate: pubdate,
        raw:     webmentions[i]
      };

      if ( 'author' in webmention.data )
      {
        webmention_object.author = webmentions[i].data.author;
      }
              
      type = webmentions[i].activity.type;
      if ( ! type )
      {
        if ( source == 'googleplus' )
        {
          if ( uri.indexOf('/like/') > -1 )
          {
            type = 'like';
          }
          else if ( uri.indexOf( '/repost/' ) > -1 )
          {
            type = 'repost';
          }
          else if ( uri.indexOf( '/comment/' ) > -1 )
          {
            type = 'reply';
          }
          else
          {
            type = 'link';
          }
        }
        else
        {
          type = 'post';
        }
      }
      webmention_object.type = type;

      // Posts
      title = false;
      if ( type == 'post' )
      {
        loop_read = read.bind({
          id: webmention_object.id,
          uri: uri
        });
        readWebPage( uri, loop_read );
      }

      content = webmention.data.content;
      if ( type != 'bookmark' && type != 'link' && type != 'post' && type != 'reply' )
      {
        content = webmention.activity.sentence_html;
      }
      webmention_object.content = content;

      // replace the existing webmention
      webmentions[i] = webmention_object;
    }

    // console.log( 'added metadata to', webmentions.length, 'webmentions' );
    return webmentions;
  }

  // Async update of the title
  function updateTitle( webmention_id, url, html_source )
  {
    var $webmention = document.querySelector( '#webmention-' + webmention_id ),
        $current_title = $webmention.querySelector( '.webmention__title' ),
        $page = document.createElement('html'),
        title = '',
        $link_title,
        $title,
        $h1;

    $page.innerHTML = html_source;
    $title = $page.querySelector('title');
    $h1 = $page.querySelector('h1');

    if ( $current_title.length < 0 )
    {
      $current_title = $webmention.querySelector( '.webmention__content' );
    }

    if ( $current_title.length > 0 )
    {
      if ( $title.length > 0 )
      {
        title = $title.innerText;
      }
      else
      {
        if ( $h1.length > 0 )
        {
          title = $h1.innerHTML;
        }
        else
        {
          title = 'No title available';
        }
      }

      if ( title )
      {
        // cleanup
        title = title.replace( /<\/?[^>]+?>}/, '' );
        $link_title = document.createElement('a');
        $link_title.href = url;
        $link_title.appendChild( document.createTextNode( title ) );
        // replace title contents
        $current_title.innerHTML = $link_title.outerHTML;
      }
    }
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
          XHR.onabort = function() {
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

  // init
  collectTemplates();
  collectExistingWebmentions();
  identifyWebmentionCollections();
  
}(this, this.document));