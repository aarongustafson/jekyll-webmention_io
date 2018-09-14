# frozen_string_literal: true

require "fileutils"
require "jekyll"
require "time"
require "safe_yaml/load"

class Paths
  SOURCE_DIR = Pathname.new(File.expand_path("../..", __dir__))

  def self.test_dir
    source_dir.join("tmp", "jekyll")
  end

  def self.output_file
    test_dir.join("jekyll_output.txt")
  end

  def self.status_file
    test_dir.join("jekyll_status.txt")
  end

  def self.source_dir
    SOURCE_DIR
  end
end

WEBMENTIONS_DEFAULT_CONF = YAML.load(<<~CONFIG)
baseurl: ""
url: https://www.aaron-gustafson.com
plugins: ["jekyll-webmention_io"]
webmentions:
  debug: false
  username: aarongustafson
  legacy_domains:
    - http://aaron-gustafson.com
    - http://www.aaron-gustafson.com
  cache_bad_urls_for: 1
  pages: true
CONFIG

def file_content_from_hash(input_hash)
  matter_hash = input_hash.reject { |k, _v| k == "content" }
  matter = matter_hash.map { |k, v| "#{k}: #{v}\n" }
  matter = matter.join.chomp
  content =
    if !input_hash["input"] || !input_hash["filter"]
      input_hash["content"]
    else
      "{{ #{input_hash["input"]} | #{input_hash["filter"]} }}"
    end

  Jekyll::Utils.strip_heredoc(<<-EOF)
    ---
    #{matter.gsub(%r!\n!, "\n    ")}
    ---
    #{content}
  EOF
end

def source_dir(*files)
  Paths.test_dir(*files)
end

def all_steps_to_path(path)
  dest = Pathname.new(path).expand_path
  paths = []

  dest.ascend do |f|
    break if f == source_dir
    paths.unshift f.to_s
  end

  paths
end

def jekyll_run_output
  Paths.output_file.read if Paths.output_file.file?
end

def jekyll_run_status
  Paths.status_file.read if Paths.status_file.file?
end

def run_bundle(args)
  run_in_shell("bundle", *args.strip.split(" "))
end

def run_rubygem(args)
  run_in_shell("gem", *args.strip.split(" "))
end

def run_jekyll(args)
  args = args.strip.split(" ") # Shellwords?
  process = run_in_shell("bundle", "exec", "jekyll", *args, "--trace")
  process.exitstatus.zero?
end

def run_in_shell(*args)
  p, output = Jekyll::Utils::Exec.run(*args)

  File.write(Paths.status_file, p.exitstatus)
  File.open(Paths.output_file, "wb") do |f|
    f.print "$ "
    f.puts args.join(" ")
    f.puts output
    f.puts "EXIT STATUS: #{p.exitstatus}"
  end
  p
end

def slug(title = nil)
  if title
    title.downcase.gsub(%r![^\w]!, " ").strip.gsub(%r!\s+!, "-")
  else
    Time.now.strftime("%s%9N") # nanoseconds since the Epoch
  end
end

def location(folder, direction)
  if folder
    before = folder if direction == "in"
    after  = folder if direction == "under"
  end

  [
    before || ".",
    after  || ".",
  ]
end

def file_contents(path)
  Pathname.new(path).read
end
