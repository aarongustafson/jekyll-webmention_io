# frozen_string_literal: true

#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io
#  Licence : MIT
#
#  this liquid plugin insert a webmention into your Octopress or Jekyll blog
#  using http://webmention.io/ and the following syntax:
#
module Jekyll
  module WebmentionIO
    class WebmentionItem
      attr_reader :id, :hash

      def initialize(mention)
        @raw = mention

        @uri = determine_uri
        @source = determine_source
        @id = determine_id
        @type = determine_type
      end

      def to_hash
        gather_content

        the_hash = {
          "id"      => @id,
          "uri"     => @uri,
          "source"  => @source,
          "pubdate" => @pubdate,
          "raw"     => @raw,
          "author"  => @author,
          "type"    => @type,
        }

        the_hash["title"] = @title if @title
        the_hash["content"] = @content || ""

        the_hash
      end

      private

      def gather_content
        @pubdate = determine_pubdate
        @author = determine_author
        @title = determine_title
        @content = determine_content
      end

      def determine_uri
        @raw["data"]["url"] || @raw["source"]
      end

      def determine_source
        if @uri.include? "twitter.com/"
          "twitter"
        elsif @uri.include? "/googleplus/"
          "googleplus"
        else
          false
        end
      end

      def determine_id
        id = @raw["id"].to_s
        if @source == "twitter" && !@uri.include?("#favorited-by")
          id = URI(@uri).path.split("/").last.to_s
        end
        unless id
          time = Time.now
          id = time.strftime("%s").to_s
        end
        id
      end

      def determine_type
        type = @raw.dig("activity", "type")
        unless type
          type = "post"
          if @source == "googleplus"
            type = if @uri.include? "/like/"
                     "like"
                   elsif @uri.include? "/repost/"
                     "repost"
                   elsif @uri.include? "/comment/"
                     "reply"
                   else
                     "link"
                   end
          end
        end
        type
      end

      def determine_pubdate
        pubdate = @raw.dig("data", "published_ts")
        if pubdate
          pubdate = Time.at(pubdate)
        elsif @raw["verified_date"]
          pubdate = Time.parse(@raw["verified_date"])
        end
        pubdate
      end

      def determine_author
        @raw.dig("data", "author")
      end

      def determine_title
        title = false

        if @type == "post"

          html_source = WebmentionIO.webmentions.get_body_from_uri(@uri)
          unless html_source
            return title
          end

          unless html_source.valid_encoding?
            html_source = html_source.encode("UTF-16be", :invalid => :replace, :replace => "?").encode("UTF-8")
          end

          # Check the `title` first
          matches = /<title>(.*)<\/title>/.match(html_source)
          if matches
            title = matches[1].strip
          else
            # Fall back to the first `h1`
            matches = /<h1>(.*)<\/h1>/.match(html_source)
            title = if matches
                      matches[1].strip
                    else
                      title = "No title available"
                    end
          end

          # cleanup
          title = title.gsub(/<\/?[^>]+?>/, "")
        elsif @type == "link" && @source != "twitter"

          name = @raw.dig("data", "name")
          title = name if name

        end # if post

        title
      end

      def determine_content
        if %w(post reply link).include? @type
          @raw.dig("data", "content")
        else
          @raw.dig("activity", "sentence_html")
        end
      end
    end
  end
end
