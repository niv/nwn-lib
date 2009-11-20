require File.join(File.dirname(__FILE__), 'spec_helper')

unless Gff::InputFormats[:json] && Gff::OutputFormats[:json]
  $stderr.puts "Partial or no json support, not running json specs!"
else

describe "JSON support" do
  def read_write
    g = Gff.read(StringIO.new(WELLFORMED_GFF), :gff)
    out = StringIO.new
    j = Gff.write(out, :json, g)
    out.seek(0)
    gg = Gff.read(out, :json)
  end

  it "read/writes correctly" do
    NWN.setting(:pretty_json, 0)
    read_write
  end

  it "pretty-read/writes correctly" do
    NWN.setting(:pretty_json, 1)
    read_write
  end
end

end
