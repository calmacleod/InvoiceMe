require "zip"

class OdtDocument
  MIME = "application/vnd.oasis.opendocument.text"
  LOGO = Rails.root.join("app/assets/images/eotfoa-logo.jpg")

  def self.package(content, styles:)
    manifest = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">
        <manifest:file-entry manifest:full-path="/" manifest:media-type="#{MIME}"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="Pictures/logo.jpg" manifest:media-type="image/jpeg"/>
      </manifest:manifest>
    XML
    files = {
      "mimetype" => MIME, "content.xml" => content, "styles.xml" => styles,
      "Pictures/logo.jpg" => LOGO.binread, "META-INF/manifest.xml" => manifest
    }
    Zip::OutputStream.write_buffer(suppress_extra_fields: true) do |zip|
      files.each do |name, bytes|
        entry = Zip::Entry.new("", name)
        # ODF requires mimetype first, uncompressed, with no ZIP extra fields.
        entry.size = bytes.bytesize
        entry.compression_method = name == "mimetype" ? Zip::Entry::STORED : Zip::Entry::DEFLATED
        zip.put_next_entry(entry)
        zip.write bytes
      end
    end.string
  end
end
