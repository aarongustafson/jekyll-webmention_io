---
title: "Jekyll Webmention.io Tags: webmentions_head"
---

# `webmentions_head`

To insert bits and bobs that will help webmention-enable your site, you’ll want to include this in the `head` of your pages. If you include a `username` in your [configuration](/jekyll-webmention_io/configuration), it will automatically generate the `link` elements necessary to notify webmention clients of the [webmention.io](https://webmention.io) endpoint where webmentions should be sent. It will also drop in information about any [redirects in play](/jekyll-webmention_io/configuration#picking-up-redirects) for the current page and insert [Client Hints](http://httpwg.org/http-extensions/client-hints.html) that will make the [JavaScript enhancements](/jekyll-webmention_io/tags/webmentions_js) faster.

```html
<head>
  …
  {% webmentions_head %}
</head>
```