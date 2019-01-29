---
title: "Liquid Tag: `webmentions`"
---

You can get a complete list of webmentions for a given `page.url` using the following liquid tag:

{% raw %}

```liquid
{% webmentions page.url %}
```

{% endraw %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

You can optionally filter this list by one or more supported webmention types. For instance, if you only wanted posts and replies, you could use this format:

{% raw %}

```liquid
{% webmentions page.url posts replies %}
```

{% endraw %}

## Default template info

If you go with the default template, here’s a rundown of elements and `class` names in use in the template:

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
* `webmentions__not-found` - The “no results” message shown if no mentions are found (`p`)