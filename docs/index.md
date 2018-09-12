---
title: Jekyll Webmention.io
---

# Jekyll Webmention.io

This gem includes a suite of tools for managing [webmentions](https://indieweb.org/Webmention) in Jekyll, using the [the webmention.io service](https://webmention.io).

If you want to dive right in, read the [Quickstart](/jekyll-webmention_io/quickstart).

* **[Tags](/jekyll-webmention_io/tags/)**
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
* **[Commands](/jekyll-webmention_io/commands)** - Send webmentions you’ve made
* **[Generators](/jekyll-webmention_io/generators)** - Collect webmentions from Webmention.io and gather sites you’ve mentioned

Other topics you might be interested in:

* **[Configuration](/jekyll-webmention_io/configuration)** - How to configure yoru installation
* **[Performance Tuning](/jekyll-webmention_io/performance-tuning)** - How to speed up (or at least manage) your build time
* **[Debugging](/jekyll-webmention_io/debugging)** - Print debugging info to the command line

## Supported webmentions

All inbound webmentions of your posts are collected (see below for [info on adding pages & collections into the mix](/jekyll-webmention_io/configuration#whats-checked)). The following are able to be distilled and handled separately:

* bookmarks,
* links,
* likes,
* posts,
* replies,
* reposts, and
* RSVPs.