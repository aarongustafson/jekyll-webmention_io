---
title: "Jekyll Webmention.io Tags: webmention_count"
---

# `webmention_count`

Displays a count of webmentions for the current `page.url`:

{% raw %}
```liquid
{% webmention_count page.url %}
```
{% endraw %}

The output will be a number.

You can optionally filter this number by one or more supported webmention types. For instance, if you only wanted posts and replies, you could use this format:

{% raw %}
```liquid
{% webmention_count page.url posts replies %}
```
{% endraw %}