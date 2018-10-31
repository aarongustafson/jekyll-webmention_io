# Change Log

## [v3.3.2](https://github.com/aarongustafson/jekyll-webmention_io/tree/v3.3.2) (2018-10-29)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v3.3.1...v3.3.2)

**Bugs fixed:**

- Titles should not be in markdown ([5987234](https://github.com/aarongustafson/jekyll-webmention_io/commit/598723481546967c2ace08f69cf9cf386bdf06e6))

**Implemented enhancements:**

- Added `rel="nofollow"` to default templates to discourage link-farming via webmentions ([f46803](https://github.com/aarongustafson/jekyll-webmention_io/commit/f46803a01f871bc9b01a070b43506774ee841fc3))
- Added a note on testing ([58a0f3c](https://github.com/aarongustafson/jekyll-webmention_io/commit/58a0f3c1764cac84111666e888ae761a8d04524c))

## [v3.3.1](https://github.com/aarongustafson/jekyll-webmention_io/tree/v3.3.1) (2018-10-06)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v3.3.0...v3.3.1)

**Bugs fixed:**

- Some titles went missing when posts came through as links ([e2ff131](https://github.com/aarongustafson/jekyll-webmention_io/commit/e2ff131ec951189f99957f81b88609710fe551ba))

## [v3.3.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v3.3.0) (2018-10-05)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v3.1.0...v3.3.0)

**Closed issues:**

- Issue with Webmention command [\#115](https://github.com/aarongustafson/jekyll-webmention_io/issues/115)
- Nest all generators consistently under `Jekyll::WebmentionIO` namespace [\#104](https://github.com/aarongustafson/jekyll-webmention_io/issues/104)
- Performance impact on build [\#81](https://github.com/aarongustafson/jekyll-webmention_io/issues/81)

**Merged pull requests:**

- Bootstrap WebmentionIO with webmention command [\#116](https://github.com/aarongustafson/jekyll-webmention_io/pull/116) ([ashmaroli](https://github.com/ashmaroli))
- Add missing e [\#114](https://github.com/aarongustafson/jekyll-webmention_io/pull/114) ([jamietanna](https://github.com/jamietanna))
- Remove unused dependency [\#113](https://github.com/aarongustafson/jekyll-webmention_io/pull/113) ([ashmaroli](https://github.com/ashmaroli))
- Require Ruby 2.3.0 and beyond [\#112](https://github.com/aarongustafson/jekyll-webmention_io/pull/112) ([ashmaroli](https://github.com/ashmaroli))
- Drop support for outdated Jekyll versions [\#111](https://github.com/aarongustafson/jekyll-webmention_io/pull/111) ([ashmaroli](https://github.com/ashmaroli))
- Use `private\_class\_method` to hide class methods [\#110](https://github.com/aarongustafson/jekyll-webmention_io/pull/110) ([ashmaroli](https://github.com/ashmaroli))
- Custom template should be within site source [\#109](https://github.com/aarongustafson/jekyll-webmention_io/pull/109) ([ashmaroli](https://github.com/ashmaroli))
- Nest generators under the WebmentionIO module [\#108](https://github.com/aarongustafson/jekyll-webmention_io/pull/108) ([ashmaroli](https://github.com/ashmaroli))
- Stringify config\["url"\] and config\["baseurl"\] [\#106](https://github.com/aarongustafson/jekyll-webmention_io/pull/106) ([ashmaroli](https://github.com/ashmaroli))
- Optimize by caching webmention data into memory [\#105](https://github.com/aarongustafson/jekyll-webmention_io/pull/105) ([ashmaroli](https://github.com/ashmaroli))
- Add basic Cucumber tests to assess rendering tags [\#103](https://github.com/aarongustafson/jekyll-webmention_io/pull/103) ([ashmaroli](https://github.com/ashmaroli))
- Use shorter name for constants from plugin module [\#102](https://github.com/aarongustafson/jekyll-webmention_io/pull/102) ([ashmaroli](https://github.com/ashmaroli))

## [v3.1.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v3.1.0) (2018-09-14)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v3.0.0...v3.1.0)

**Closed issues:**

- Optimize JS tag by generating the `template` markup once? [\#99](https://github.com/aarongustafson/jekyll-webmention_io/issues/99)
- `display:none` showing for `templates` in DevTools. Confused on how to use this [\#85](https://github.com/aarongustafson/jekyll-webmention_io/issues/85)

**Merged pull requests:**

- Stringify site.config\["url"\] [\#101](https://github.com/aarongustafson/jekyll-webmention_io/pull/101) ([ashmaroli](https://github.com/ashmaroli))
- Render WebmentionJSTag with a dedicated class [\#100](https://github.com/aarongustafson/jekyll-webmention_io/pull/100) ([ashmaroli](https://github.com/ashmaroli))

## [v3.0.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v3.0.0) (2018-09-10)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.7...v3.0.0)

**Merged pull requests:**

- Add WebmentionType superclass for webmention types [\#98](https://github.com/aarongustafson/jekyll-webmention_io/pull/98) ([ashmaroli](https://github.com/ashmaroli))
- Lint use of private access modifier [\#97](https://github.com/aarongustafson/jekyll-webmention_io/pull/97) ([ashmaroli](https://github.com/ashmaroli))
- Improve handling cache folder and cache file paths [\#96](https://github.com/aarongustafson/jekyll-webmention_io/pull/96) ([ashmaroli](https://github.com/ashmaroli))
- Add utility method to safely parse YAML files [\#95](https://github.com/aarongustafson/jekyll-webmention_io/pull/95) ([ashmaroli](https://github.com/ashmaroli))

## [v2.9.7](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.7) (2018-09-04)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.6...v2.9.7)

**Closed issues:**

- "\[jekyll-webmention\_io\] Liquid error: internal" error when using includes in Webmention templates [\#83](https://github.com/aarongustafson/jekyll-webmention_io/issues/83)

**Merged pull requests:**

- Render in the context of the template [\#94](https://github.com/aarongustafson/jekyll-webmention_io/pull/94) ([ashmaroli](https://github.com/ashmaroli))
- Simplify defining getters and setters [\#93](https://github.com/aarongustafson/jekyll-webmention_io/pull/93) ([ashmaroli](https://github.com/ashmaroli))
- The name's Jekyll.. [\#92](https://github.com/aarongustafson/jekyll-webmention_io/pull/92) ([ashmaroli](https://github.com/ashmaroli))
- Add utility method to dump data as YAML into file [\#91](https://github.com/aarongustafson/jekyll-webmention_io/pull/91) ([ashmaroli](https://github.com/ashmaroli))
- Improve readability of main module [\#90](https://github.com/aarongustafson/jekyll-webmention_io/pull/90) ([ashmaroli](https://github.com/ashmaroli))
- Freeze string literals to improve performance [\#89](https://github.com/aarongustafson/jekyll-webmention_io/pull/89) ([ashmaroli](https://github.com/ashmaroli))
- Use shorter name for superclass [\#88](https://github.com/aarongustafson/jekyll-webmention_io/pull/88) ([ashmaroli](https://github.com/ashmaroli))
- set\_data in tags with @template\_name as type [\#87](https://github.com/aarongustafson/jekyll-webmention_io/pull/87) ([ashmaroli](https://github.com/ashmaroli))

## [v2.9.6](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.6) (2018-08-31)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.5...v2.9.6)

## [v2.9.5](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.5) (2018-08-31)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.3...v2.9.5)

**Closed issues:**

- Throttling doesn't apply to posts without webmentions [\#84](https://github.com/aarongustafson/jekyll-webmention_io/issues/84)

**Merged pull requests:**

- Full throttle [\#86](https://github.com/aarongustafson/jekyll-webmention_io/pull/86) ([aarongustafson](https://github.com/aarongustafson))

## [v2.9.3](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.3) (2018-06-29)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.2...v2.9.3)

**Closed issues:**

- Don't collect outgoing mentions from localhost [\#82](https://github.com/aarongustafson/jekyll-webmention_io/issues/82)

## [v2.9.2](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.2) (2018-06-28)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.1...v2.9.2)

**Closed issues:**

- undefined local variable or method `original\_uri' for Jekyll::WebmentionIO:Module [\#79](https://github.com/aarongustafson/jekyll-webmention_io/issues/79)
- Update uglifier dependency [\#78](https://github.com/aarongustafson/jekyll-webmention_io/issues/78)

**Merged pull requests:**

- \(deps\) Bump uglifier to 4.x [\#80](https://github.com/aarongustafson/jekyll-webmention_io/pull/80) ([DirtyF](https://github.com/DirtyF))

## [v2.9.1](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.1) (2018-02-26)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.9.0...v2.9.1)

## [v2.9.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.9.0) (2018-02-26)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.5...v2.9.0)

**Implemented enhancements:**

- Add support for RSVP [\#76](https://github.com/aarongustafson/jekyll-webmention_io/issues/76)
- Add support for "bookmark" type. [\#67](https://github.com/aarongustafson/jekyll-webmention_io/issues/67)

**Closed issues:**

- Fails to compile [\#75](https://github.com/aarongustafson/jekyll-webmention_io/issues/75)
- \[error\] Failed to open TCP connection to webmention.io:443 [\#74](https://github.com/aarongustafson/jekyll-webmention_io/issues/74)
- SSL issue [\#72](https://github.com/aarongustafson/jekyll-webmention_io/issues/72)

## [v2.8.5](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.5) (2017-12-01)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.4...v2.8.5)

**Merged pull requests:**

- Bugfix for \#72 [\#73](https://github.com/aarongustafson/jekyll-webmention_io/pull/73) ([aarongustafson](https://github.com/aarongustafson))

## [v2.8.4](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.4) (2017-09-25)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.3...v2.8.4)

**Merged pull requests:**

- Define path with \_\_dir\_\_ [\#69](https://github.com/aarongustafson/jekyll-webmention_io/pull/69) ([DirtyF](https://github.com/DirtyF))

## [v2.8.3](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.3) (2017-09-12)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.2...v2.8.3)

## [v2.8.2](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.2) (2017-09-08)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.1...v2.8.2)

**Closed issues:**

- Error when building: "NoMethodError: undefined method `empty?' for nil:NilClass" [\#65](https://github.com/aarongustafson/jekyll-webmention_io/issues/65)
- Don't break when a mentioned website doesn't respond [\#61](https://github.com/aarongustafson/jekyll-webmention_io/issues/61)

**Merged pull requests:**

- Bugfixes 2017 09 08 [\#68](https://github.com/aarongustafson/jekyll-webmention_io/pull/68) ([aarongustafson](https://github.com/aarongustafson))

## [v2.8.1](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.1) (2017-09-08)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.8.0...v2.8.1)

**Merged pull requests:**

- Attempting to fix issue \#65 [\#66](https://github.com/aarongustafson/jekyll-webmention_io/pull/66) ([aarongustafson](https://github.com/aarongustafson))

## [v2.8.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.8.0) (2017-08-25)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.7.0...v2.8.0)

**Merged pull requests:**

- Inherit Jekyll's rubocop config for consistency [\#64](https://github.com/aarongustafson/jekyll-webmention_io/pull/64) ([DirtyF](https://github.com/DirtyF))

## [v2.7.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.7.0) (2017-08-17)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.6.4...v2.7.0)

**Merged pull requests:**

- Throttle lookups [\#62](https://github.com/aarongustafson/jekyll-webmention_io/pull/62) ([aarongustafson](https://github.com/aarongustafson))

## [v2.6.4](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.6.4) (2017-08-17)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.6.3...v2.6.4)

**Closed issues:**

- Unable to use my own "likes" template [\#60](https://github.com/aarongustafson/jekyll-webmention_io/issues/60)
- Make webmentions\_count a "real" number [\#57](https://github.com/aarongustafson/jekyll-webmention_io/issues/57)
- Standardize naming of liquid tags [\#55](https://github.com/aarongustafson/jekyll-webmention_io/issues/55)
- How to show a webmention without any content? [\#54](https://github.com/aarongustafson/jekyll-webmention_io/issues/54)

**Merged pull requests:**

- Adding settings for CSP when using the JavaScript enhancement [\#59](https://github.com/aarongustafson/jekyll-webmention_io/pull/59) ([nhoizey](https://github.com/nhoizey))
- Jekyll needs the ":jekyll\_plugins" group in the Gemfile [\#58](https://github.com/aarongustafson/jekyll-webmention_io/pull/58) ([nhoizey](https://github.com/nhoizey))

## [v2.6.3](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.6.3) (2017-08-08)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.6.2...v2.6.3)

**Closed issues:**

- \[2.6.2\] NoMethodError: undefined method `\[\]' for nil:NilClass [\#53](https://github.com/aarongustafson/jekyll-webmention_io/issues/53)

**Merged pull requests:**

- Another little typo [\#52](https://github.com/aarongustafson/jekyll-webmention_io/pull/52) ([nhoizey](https://github.com/nhoizey))
- Typo [\#51](https://github.com/aarongustafson/jekyll-webmention_io/pull/51) ([nhoizey](https://github.com/nhoizey))

## [v2.6.2](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.6.2) (2017-08-01)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.6.1...v2.6.2)

**Merged pull requests:**

- Various minor updates [\#50](https://github.com/aarongustafson/jekyll-webmention_io/pull/50) ([stuartbreckenridge](https://github.com/stuartbreckenridge))

## [v2.6.1](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.6.1) (2017-07-31)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.6.0...v2.6.1)

**Closed issues:**

- \[2.6.0\] NoMethodError: undefined method `\[\]' for nil:NilClass [\#46](https://github.com/aarongustafson/jekyll-webmention_io/issues/46)

**Merged pull requests:**

- Bugfixes 2017 07 31 [\#49](https://github.com/aarongustafson/jekyll-webmention_io/pull/49) ([aarongustafson](https://github.com/aarongustafson))
- Just a little typo… [\#45](https://github.com/aarongustafson/jekyll-webmention_io/pull/45) ([nhoizey](https://github.com/nhoizey))

## [v2.6.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.6.0) (2017-07-20)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.5.1...v2.6.0)

**Merged pull requests:**

- Added ability to keep the Gem from putting the JS file in your source… [\#44](https://github.com/aarongustafson/jekyll-webmention_io/pull/44) ([aarongustafson](https://github.com/aarongustafson))

## [v2.5.1](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.5.1) (2017-07-19)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.5.0...v2.5.1)

**Implemented enhancements:**

- JekyllWebmentionIO.js, why source folder? [\#41](https://github.com/aarongustafson/jekyll-webmention_io/issues/41)

**Fixed bugs:**

- bundler: failed to load command: jekyll [\#42](https://github.com/aarongustafson/jekyll-webmention_io/issues/42)
- Bug: NoMethodError: undefined method `\[\]' for nil:NilClass [\#40](https://github.com/aarongustafson/jekyll-webmention_io/issues/40)
- Bugfixes for this week [\#43](https://github.com/aarongustafson/jekyll-webmention_io/pull/43) ([aarongustafson](https://github.com/aarongustafson))

**Closed issues:**

- Quickstart guide in readme? [\#39](https://github.com/aarongustafson/jekyll-webmention_io/issues/39)

## [v2.5.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.5.0) (2017-07-07)
[Full Changelog](https://github.com/aarongustafson/jekyll-webmention_io/compare/v2.3.0...v2.5.0)

**Implemented enhancements:**

- Store response data from sent webmentions [\#30](https://github.com/aarongustafson/jekyll-webmention_io/issues/30)

**Closed issues:**

- Integrate `since\_id` [\#36](https://github.com/aarongustafson/jekyll-webmention_io/issues/36)

**Merged pull requests:**

- Added support for `since\_id` to reduce the processing time. Fixes \#36. [\#38](https://github.com/aarongustafson/jekyll-webmention_io/pull/38) ([aarongustafson](https://github.com/aarongustafson))
- Log webmention responses [\#37](https://github.com/aarongustafson/jekyll-webmention_io/pull/37) ([aarongustafson](https://github.com/aarongustafson))

## [v2.3.0](https://github.com/aarongustafson/jekyll-webmention_io/tree/v2.3.0) (2017-07-05)
**Implemented enhancements:**

- Add webmention.io link tag [\#32](https://github.com/aarongustafson/jekyll-webmention_io/issues/32)
- Optimize avatars [\#24](https://github.com/aarongustafson/jekyll-webmention_io/issues/24)
- Error Checking if wm.io down [\#15](https://github.com/aarongustafson/jekyll-webmention_io/issues/15)
- Rework webmention rakefile as a command/hook? [\#7](https://github.com/aarongustafson/jekyll-webmention_io/issues/7)
- Publish to rubygems.org [\#3](https://github.com/aarongustafson/jekyll-webmention_io/issues/3)
- Add parameters to only display webmentions of a certain type [\#2](https://github.com/aarongustafson/jekyll-webmention_io/issues/2)

**Closed issues:**

- Bring back the JS [\#28](https://github.com/aarongustafson/jekyll-webmention_io/issues/28)
- \(optionaly?\) generate Jekyll data files with webmentions [\#25](https://github.com/aarongustafson/jekyll-webmention_io/issues/25)
- Jekyll isn’t finding the gem when bundled from RubyGems [\#22](https://github.com/aarongustafson/jekyll-webmention_io/issues/22)
- Error:  incompatible character encodings: UTF-8 and ASCII-8BIT [\#18](https://github.com/aarongustafson/jekyll-webmention_io/issues/18)
- Jekyll 3.3 breaks webmention caching [\#17](https://github.com/aarongustafson/jekyll-webmention_io/issues/17)
- Suggestion on Storing Webmention Response? [\#16](https://github.com/aarongustafson/jekyll-webmention_io/issues/16)
- Ability to parse more than markdown file for links? [\#14](https://github.com/aarongustafson/jekyll-webmention_io/issues/14)
- Rake task will download entire file looking for webmention endpoint [\#12](https://github.com/aarongustafson/jekyll-webmention_io/issues/12)
- Vulnerability: curl usage allows command injection via url/a\_photo [\#10](https://github.com/aarongustafson/jekyll-webmention_io/issues/10)
- Jekyll 3.1 error:  Liquid Exception: undefined method `getConverterImpl' [\#6](https://github.com/aarongustafson/jekyll-webmention_io/issues/6)
- "Liquid Exception: Socket is not connected" [\#5](https://github.com/aarongustafson/jekyll-webmention_io/issues/5)

**Merged pull requests:**

- Integrate webmentions gem [\#35](https://github.com/aarongustafson/jekyll-webmention_io/pull/35) ([aarongustafson](https://github.com/aarongustafson))
- Add link tags [\#34](https://github.com/aarongustafson/jekyll-webmention_io/pull/34) ([aarongustafson](https://github.com/aarongustafson))
- Javascript rewrite [\#33](https://github.com/aarongustafson/jekyll-webmention_io/pull/33) ([aarongustafson](https://github.com/aarongustafson))
- Merging in the gem\_conversion branch as it is no longer needed [\#27](https://github.com/aarongustafson/jekyll-webmention_io/pull/27) ([aarongustafson](https://github.com/aarongustafson))
- Use Jekyll's soon to be \(let's hope\) default cache folder [\#26](https://github.com/aarongustafson/jekyll-webmention_io/pull/26) ([nhoizey](https://github.com/nhoizey))
- Create CODE\_OF\_CONDUCT.md [\#23](https://github.com/aarongustafson/jekyll-webmention_io/pull/23) ([aarongustafson](https://github.com/aarongustafson))
- Gem conversion [\#21](https://github.com/aarongustafson/jekyll-webmention_io/pull/21) ([aarongustafson](https://github.com/aarongustafson))
- Fix @site -\> site [\#8](https://github.com/aarongustafson/jekyll-webmention_io/pull/8) ([0xdevalias](https://github.com/0xdevalias))
- require statements for yaml and net/http [\#1](https://github.com/aarongustafson/jekyll-webmention_io/pull/1) ([eminaksehirli](https://github.com/eminaksehirli))

----

*This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*