---
title: "Jekyll Webmention.io Tags: webmention_posts"
---

# `webmention_posts`

You can get a complete list of “posts” webmentions for a given `page.url` using the following liquid tag:

{% raw %}
```liquid
{% webmention_posts page.url %}
```
{% endraw %}

The webmentions found, if any, will be piped into the webmentions template your specified in your configuration or the default one that ships with this gem.

## Default template info

If you go with the default template, here’s a rundown of elements and class names in use in the template:

* `webmentions` - overall container (`div`)
  * `webmentions--posts` - Identifies this as only pertaining to “posts”
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
* `webmentions__not-found` - The “no results” message shown if no mentions are found (`p`)