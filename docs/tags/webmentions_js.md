---
title: "Jekyll Webmention.io Tags: webmentions_js"
---

# `webmentions_js`

Because static websites are, well, static, it’s possible webmentions might have accrued since your site was last built. This gem includes JavaScript code to pipe those webmentions into your pages asynchronously. These features are turned on by default, but require some tags in order to work:

{% raw %}
```html
  …
  {% webmentions_js %}
</body>
```
{% endraw %}

Include this tag before your post layout’s `</body>` and the plugin will render in a `script` tag pointing to the `JekyllWebmentionIO.js` file and generate `template` tags corresponding to the various Liquid templates (default or custom) being used to render your webmentions.

We are using [liquid.js](https://github.com/mattmccray/liquid.js), a JavaScript port of Liquid by [Matt McCray](https://github.com/mattmccray/), to render these webmentions.

If you use [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP), you need to add these values:

```sh
script-src https://webmention.io
connect-src ws://webmention.io:8080
```

## The JavaScript file

By default, this gem will render a new file, `JekyllWebmentionIO.js`, into the `js` directory in your source folder. The file will be compressed using [a Ruby port of Uglify](https://github.com/lautis/uglifier). This file will also get added to your deployment build (even on the first run). For most use cases, this approach plus the `webmentions_js` Liquid tag will be perfectly adequate, but if you need more control, there are a few configuration options available. All are nested in `webmentions.js`:

* `deploy` - If you would rather manage the deployment of this JavaScript file independently, add this property and set it to `false`. The file will not be added to your site build. If you do this, you will likely also want to set the `destination` to a directory Jekyll excludes.
* `destination` - Where you want the file to be put within your site’s source folder. If you don’t explicitly name a location, the file will be placed in `SOURCE_FOLDER/js`.
* `source` - If you do not want the JavaScript file added to your Jekyll install’s source folder, set this to `false`
* `uglify` - If you would prefer to minify the file yourself using another tool, add this property and set it to `false`.

Here’s an example that deploys to an ignored folder and doesn’t bother with minification or deployment (as I use a Gulp task to build and minify my JavaScript files):

```yaml
webmentions:
  cache_folder: _data
  cache_bad_uris_for: 5
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  js:
    destination: _javascript/posts
    uglify: false
    deploy: false
```

You can also disable all JavaScript-related actions of this gem globally:

```yaml
webmentions:
  cache_folder: _data
  cache_bad_uris_for: 5
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  js: false
```

## Streaming Mentions

Coming Soon!