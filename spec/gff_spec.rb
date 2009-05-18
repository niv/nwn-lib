require File.join(File.dirname(__FILE__), 'spec_helper')

WELLFORMED_GFF = IO.read(File.dirname(__FILE__) + "/wellformed_gff.binary").freeze

describe "Gff::*" do

  def wellformed_verify binary
    t = Gff::Reader.read(binary)
  end

  it "reads wellformed GFF data" do
    wellformed_verify WELLFORMED_GFF
  end

  it "reproduces correct GFF binary data" do
    t = Gff::Reader.read(WELLFORMED_GFF)
    v = Gff::Writer.dump(t)
    t2 = wellformed_verify v
    t2.should == t
  end

end
