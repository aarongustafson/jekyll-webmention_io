---
title: "Bad URI Policy"
---

Attempts to send webmentions to a given site may fail for a few different reasons:

1. The site doesn't support webmentions.
2. The site returned an error indicating an issue with the request.
3. The site returned a server error or there was a network connectivity issue.

When an error like this occurs, this plugin tracks a record indicating the affected host, the time the attempt was made, and the number of attempts that have been made with that host.  The next time the plugin attempts to send a webmention, a configurable policy controls whether the attempt is made or skipped.  This reduces the number of unnecessary attempts made when persistent error conditions are encountered.

To provide the most flexibility the plugin allows different rules to be applied depending on the type of failure encountered.  The following is an example of complete retry policy:

```yml
bad_uri_policy:
  unsupported: ban
  error:
    policy: ignore
  failure:
    policy: retry
    retry_delay: [ 1, 12, 48, 120 ]
    max_retries: 5
  whitelist:
    - "^https://brid.gy/publish/"
  blacklist:
    - "^https://en.wikipedia.org/"
```

## Policy definition

As illustrated in the previous example, the retry policy is broken into sections based on the error type in question.  Valid error types are:

* `unsupported` - The target of the webmention does not support webmentions.
* `error` - The target of the webmention returned an error indicating a client-side issue.
* `failure` - The target of the webmention returned an error indicating a server-side issue, or there was a network connectivity failure.
* `default` - Default policy applied if no policy is defined for the recorded host status.

The `policy` field indicates how to treat the link based on the previous error encountered:

* `ban` - Always skip sending webmentions to this host.
* `ignore` - Always attempt to send webmentions to this host.
* `retry` - Attempt to send webmentions based on the retry policy.

The retry policy then allows the user to control when and how often to retry, and supports the following settings:

* `retry_delay` - A list of *hour* delay values.  For the nth attempt, the nth value is looked up in the list, and the next attempt must occur that many hours after the previous attempt.  The last entry is used for all subsequent attempts.  If not specified, defaults to 24 hours.
* `max_retries` - If specified, once this many attempts have been made, webmentions will no longer be sent to this host.  By default, there is no maximum.

## Whitelisting and Blacklisting

In some cases it's desirable to force the plugin to always (or never) send a webmention to a given URL.

As a practical example, the [brid.gy](https://brid.gy) landing page does not publish webmention endpoints.  However, the service does provide specific webmention publishing endpoints.  Unfortunately, simply including the link to brid.gy in a blog post would then result in its publishing endpoints being affected (as the policy is applied to the whole host).

To support these use cases, the plugin supports these settings:

* `whitelist` - A list of regular expressions.  If the URI in question matches one of these patterns, the webmention will be sent.
* `blacklist` - A list of regular expressions.  If the URI in question matches one of these patterns, the webmention will *not* be sent.

Note, the pattern is matched against the whole URI and not just the host.

## Default

The default policy is:

```yml
bad_uri_policy:
  default: retry
```

This is equivalent to infinite retries with a 24 delay.

## cache_bad_uris_for

In previous versions of this plugin the setting `cache_bad_uris_for` was used to control the behaviour of this plugin when an error occurred sending a webmention.  As per the previous documentation:

>  In order to reduce unnecessary requests to servers that aren’t responding, this gem will keep track of them and avoid making new requests to them for 1 day. If you’d like to adjust this up or down, you can use this configuration value. It expects a number corresponding to the number of days you want to wait before trying the domain again.

For backward compatibility, this setting is still supported.  When configured, it sets the default `retry_delay` value when the value is not specified in a given policy.  For example, this configuration:

```yml

cache_bad_uris_for: 5
bad_uri_policy:
  default:
    policy: retry
    max_attempts: 5
```

Will result in a retry policy that waits 5 *days* between attempts, and stops retrying after 5 attempts.
