require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::*" do

  def wellformed_verify binary
    t = Gff::Reader.read(StringIO.new binary)
  end

  it "reads wellformed GFF data" do
    wellformed_verify WELLFORMED_GFF
  end

  it "reproduces correct GFF binary data" do
    t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
    v = Gff::Writer.dump(t)
    t2 = wellformed_verify v
    t2.should == t
  end

  it "writes to io and returns the number of written bytes" do
    t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
    out = StringIO.new
    v = Gff::Writer.dump(t, out)
    v.should == out.size
    out.seek(0)
    v = out.read(v)
    t2 = wellformed_verify v
    t2.should == t
  end

  it "fails on not enough data" do
    proc {wellformed_verify WELLFORMED_GFF[0 .. -2] }.should
      raise_error IOError, "cannot read list_indices"
  end

end
