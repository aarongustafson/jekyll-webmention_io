---
title: "Jekyll Webmention.io Tags: webmention_links"
---

# `webmention_links`

You can get a complete list of “link” webmentions for a given `page.url` using the following liquid tag:

{% raw %}
```liquid
{% webmention_links page.url %}
```
{% endraw %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

## Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--links` - Identifies this as only pertaining to “links”
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
* `webmentions__not-found` - The “no results” message shown if no mentions are found (`p`)