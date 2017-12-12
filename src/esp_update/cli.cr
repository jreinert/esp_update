require "./options"

module EspUpdate
  module Cli
    def self.parse_options
      options = Options.new

      option_parser = OptionParser.new do |parser|
        parser.banner = "Usage: #{PROGRAM_NAME} [options]"

        parser.on(
          "-d PATH", "--bindir PATH",
          "Path to directory with firmware blobs (defaults to current directory)"
        ) do |path|
          options.bindir = path
        end

        parser.on(
          "-h HOST", "--host HOST",
          "Listen on this host (defaults to localhost)"
        ) do |host|
          options.host = host
        end

        parser.on(
          "-p PORT", "--port PORT",
          "Listen on this port (defaults to 3000)"
        ) do |port|
          options.port = port.to_i
        end

        parser.on("-v", "--version", "Print out version") do
          puts EspUpdate::VERSION
          exit
        end

        parser.on("-?", "--help", "Show this message") do
          puts parser
          exit
        end
      end

      option_parser.parse!
      options
    rescue e : Exception
      raise [e.message, option_parser.to_s].join("\n")
    end
  end
end
