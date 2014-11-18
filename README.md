# Liquid Webmention Tag for Jekyll and Octopress

This plugin makes it possible to load [webmentions](http://indiewebcamp.com/webmention) from [Webmention.io](http://webmention.io) into your Jekyll and Octopress projects. It currently supports the following:

## Webmention Count

Get a count of webmentions for a page or post using the following liquid tag:

	{% webmention_count YOUR_URL %}
	
The output will simply be a number.

## Webmention List

You can get a complete list of webmentions for a page or post using the following liquid tag:

	{% webmentions YOUR_URL %}

If webmentions are found, this is the format they will come out in:

	<div class="webmentions">
		<ol class="webmentions__list">
			<!-- if it has a Name/Title, this is the generated code -->
			<li class="webmentions__item">
				<article class="webmention webmention--title-only">
					<!-- if Author this block appears -->
					<div class="webmention__author vcard">
						<!-- if Author Link the name is wrapped in a link -->
						<a class="fn url" href="https://kylewm.com">
							<!-- if Author Photo -->
							<img class="webmention__author__photo photo" src="/static/img/users/kyle.jpg" alt="">
							Kyle Mahan
						</a>
					</div>
					<div class="webmention__title">
						<a href="https://kylewm.com/2014/03/renaming-my-blog-engine-groomsman-to-red-wind">renaming my blog engine Groomsman to Red Wind</a>
					</div>
					<div class="webmention__meta">
						<time class="webmention__pubdate" datetime="2014-03-13T20:33:42+00:00">13 March 2014</time>
					</div>
				</article>
			</li>
			<!-- if it has Content, but no Name, this is the generated code -->
			<li class="webmentions__item">
				<article class="webmention webmention--content-only">
					<div class="webmention__meta">
						<time class="webmention__pubdate" datetime="2014-11-11T15:30:18+00:00">11 November 2014</time>
						|
						<a class="webmention__source" href="http://aaronparecki.com/replies/2014/11/11/4/drupal">Permalink</a>
					</div>
					<div class="webmention__content">
						<!-- This is run through Markdown -->
						<p>@noneck @indiewebcamp Well the good news is there&rsquo;s lots of PHP libraries which should be easy to use in #drupal! <a href="http://indiewebcamp.com/PHP#Libraries">http://indiewebcamp.com/PHP#Libraries</a></p>
					</div>
				</article>
			</li>
		</ol>
	</div>

If no webmentions are found, the plugin spits out this:

	<div class="webmentions">
		<p class="webmentions__not-found">No webmentions were found</p>
	</div>
	
To summarize the classes, here’s what you have to work with:

* `webmentions` - overall container (`div`)
* `webmentions__list` - the list of webmentions (`ol`)
* `webmentions__item` - the webmention container (`li`)
* `webmention` - the webmention itself (`article`)
	* `webmention--title-only` - title-only variant
	* `webmention--content-only` - content-only variant
* `webmention__author` - Author of the webmention (`div`)
* `webmention__author__photo` - Author’s photo (`img`)
* `webmention__title` - The webmention’s title (`div`)
* `webmention__content` - The webmention’s content (`div`)
* `webmention__meta` - The webmention’s meta information container (`div`)
* `webmention__pubdate` - The publication date (`time`)
* `webmention__source` - The webmention permalink (`a`)
* `webmentions__not-found` - The "no results" message (`p`)

## JavaScript (optional)

I have also included a JavaScript file that will keep your webmentions up to date even when you don’t publish frequently. It will also update your page’s webmentions in realtime.