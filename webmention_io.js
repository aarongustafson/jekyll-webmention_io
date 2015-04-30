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
    
;(function(window,document){
    
    if ( ! 'querySelectorAll' in document ){ return; }
    
    if ( !( 'AG' in window ) ){ window.AG = {}; }
    
    if ( ! window.location.origin )
    {
       window.location.origin = window.location.protocol + "//" + window.location.host;
    }

    var $webmentions_list = document.querySelectorAll( '.webmentions__list' ),
        elements = {
            a:          document.createElement('a'),
            author_name:document.createElement('b'),
            article:    document.createElement('article'),
            div:        document.createElement('div'), 
            photo:      document.createElement('img'),
            li:         document.createElement('li'),
            time:       document.createElement('time')
        },
        space = document.createTextNode(' '),
        months = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        ],
        json_webmentions,
        targets = [
            window.location.href.replace( 'localhost', 'www.aaron-gustafson.com' )
        ],
        $none = false,
        $redirects = document.querySelector('meta[property="webmention:redirected_from"]'),
        redirects,
        base_url = window.location.origin,
        $existing_webmentions,
        existing_webmentions = [],
        e = 0;
    
    if ( $redirects )
    {
        redirects = $redirects.getAttribute('content').split(',');
        redirects.forEach(function( value, i ){
            targets.push( 
                value.indexOf('//') < 0 ? base_url + value : value
            );
        });
        redirects = false;
    }

    // Do we need to create the list?
    if ( $webmentions_list.length < 1 )
    {
        var $none = document.querySelectorAll( '.webmentions__not-found' );
        if ( $none.length )
        {
            $none = $none[0];
            $webmentions_list = document.createElement( 'ol' );
            $webmentions_list.className = 'webmentions__list';
        }
        else
        {
            return;
        }
    }
    else
    {
        $webmentions_list = $webmentions_list[0];
        // get existing webmentions
        $existing_webmentions = $webmentions_list.querySelectorAll( '[id^=webmention-]' );
        e = $existing_webmentions.length;
        while ( e-- )
        {
            existing_webmentions.push(
                parseInt( 
                    $existing_webmentions[e]
                        .getAttribute( 'id' )
                        .replace( 'webmention-', '' ),
                    10
                )
            );
        }
        $existing_webmentions = null;
    }
    
    // Set up the markup
    elements.li.className = 'webmentions__item';
    elements.article.className = 'h-cite webmention';
    elements.time.className = 'webmention__pubdate dt-published';
    elements.author = elements.div.cloneNode();
    elements.author.className = 'webmention__author p-author h-card';
    elements.author_name.className = 'p-name';
    elements.author_link = elements.a.cloneNode();
    elements.author_link.className = 'u-url';
    elements.photo.className = 'webmention__author__photo u-photo';
    elements.photo.alt = '';
    elements.title = elements.div.cloneNode();
    elements.title.className = 'webmention__title p-name';
    elements.permalink = elements.a.cloneNode();
    elements.permalink.className = 'webmention__source u-url';
    elements.permalink.appendChild( document.createTextNode('Permalink') );
    elements.content = elements.div.cloneNode();
    elements.content.className = 'webmention__content p-content';
    elements.meta = elements.div.cloneNode();
    elements.meta.className = 'webmention__meta';
    
    function addMention( mention )
    {
        var streaming = !( 'data' in mention ),
            data = streaming ? mention : mention.data,
            id = streaming ? mention.element_id : mention.id;

        // Twitter uses the actual satus ID
        if ( data.url && data.url.indexOf( 'twitter.com/' ) > -1 )
        {
            id = data.url.replace(/^.*?status\/(.*)$/, '$1' );
        }

        // No need to replace
        if ( existing_webmentions.indexOf( id ) > -1 )
        {
            return;
        }
        
        var $existing_mention = document.querySelectorAll( '#webmention-' + id  ),
            $item = elements.li.cloneNode( true ),
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
            content = data.content,
            url = data.url,
            type = mention.activity.type,
            activity = ( type == "like" || type == "repost" ),
            sentence = mention.activity.sentence_html,
            author = data.author.name,
            author_photo = data.author.photo,
            pubdate = data.published || mention.verified_date,
            display_date = '';
        
        $item.id = 'webmention-' + id;
        $item.appendChild( $mention );

        if ( author )
        {
            $author_link.href = data.author.url;
            if ( author_photo )
            {
                $author_photo.src = author_photo;
                $author_link.appendChild( $author_photo );
            }
            $author_name.appendChild( document.createTextNode( author ) );
            $author_link.appendChild( $author_name );
            $author.appendChild( $author_link );
            $mention.appendChild( $author );

            if ( activity )
            {
                console.log( 'activity!' );
                title = author + ' ' + title;
                $mention.className += ' webmention--author-starts';
            }
        }

        if ( pubdate )
        {
            $pubdate.setAttribute( 'datetime', pubdate );
            pubdate = new Date( pubdate );
            display_date += pubdate.getUTCDate() + ' ';
            display_date += months[ pubdate.getUTCMonth() ] + ' ';
            display_date += pubdate.getUTCFullYear();
            $pubdate.appendChild( document.createTextNode( display_date ) );
            $meta.appendChild( $pubdate );
            
            if ( url & ! activity )
            {
                $meta.appendChild( document.createTextNode( ' | ' ) );
            }
        }
        if ( url & ! activity )
        {
            $link = elements.permalink.cloneNode( true );
            $link.href = url;
            $meta.appendChild( $link );
        }

        if ( type == "reply" )
        {
            title = false;
        }

        // no doubling up
        if ( title && content &&
             title == content )
        {
            title = false;
        }

        if ( title )
        {
            $mention.className += ' webmention--title-only';

            title = title.replace( 'reposts', 'reposted' );

            if ( url )
            {
                $link = elements.a.cloneNode( true );
                $link.href = url;
                $link.appendChild( document.createTextNode( title ) );
            }
            else
            {
                $link = document.createTextNode( title );
            }

            $block = elements.title.cloneNode( true );
            $block.appendChild( $link );
            $mention.appendChild( space.cloneNode( true ) );
            $mention.appendChild( $block );
        }
        else if ( content )
        {
            $mention.className += ' webmention--content-only';

            // TODO: Add Markdown
            $block = elements.content.cloneNode( true );
            
            if ( activity && sentence )
            {
                $block.innerHTML = sentence.replace( /href/, 'class="p-author h-card" href' );
            }
            else
            {
                $block.innerHTML = content;
            }
            $mention.appendChild( $block );
        }

        if ( $meta.children.length > 0 )
        {
            $mention.appendChild( $meta );
        }
        
        if ( $existing_mention.length < 1 )
        {
            if ( !! $none )
            {
                $none.parentNode.replaceChild( $webmentions_list, $none );
                $none = false;
            }
            $webmentions_list.appendChild( $item );
        }
        else
        {
            $webmentions_list.replaceChild( $item, $existing_mention[0] );
        }

        // Store the id
        existing_webmentions.push( id );
        
        // Release
        $item = null;
        $existing_mention = null;
        $mention = null;
        $author = null;
        $author_link = null;
        $author_photo = null;
        $block = null;
        $link = null;
        $meta = null;
        $pubdate = null;
    }
    
    window.AG.processWebmentions = function( data ){
        if ( ! ( 'error' in data ) )
        {
            data.links.reverse();
            data.links.forEach( addMention );
        }
    };
    
    // Load up any unpublished webmentions on load
    json_webmentions = document.createElement('script');
    json_webmentions.async = true;
    json_webmentions.src = 'http://webmention.io/api/mentions?jsonp=window.AG.processWebmentions&amp;target[]=' +
                            targets.join( '&amp;target[]' );
    document.getElementsByTagName('head')[0].appendChild( json_webmentions );
    
    // Listen for new ones
    if ( $webmentions_list.length &&
        "WebSocket" in window )
    {
        var ws = new WebSocket('ws://webmention.io:8080');
        
        ws.onopen = function( event ){
            // Send the current window URL to the server to register to receive notifications about this URL
            ws.send( this_page );
        };
        ws.onmessage = function( event ){
            addMention( JSON.parse( event.data ) );
        };
    }
    
}(this,this.document));