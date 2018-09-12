---
title: "Jekyll Webmention.io Performance Tuning"
---

# Performance Tuning

Looking up webmentions is a time-consuming process and can really increase your build times. As it’s likely that engagement with your content will go down over time, this plugin enables you to tailor how often you want to look for new webmentions of your posts. Using the `webmentions.throttle_lookups` key, you can deal with posts in the following broad categories:

* `last_week` - Posts with a `date` in the last week
* `last_month` - Posts with a `date` in the last month
* `last_year` - Posts with a `date` in the last year
* `older` - Everything else

Each of these accepts one of the following values:

* daily
* weekly
* monthly
* yearly
* every &lt;digit&gt; [ days | weeks | months | years]

For instance, it might be sensible to look for webmentions daily for posts you’ve made in the last week, weekly for posts made in the last month, every 2 weeks for posts made in the last year, and monthly thereafter. To do that you’d set up the configuration like this:

```yml
webmentions:
  throttle_lookups:
    last_week: daily
    last_month: weekly
    last_year: every 2 weeks
    older: monthly
```

You can also completely “pause” lookups by setting `pause_lookups` to `true`:

```yml
webmentions:
  pause_lookups: true
```

It’s worth noting that throttling and pausing only apply to looking for new webmentions. Any existing webmentions that have already been gathered and cached will still be used to output the site.