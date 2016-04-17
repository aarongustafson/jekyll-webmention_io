#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT

module Jekyll
  module WebmentionIo

    class WebmentionCommand < Jekyll::Command
      class << self
        def init_with_program(p)
          p.command(:webmention) do |c|
            c.syntax "webmention"
            c.description 'Notify any mentioned URLs that offer webmention endpoints'

            c.action do |args, options|
              Jekyll.logger.warn "jekyll-webmention-io:", "TODO: Reimplement webmention.Rakefile in this command."
            end
          end
        end
      end
    end

  end
end
