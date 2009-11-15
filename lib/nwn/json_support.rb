require 'json'

module NWN::Gff::Struct
  def to_json(*a)
    box.to_json(*a)
  end
end

module NWN::Gff::Field
  def to_json(*a)
    box.to_json(*a)
  end
end

module NWN::Gff::JSON
  def self.load io
    json = if io.respond_to?(:to_str)
      io.to_str
    elsif io.respond_to?(:to_io)
      io.to_io.read
    else
      io.read
    end

    NWN::Gff::Struct.unbox!(JSON.parse(json), nil)
  end

  def self.dump struct, io
    if NWN.setting(:pretty_json)
      io.puts JSON.pretty_generate(struct)
    else
      io.print JSON.generate(struct)
    end
  end
end

NWN::Gff.register_format_handler :json, /^json$/, NWN::Gff::JSON
