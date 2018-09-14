Feature: Webmentions Head Tag

  Scenario: Rendering the Webmention Head Tag with default configuration
    Given I have an "index.md" page that contains "{% webmentions_head %}"
    And I have a fixture configuration file
    When I run jekyll build
    Then I should get a zero exit status
    And the _site directory should exist
    And I should see "<link rel=\"dns-prefetch\" href=\"https://webmention.io\" />" in "_site/index.html"
    And I should see "<link rel=\"preconnect\" href=\"https://webmention.io\" />" in "_site/index.html"
    And I should see "<link rel=\"preconnect\" href=\"ws://webmention.io:8080\" />" in "_site/index.html"

  Scenario: Rendering the Webmention Head Tag with custom configuration
    Given I have an "index.md" page that contains "{% webmentions_head %}"
    And I have a fixture configuration file with:
    | key      | value    |
    | username | John Doe |
    When I run jekyll build
    Then I should get a zero exit status
    And the _site directory should exist
    And I should see "<link rel=\"dns-prefetch\" href=\"https://webmention.io\" />" in "_site/index.html"
    And I should see "<link rel=\"preconnect\" href=\"https://webmention.io\" />" in "_site/index.html"
    And I should see "<link rel=\"preconnect\" href=\"ws://webmention.io:8080\" />" in "_site/index.html"
    And I should see "<link rel=\"pingback\" href=\"https://webmention.io/John Doe/xmlrpc\" />" in "_site/index.html"
    And I should see "<link rel=\"webmention\" href=\"https://webmention.io/John Doe/webmention\" />" in "_site/index.html"
