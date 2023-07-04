---
---

# A quick introduction

If you've come by this gem, I have to assume you're probably already aware of [Webmentions](https://indieweb.org/webmention), which are a technology designed to enable conversations across the web by supporting things like comments, likes, reposts, and so forth.  Think: pingback but better.

Webmentions function by having the source site send a message to a defined endpoint on the target site.  This model naturally assumes an active service that's available and listening for these messages.  Unfortunately, static site generators like Jekyll provide no such service (being served by a vanilla web server), and so some intermediary server must exist to receive webmentions and store them for use during site generation.

And this is where [webmention.io](https://webmention.io) enters the picture.  Developed and operated by the most excellent [Aaron Parecki](https://aaronparecki.com/), the service is designed to receive webmentions on behalf of a site, and provides APIs to then access those webmentions.

Which brings us to this gem, which integrates Jekyll with webmention.io to receive and display webmentions, while also providing functionality for sending webmentions to supported sites.

# Setting up the plugin

A basic installation and setup of the plugin is pretty straightforward and involves the following steps:

{% raw %}
1. Add `gem 'jekyll-webmention_io'` to the `:jekyll_plugins` group in your `Gemfile`
2. Run `bundle install`
3. Optional but recommended: Configure the `username` setting of the `webmention` configuration section to match your webmention.io user name (this ensures that anyone sending webmentions to your site can find the correct webmention endpoint)
4. Add the [`{% webmentions_head %}`](/jekyll-webmention_io/tags/webmentions_head) tag to the `head` of your site
5. Add the [`{% webmentions page.url %}`](/jekyll-webmention_io/tags/webmentions) tag to the layout for your posts where you want webmentions displayed
6. Optionally, add the [`{% webmentions_js %}`](/jekyll-webmention_io/tags/webmentions_js) tag to the bottom of your posts template (before the `</body>` tag) to dynamically render webmentions on the client between site builds
{% endraw %}

For information about more advanced configuration options, including controlling how inbound webmentions are rendered, outgoing webmentions are gathered, and so forth, see the [configuration documentation](/jekyll-webmention_io/configuration)

# Using the plugin

## Building the site

This gem includes two generators, each of which run when you build your site.

The first reaches out to the webmention.io service and collects any webmentions referencing your posts.  These webmentions are stored in your local cache directory in a filed called `webmention_io_received.yml`.  The cached webmentions are used by the supplied Jekyll custom tags to render webmentions on your site.

The second collects any webmentions you may have made--meaning any URLs you've referenced in any posts processed by this plugin, or any syndication endpoints that have been selected--and queues them up for sending.  These webmentions are queued in a file called `webmention_io_outgoing.yml`.

## Sending webmentions

Once the site is built and the outgoing webmentions have been cached, they can be sent using [the `jekyll webmention` command](/jekyll-webmention_io/commands)

```sh
$> jekyll webmention
```

Now, not all sites support receiving webmentions, and those that do may experience technical issues that prevent their being received.  The plugin includes a variety of [configuration options](/jekyll-webmention_io/bad_uri_policy) which control how these errors are handled (e.g. when to retry, how often to retry before giving up, blacklisting and whitelisting policies, etc).

# Syndication support

Beyond traditional site-to-site interactions, webmentions have also been leveraged by services like brid.gy and news.indieweb.org to enable [POSSE-style](https://indieweb.org/POSSE) content syndication.  In version 4.0.0 of this plugin, additional functionality was added to simplify integration with these services.

For more information, you can see the [syndication documentation](/jekyll-webmention_io/syndication).

# Jekyll custom tags

The gem ships with a number of custom tags which can be used to render webmentions and related information on your site, including:

* [Count of webmentions](/jekyll-webmention_io/tags/webmention_count) (filterable)
* [All webmentions](/jekyll-webmention_io/tags/webmentions) (filterable)
* [Bookmarks](/jekyll-webmention_io/tags/webmention_bookmarks)
* [Likes](/jekyll-webmention_io/tags/webmention_likes)
* [Links](/jekyll-webmention_io/tags/webmention_links)
* [Posts](/jekyll-webmention_io/tags/webmention_posts)
* [Replies](/jekyll-webmention_io/tags/webmention_replies)
* [Reposts](/jekyll-webmention_io/tags/webmention_reposts)
* [RSVPs](/jekyll-webmention_io/tags/webmention_rsvps)
* [Contents for the `head` of your pages](/jekyll-webmention_io/tags/webmentions_head)
* [JavaScript enhancements](/jekyll-webmention_io/tags/webmentions_js)

# Additional topics

* **[Performance Tuning](/jekyll-webmention_io/performance-tuning)** - How to speed up (or at least manage) your build time
* **[Debugging](/jekyll-webmention_io/debugging)** - Print debugging info to the command line
