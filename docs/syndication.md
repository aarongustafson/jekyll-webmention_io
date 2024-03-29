---
title: "Syndication"
---

A core concept of [POSSE](https://indieweb.org/POSSE) is the syndication of content from your blog to [silos](https://indieweb.org/silo) such as Mastodon, Github, and so forth.  Syndication is often done manually, but services like [Brid.gy](https://brid.gy/) make it possible to automate the process using webmentions.  Additionally, sites like [IndieNews](https://news.indieweb.org/) make it possible to publish links to the service in the same way.

To enable syndication to services supporting webmention, this plugin includes some convenience configuration that makes it easy to indicate common webmention targets that you'd like to use for posts.  This mechanism comes in the form of:

1. A set of short-hand syndication endpoints, specified in your site configuration
2. Additional front matter in the page that indicates where to send webmentions
3. Additional material in your layout template to automatically include the endpoint URL in the page
4. Support for pulling data from syndication endpoint JSON responses into the page front matter for display

## Site configuration

The first part of the setup is to configure your syndication endpoints:

```yml
webmentions:
  syndication:
    mastodon: 
      endpoint: https://brid.gy/publish/mastodon
    github: 
      endpoint: https://brid.gy/publish/github
```

Each endpoint includes a shorthand name and the URL to send the webmention to.  In this case, we're configuring our system to send webmentions to Brid.gy for automated syndication.

## Post syndication

Once syndication targets have been set up, you must provide Jekyll with instructions as to where to syndicate each page.  Syndication is controlled in one of two ways:

1. Page front matter
2. Collection configuration

Note, these can be combined.  If you specify syndication targets in both front matter and collections, the results are combined and webmentions are sent to all endpoints that apply for the page in question.

### Front matter

If a page contains a "syndicate_to" key in its front matter, the value is assumed to be an array which contains the names of one or more endpoints to send webmentions to.  For example:

```yml
---
layout: post
date:   2019-11-18 09:49:09 -0700
syndicate_to: [ mastodon, github ]
---
```

Alternatively, this can also be controlled via the `defaults` Jekyll configuration.  For example:

```yml
defaults:
  -
    scope:
      path: ""
      type: "posts"
    values:
      syndicate_to: [ mastodon, github ]
```

Either way, when the site is built, a webmention will be send with the page as the source and the webmention endpoint as the target.

### Collections

As an alternative to used `defaults`, you can also instruct the plugin to syndicate whole collections as follows:

```yml
collections:
  posts:
    syndicate_to: [ mastodon, github ]
```

## Layout

Receivers of webmentions require that the source page where the webmention originates include a link to the target page.  To automate this, some additional material should be added to the page layout (the simplest would be to add this to the common header or footer):

{%raw%}
```
{% for target in page.syndicate_to %}
  <a href="{{ site.webmentions.syndication[target].endpoint }}"></a>
{% endfor %}
```
{%endraw%}

## Response mapping

Some syndication endpoints return JSON responses which contain important information about the syndicated post, such as permalinks to the syndicated copy on the target silo.

This plugin supports defining a mapping from data in the response to keys in the front matter for the page.  For example:

```yml
webmentions:
  syndication:
    mastodon: 
      endpoint: https://brid.gy/publish/mastodon
      response_mapping:
        syndication: $.url
        username: $.user.screen_name: 
```

The keys in the `response_mapping` map represent the names of keys that will be populated in the page front matter.  The values are [JsonPath](https://goessner.net/articles/JsonPath/) expressions that return the value for the key.  If the expression returns a single value, that value will be used to populate the front matter.  Otherwise, the set of values will be stored as an array.

Note:  If multiple endpoints are specified that map a response value to the same front matter key, the result will be a flattened array of values.

These values can then be used in the page layout.  For example, the following snippet will use the `syndication` front matter property defined above to create links to the syndicated content on the target silo:

{%raw%}
```
{%- for url in page.syndication -%}
  <a class="u-syndication" href="{{ url }}">{{ url }}</a>
{%- endfor -%}
```
{%endraw%}

If you're curious what is present in the endpoint responses that you might be able to use, you can find the raw webmention responses in the webmention_io_outgoing.yml file in your cache directory.

