require "./esp_update/*"
require "kemal"
require "option_parser"
require "semantic_version"

module EspUpdate
  record(
    Options,
    bindir : String = ".", 
    host : String = "localhost",
    port : Int32 = 3000,
    ssl : Bool = false,
    ssl_cert : String? = nil,
    ssl_key : String? = nil
  ) { setter :bindir, :host, :port, :ssl, :ssl_cert, :ssl_key }

  options = Options.new

  option_parser = OptionParser.new do |parser|
    parser.banner = "Usage: #{$0} [options]"

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

    parser.on(
      "-s", "--use-ssl",
      "Use SSL (defaults to plain HTTP)"
    ) do
      options.ssl = true
    end

    parser.on(
      "-k PATH", "--ssl-key-file PATH",
      "SSL key File (required when using ssl)"
    ) do |path|
      options.ssl_key = path
    end

    parser.on(
      "-c PATH", "--ssl-cert-file PATH",
      "SSL cert file (required when using ssl)"
    ) do |path|
      options.ssl_cert = path
    end

    parser.on("-?", "--help", "Show this message") do
      puts parser
      exit
    end
  end

  begin
    option_parser.parse!
    raise "No SSL key file given" if options.ssl && !options.ssl_key
    raise "No SSL cert file given" if options.ssl && !options.ssl_cert
  rescue e
    puts e.message
    abort(option_parser)
  end

  error 404 do |context|
    context.response.puts "404 - Not Found"
  end

  get "/:project" do |context|
    project_dir = File.join(options.bindir, context.params.url["project"])
    blobs = Dir[File.join(project_dir, "*.bin")]

    unless blobs.any?
      context.response.status_code = 404
      next
    end

    version = SemanticVersion.parse(
      context.request.headers["HTTP_X_ESP8266_VERSION"]? || "0.0.0-0"
    )

    available_firmwares = {} of SemanticVersion => String

    blobs.each do |file|
      blob_version = SemanticVersion.parse(File.basename(file, ".bin"))
      available_firmwares[blob_version] = file
    end

    latest_version = available_firmwares.keys.max

    if latest_version <= version
      context.response.status_code = 304
      next
    end

    blob = available_firmwares[latest_version]
    context.response.content_type = "application/octet-stream"
    context.response.content_length = File.size(blob)

    File.open(blob) do |file|
      IO.copy(file, context.response)
    end
  end

  Kemal.config.tap do |config|
    config.host_binding = options.host
    config.port = options.port
    if options.ssl
      ssl = Kemal::SSL.new
      ssl.key_file = options.ssl_key.not_nil!
      ssl.cert_file = options.ssl_cert.not_nil!
      config.ssl = ssl.context
    end
  end

  Kemal.run
end
