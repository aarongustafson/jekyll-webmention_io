---
title: "Quickstart"
---

If you want to get up and running quickly, here’s the rundown of what you need to do:

{% raw %}
1. Add `gem 'jekyll-webmention_io'` to the `:jekyll_plugins` group in your `Gemfile`
2. Run `bundle install`
3. Add the [`{% webmentions_head %}`](/aarongustafson/jekyll-webmention_io/wiki/webmentions_head) tag to the `head` of your site
4. Add the [`{% webmentions %}`](/aarongustafson/jekyll-webmention_io/wiki/webmentions) tag to the layout for your posts where you want webmentions displayed
5. (Optional) Add the [`{% webmentions_js %}`](/aarongustafson/jekyll-webmention_io/wiki/JavaScript-Enhancements) tag to the bottom of your posts template (before the `</body>` tag)
{% endraw %}

If you want to customize your install, consult the sidebar.