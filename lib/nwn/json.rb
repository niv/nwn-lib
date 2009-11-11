require 'json'
require 'iconv'

module NWN::Gff::Struct
  def to_json(*a)
    box(proc {|x| NWN::JSON::GffToUtf8.iconv(x) }).to_json(*a)
  end
end

module NWN::Gff::Field
  def to_json(*a)
    box(proc {|x| NWN::JSON::GffToUtf8.iconv(x) }).to_json(*a)
  end
end

module NWN::Gff::JSON
  GffToUtf8 = Iconv.new('utf-8', 'iso8859-1')
  Utf8ToGff = Iconv.new('iso8859-1', 'utf-8')

  def self.load io
    json = if io.respond_to?(:to_str)
      io.to_str
    elsif io.respond_to?(:to_io)
      io.to_io.read
    else
      io.read
    end

    NWN::Gff::Struct.unbox!(JSON.parse(json), nil, proc {|x| Utf8ToGff.iconv(x) })
  end

  def self.dump struct
    JSON.pretty_generate(struct)
  end
end
