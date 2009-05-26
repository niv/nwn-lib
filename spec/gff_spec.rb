require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff.read/write API" do
  it "reads correctly" do
    i = StringIO.new WELLFORMED_GFF
    g = Gff.read(i, :gff)
  end

  it "writes correctly" do
    i = StringIO.new WELLFORMED_GFF
    gff = Gff.read(i, :gff)

    out = StringIO.new
    ret = Gff.write(out, :gff, gff)
    ret.should == out.size
  end

  {
    :gff => %w{utc utd ute uti utm utp uts utt utw git are gic mod ifo fac ssf dlg itp bic},
    :yaml => %w{yml yaml},
    :kivinen => %w{k kivinen},
    :marshal => %w{marshal}
  }.each {|expect, arr|
    arr.each {|ext|
      it "guesses the file format #{expect} for extension #{ext} correctly" do
        Gff.guess_file_format("xxy.#{ext}").should == expect
      end
    }
  }
end

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
    proc {
      wellformed_verify WELLFORMED_GFF[0 .. -2]
    }.should raise_error IOError
  end

end
