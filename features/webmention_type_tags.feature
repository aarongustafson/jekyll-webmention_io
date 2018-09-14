Feature: Webmentions Type Tags
  Rendering of webmentions and types: bookmarks | likes | links | posts | replies | reposts | rsvps tags

  Scenario Outline: Rendering a Type Tag
    Given I have an "index.md" page that contains <tag>
    And I have a fixture configuration file
    When I run jekyll build
    Then I should get a zero exit status
    And the _site directory should exist
    And I should see <markup> in "_site/index.html"

  Examples:
    | tag                                   | markup                                             |
    | "{% webmentions page.url %}"          | "<div class="webmentions">"                        |
    | "{% webmention_bookmarks page.url %}" | "<div class="webmentions webmentions--bookmarks">" |
    | "{% webmention_likes page.url %}"     | "<div class="webmentions webmentions--likes">"     |
    | "{% webmention_links page.url %}"     | "<div class="webmentions webmentions--links">"     |
    | "{% webmention_posts page.url %}"     | "<div class="webmentions webmentions--posts">"     |
    | "{% webmention_replies page.url %}"   | "<div class="webmentions webmentions--replies">"   |
    | "{% webmention_reposts page.url %}"   | "<div class="webmentions webmentions--reposts">"   |
    | "{% webmention_rsvps page.url %}"     | "<div class="webmentions webmentions--rsvps">"     |
