require "./esp_update/*"
require "kemal"
require "option_parser"
require "semantic_version"
require "digest"

module EspUpdate
  @@options : Options?

  def self.options
    @@options ||= Cli.parse_options
  rescue e
    abort(e)
  end

  def self.md5_digest(file)
    digest = Digest::MD5.digest do |ctx|
      buffer = Bytes.new(4096)
      File.open(file) do |f|
        while (bytes_read = f.read(buffer)) > 0
          ctx.update(buffer[0, bytes_read])
        end
      end
    end

    digest.to_slice.hexstring
  end

  enum UpdateType
    Firmware
    Spiffs
  end

  def self.handle_update(context, type : UpdateType)
    project_dir = File.join(options.bindir, context.params.url["project"])
    blobs = case type
            when UpdateType::Firmware
              Dir[File.join(project_dir, "*.fw.bin")]
            else UpdateType
              Dir[File.join(project_dir, "*.spiffs.bin")]
            end

    version = SemanticVersion.parse(
      context.request.headers["x-ESP8266-version"]? || "0.0.0-0"
    )

    available_firmwares = {} of SemanticVersion => String

    blobs.each do |file|
      version_string = File.basename(file)[/.*(?=(?:\.fw|\.spiffs)\.bin)/]
      blob_version = SemanticVersion.parse(version_string)
      available_firmwares[blob_version] = file
    end

    if available_firmwares.empty?
      context.response.status_code = 404
      return
    end

    latest_version = available_firmwares.keys.max

    if latest_version <= version
      context.response.status_code = 304
      return
    end

    blob = available_firmwares[latest_version]
    context.response.headers["x-MD5"] = md5_digest(blob)
    context.response.content_length = File.size(blob)
    filename = [context.params.url["project"], File.basename(blob)].join('_')
    context.response.headers["Content-Disposition"] =
      "attachment; filename=#{filename}"

    send_file(context, blob)
  end

  error 404 do |context|
    context.response.puts "404 - Not Found"
  end

  get "/:project/spiffs" do |context|
    handle_update(context, UpdateType::Spiffs)
  end

  get "/:project" do |context|
    handle_update(context, UpdateType::Firmware)
  end

  Kemal.config.tap do |config|
    config.host_binding = options.host
    config.port = options.port
  end

  Kemal.run
end
