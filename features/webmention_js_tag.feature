Feature: Webmentions JS Tag

  Scenario: Rendering the Webmention JavaScript Tag with default configuration
    Given I have an "index.md" page that contains "{% webmentions_js %}"
    And I have a fixture configuration file
    When I run jekyll build
    Then I should get a zero exit status
    And the _site directory should exist
    And the "_site/js/JekyllWebmentionIO.js" file should exist
    And I should see "/js/JekyllWebmentionIO.js\" async=\"\"></script>" in "_site/index.html"

  Scenario: Rendering the Webmention JavaScript Tag with custom configuration
    Given I have an "index.md" page that contains "{% webmentions_js %}"
    And I have a fixture configuration file with subkey "js" set to:
    | key         | value       |
    | destination | _javascript |
    | uglify      | false       |
    | deploy      | false       |
    When I run jekyll build
    Then I should get a zero exit status
    And the _site directory should exist
    And the "_site/js/JekyllWebmentionIO.js" file should not exist
    And the "_site/_javascript/JekyllWebmentionIO.js" file should not exist
    And I should not see "<script src" in "_site/index.html"
