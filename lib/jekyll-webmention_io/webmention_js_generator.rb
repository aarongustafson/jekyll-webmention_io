#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionIoJsFile < StaticFile
      def destination_rel_dir
        @site.config['jekyll-webmention-io']['js'] || "/assets/js/"
      end
    end

    class CategoryPageGenerator < Generator
      safe true

      def generate(site)
        site.static_files << Jekyll::WebmentionIo::WebmentionIoJsFile.new(site, WEBMENTION_GEM_BASE_DIR, "", "webmention_io.js")
      end
    end

  end
end
