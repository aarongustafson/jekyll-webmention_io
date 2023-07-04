---
title: "Quickstart"
---

If you want to get up and running quickly, here’s the rundown of what you need to do:

{% raw %}
1. Add `gem 'jekyll-webmention_io'` to the `:jekyll_plugins` group in your `Gemfile`
2. Run `bundle install`
3. Optional but recommended: Configure the `username` setting of the `webmention` configuration section to match your webmention.io user name (this ensures that anyone sending webmentions to your site can find the correct webmention endpoint)
4. Add the [`{% webmentions_head %}`](/jekyll-webmention_io/tags/webmentions_head) tag to the `head` of your site
5. Add the [`{% webmentions page.url %}`](/jekyll-webmention_io/tags/webmentions) tag to the layout for your posts where you want webmentions displayed
6. (Optional) Add the [`{% webmentions_js %}`](/jekyll-webmention_io/tags/webmentions_js) tag to the bottom of your posts template (before the `</body>` tag)
{% endraw %}

If you want to customize your install, consult the sidebar.
