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

module NWN::Gff::Handler::JSON
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
    d = if NWN.setting(:pretty_json)
      d = ::JSON.pretty_generate(struct)
      io.puts d
      d.size
    else
      d = ::JSON.generate(struct)
      io.print d
      d.size
    end
  end
end

NWN::Gff::Handler.register :json, /^json$/, NWN::Gff::Handler::JSON
