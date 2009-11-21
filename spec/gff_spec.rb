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
    :json => %w{json},
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

  NWN::Gff::OutputFormats.keys.each do |fmt|
    it "#{fmt} writes to io and returns the number of written bytes" do
      t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
      out = StringIO.new
      v = Gff.write(out, fmt, t)
      v.should == out.pos
    end
  end

  (NWN::Gff::OutputFormats.keys & NWN::Gff::InputFormats.keys).each do |fmt|
    it "#{fmt} fails on not enough data" do
      proc {
        gff = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
        out = StringIO.new
        Gff.write(out, fmt, gff)
        size = out.pos
        out.seek(0)
        out.truncate(size - 20)
        Gff.read(out, fmt)
      }.should raise_error
    end

  end

end
