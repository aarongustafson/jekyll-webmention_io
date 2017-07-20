# A Jekyll plugin for sending & receiving webmentions via Webmention.io.

This Gem includes a suite of tools for managing webmentions in Jekyll:

* **[Tags](#tags)**
  * [Count of webmentions](#webmention_count) (filterable)
  * [All webmentions](#webmentions) (filterable)
  * [Likes](#webmention_likes)
  * [Links](#webmention_links)
  * [Posts](#webmention_posts)
  * [Replies](#webmention_replies)
  * [Reposts](#webmention_reposts)
  * [Contents for the `head` of your pages](#webmentions_head)
  * [JavaScript enhancements](#javascript-enhancements)
* **[Commands](#commands)** - Send webmentions you’ve made
* **[Generators](#generators)** - Collect webmentions from Webmention.io and gather sites you’ve mentioned

There are also a few [JavaScript enhancement features](#javascript-enhancements) available.

## Quickstart

If you just want to get up and running quickly, here’s the rundown of what you need to do:

1. Add `gem 'jekyll-webmention_io'` to your `Gemfile`
2. Add the plugin to `gems` section of your `_config.yml`
3. Run `bundle install`
4. Add the [`{% webmentions_head %}`](#webmentions_head) tag to the `head` of your site
5. Add the [`{% webmentions %}`](#webmentions) tag to the layout for your posts where you want webmentions displayed
6. (Optional) Add the [`{% webmentions_js %}`](#javascript-enhancements) tag to the bottom of your posts template (before the `</body>` tag)

If you want to customize your install, read on…

## Webmention support

All inbound webmentions are collected. The following are able to be distilled and handled separately::

* links,
* likes,
* posts,
* replies, and
* reposts.

## Configuration

This gem will work well out of the box, but is configurable in a number of ways. Note: all of these configuration options should nest under a `webmentions` key in your `_config.yml` file.

* `cache_folder` - by default, this gem will cache all files in the `.jekyll-cache`, but you can specify another location (like `_data`) if you like. In order to avoid collisions, all cache files will be prefixed with "webmention_io_" unless your `cache_folder` value contains "webmention" (e.g. `.jekyll_cache/webmentions`)
* `cache_bad_uris_for` - In order to reduce unnecessary requests to servers that aren’t responding, this gem will keep track of them and avoid making new requests to them for 1 day. If you’d like to adjust this up or down, you can use this configuration value. It expects a number corresponding to the number of days you want to wait before trying the domain again.
* `legacy_domains` - If you’ve relocated your site from another URL or moved from to HTTPS from HTTP, you can use this configuration option to specify additional domains to append your `page.url` to. It expects an array.
* `templates` - If you would like to roll your own templates, you totally can. You will need to assign a hash of the template paths to use for loading each one.
* `username` - Your [webmention.io](https://webmention.io) username (for use in the `link` tags in your head)

### Simple Example:

```yml
webmentions:
  username: YOUR_USERNAME
  # Use my own cache folder
  cache_folder: .cache
  # skip bad URLs for 5 days
  cache_bad_uris_for: 5
  # I moved to www and then to https, so…
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
```

### Exhaustive Example:

```yml
webmentions:
  username: YOUR_USERNAME
  cache_folder: .cache
  cache_bad_uris_for: 5
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  templates:
    count: _includes/webmentions/count.html
    likes: _includes/webmentions/likes.html
    links: _includes/webmentions/links.html
    posts: _includes/webmentions/posts.html
    replies: _includes/webmentions/replies.html
    reposts: _includes/webmentions/reposts.html
    webmentions: _includes/webmentions/webmentions.html
```

## Pausing Lookups

Looking up webmentions is a time-consuming process and can really increase your build times. We are [looking into options for throttling lookups based on page age](https://github.com/aarongustafson/jekyll-webmention_io/issues/31), but in the meantime you can "pause" lookups by setting `webmentions.pause_lookups` to `true`.

It’s worth noting this will only pause the lookup end of things. Any existing webmentions cached locally will still be used.

## Picking up Redirects

If you’ve ever changed the path to your posts, you may have used [the `jekyll-redirect-from` gem](https://github.com/jekyll/jekyll-redirect-from). `jekyll-webmention_io` will look for a `redirect_from` key in your YAML front matter and automatically include that original URL in any requests for webmentions so none get left behind.

## Tags

The various tag options provided by this gem are focused around display of information about incoming webmentions.

### `webmention_count`

Displays a count of webmentions for the current `page.url`:

	{% webmention_count page.url %}
	
The output will be a number.

You can optionally filter this number by one or more supported webmention types. For instance, if you only wanted posts and replies, you could use this format:

	{% webmention_count page.url posts replies %}

### `webmentions`

You can get a complete list of webmentions for a given `page.url` using the following liquid tag:

	{% webmentions page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

You can optionally filter this number by one or more supported webmention types. For instance, if you only wanted posts and replies, you could use this format:

	{% webmentions page.url posts replies %}

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
* `webmention` - the webmention itself (`article`)
	* `webmention--[type]` - modifier for the type
	* `webmention--no-author` - added if there’s no author info available
	* `webmention--no-photo` - added if there’s no photo of the author availble
	* `webmention--author-starts` - variant for when the author’s name starts the content (as in a tweet interaction such as a favorite or retweet)
	* `h-cite` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__author` - Author of the webmention (`div`)
  * `p-author` - [Citation Microformat](http://microformats.org/wiki/h-cite)
	* `h-card` - [Person Microformat](http://microformats.org/wiki/h-card)
* `u-url` - [Person Microformat](http://microformats.org/wiki/h-card) (`a`)
* `webmention__author__photo` - Author’s photo (`img`)
  * `u-photo` - [Person Microformat](http://microformats.org/wiki/h-card)
* `webmention__content` - The webmention’s content container (`div`)
  * `p-content` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__meta` - The webmention’s meta information container (`div`)
* `webmention__pubdate` - The publication date (`time`)
  * `dt-published` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__source` - The webmention permalink (`a`)
  * `u-url` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)

### `webmention_likes`

You can get a complete list of "like" webmentions for a given `page.url` using the following liquid tag:

	{% webmention_likes page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--likes` - Identifies this as only pertaining to "likes"
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
  * `webmention`
	* `webmention--like`
* `webmention__author` - Author of the webmention (`div`)
  * `p-author` - [Citation Microformat](http://microformats.org/wiki/h-cite)
	* `h-card` - [Person Microformat](http://microformats.org/wiki/h-card)
* `u-url` - [Person Microformat](http://microformats.org/wiki/h-card) (`a`)
* `webmention__author__photo` - Author’s photo (`img`)
  * `u-photo` - [Person Microformat](http://microformats.org/wiki/h-card)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)

### `webmention_links`

You can get a complete list of "link" webmentions for a given `page.url` using the following liquid tag:

	{% webmention_links page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--links` - Identifies this as only pertaining to "links"
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
  * `webmention`
	* `webmention--like`
* `webmention__meta` - The webmention’s meta information container (`div`)
* `webmention__author` - Author of the webmention (`a`)
  * `h-card` - [Person Microformat](http://microformats.org/wiki/h-card)
  * `u-url` - [Person Microformat](http://microformats.org/wiki/h-card) (`a`)
* `webmention__source` - The webmention permalink (`a`)
  * `u-url` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__pubdate` - The publication date (`time`)
  * `dt-published` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)

### `webmention_posts`

You can get a complete list of "posts" webmentions for a given `page.url` using the following liquid tag:

	{% webmention_posts page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--posts` - Identifies this as only pertaining to "posts"
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
  * `webmention`
	* `webmention--post`
* `webmention__title` - The title of the post (`a`)
	* `webmention__source`
  * `u-url` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__meta` - The webmention’s meta information container (`div`)
* `webmention__pubdate` - The publication date (`time`)
  * `dt-published` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)

### `webmention_replies`

You can get a complete list of "reply" webmentions for a given `page.url` using the following liquid tag:

	{% webmention_replies page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--replies` - Identifies this as only pertaining to "replies"
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
  * `webmention`
	* `webmention--reply`
* `webmention__meta` - The webmention’s meta information container (`div`)
* `webmention__author` - Author of the webmention (`a`)
  * `h-card` - [Person Microformat](http://microformats.org/wiki/h-card)
  * `u-url` - [Person Microformat](http://microformats.org/wiki/h-card) (`a`)
* `webmention__author__photo` - Author’s photo (`img`)
  * `u-photo` - [Person Microformat](http://microformats.org/wiki/h-card)
* `p-name` - Author’s name (`b`)
* `webmention__source` - The webmention permalink (`a`)
  * `u-url` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmention__pubdate` - The publication date (`time`)
  * `dt-published` - [Citation Microformat](http://microformats.org/wiki/h-cite)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)
	
### `webmention_reposts`

You can get a complete list of "repost" webmentions for a given `page.url` using the following liquid tag:

	{% webmention_reposts page.url %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

#### Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--reposts` - Identifies this as only pertaining to "likes"
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
  * `webmention`
	* `webmention--repost`
* `webmention__author` - Author of the webmention (`div`)
  * `p-author` - [Citation Microformat](http://microformats.org/wiki/h-cite)
	* `h-card` - [Person Microformat](http://microformats.org/wiki/h-card)
* `u-url` - [Person Microformat](http://microformats.org/wiki/h-card) (`a`)
* `webmention__author__photo` - Author’s photo (`img`)
  * `u-photo` - [Person Microformat](http://microformats.org/wiki/h-card)
* `webmentions__not-found` - The "no results" message shown if no mentions are found (`p`)

### `webmentions_head`

To insert bits and bobs that will help webmention-enable your site, you’ll want to include this in the `head` of your pages. If you include a `username` in your [configuration](#configuration), it will automatically generate the `link` elements necessary to notify webmention clients of the [webmention.io](https://webmention.io) endpoint where webmentions should be sent. It will also drop in information about any [redirects in play](#picking-up-redirects) for the current page and insert [Client Hints](http://httpwg.org/http-extensions/client-hints.html) that will make the [JavaScript enhancements](#javascript-enhancements) faster.

```html
<head>
  …
  {% webmentions_head %}
</head>
```

## Commands

Webmentions are not automatically sent when building your Jekyll project as that may not always be desirable. That said, this gem does automatically collect mentions made in your posts. It caches them and makes them available to you to send using the following command:

```
$> jekyll webmention
```

## Generators

This gem includes two generators. One collects any webmentions referencing your posts. The other collects any webmentions you may have made in order to queue them up for sending using [the `jekyll webmention` command](#commands).

## JavaScript enhancements

Because static websites are, well, static, it’s possible webmentions might have accrued since your site was last built. This gem includes JavaScript code to pipe those webmentions into your pages asynchronously. These features are turned on by default, but require some tags in order to work:

```html
  …
  {% webmentions_js %}
</body>
```

Include this tag before your post layout’s `</body>` and the plugin will render in a `script` tag pointing to the `JekyllWebmentionIO.js` file and generate `template` tags corresponding to the various Liquid templates (default or custom) being used to render your webmentions.

We are using [liquid.js](https://github.com/mattmccray/liquid.js), a JavaScript port of Liquid by [Matt McCray](https://github.com/mattmccray/), to render these webmentions.

### The JavaScript file

By default, this gem will render a new file, `JekyllWebmentionIO.js`, into the `js` directory in your source folder. The file will be compressed using [a Ruby port of Uglify](https://github.com/lautis/uglifier). This file will also get added to your deployment build (even on the first run). For most use cases, this apprach plus the `webmentions_js` Liquid tag will be perfectly adequate, but if you need more control, there are a few configuration options available. All are nested in `webmentions.js`:

* `deploy` - If you would rather manage the deployment of this JavaScript file independently, add this property and set it to `false`. The file will not be added to your site build. If you do this, you will likely also want to set the `destination` to a directory Jekyll excludes.
* `destination` - Where you want the file to be put within your site’s source folder. If you don’t explicitly name a location, the file will be placed in `SOURCE_FOLDER/js`.
* `source` - If you do not want the JavaScript file added to your Jekyll install’s source folder, set this to `false`
* `uglify` - If you would prefer to minify the file yourself using another tool, add this property and set it to `false`.

Here’s an example that deploys to an ignored folder and doesn’t bother with minification or deployment (as I use a Gulp task to build and minify my JavaScript files):

```yaml
webmentions:
  cache_folder: _data
  cache_bad_uris_for: 5
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  js:
    destination: _javascript/posts
    uglify: false
    deploy: false
```

You can also disable all JavaScript-related actions of this gem globally:

```yaml
webmentions:
  cache_folder: _data
  cache_bad_uris_for: 5
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  js: false
```

### Streaming Mentions

Coming Soon!
