#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class CategoryPageGenerator < Generator
      safe true

      def generate(site)
        site.static_files << Jekyll::StaticFile.new(site, WEBMENTION_GEM_BASE_DIR, "", "webmention_io.js")
      end
    end

  end
end
