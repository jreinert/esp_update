require "./esp_update/*"
require "kemal"
require "option_parser"
require "semantic_version"
require "digest"

module EspUpdate
  begin
    options = Cli.parse_options
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
      context.request.headers["x-ESP8266-version"]? || "0.0.0-0"
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
    context.response.headers["x-MD5"] = md5_digest(blob)
    context.response.content_length = File.size(blob)
    filename = [context.params.url["project"], File.basename(blob)].join('_')
    context.response.headers["Content-Disposition"] =
      "attachment; filename=#{filename}"

    send_file(context, blob)
  end

  Kemal.config.tap do |config|
    config.host_binding = options.host
    config.port = options.port
  end

  Kemal.run
end
