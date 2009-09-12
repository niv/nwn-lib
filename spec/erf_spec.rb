require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Erf::Erf", :shared => true do
  def wellformed_verify binary, expect_locstr = true
    t = Erf::Erf.new(StringIO.new binary)

    t.file_type.should == "HAK"
    if expect_locstr
      t.localized_strings.should == {0 => "abcdef"}
    else
      t.localized_strings.should == {}
    end
    t.content.size.should == 3
    t.year.should == 100
    t.day_of_year.should == 126
    t.description_str_ref.should == 0xdeadbeef

    t.content[0].filename.should == "resref.txt"
    t.content[1].filename.should == "help.bmp"
    t.content[2].filename.should == "yegods.wav"
    t.content[0].size.should == 6
    t.content[1].size.should == 4
    t.content[2].size.should == 6
    t.content[0].get.should == "resref"
    t.content[1].get.should == "help"
    t.content[2].get.should == "yegods"
  end

  it "reads wellformed ERF containers" do
    wellformed_verify @erf
  end

  it "sets the correct default parameters" do
    t = Erf::Erf.new
    t.year.should == Time.now.year - 1900
    t.day_of_year.should == Time.now.yday
    t.content.size.should == 0
  end

  it "reproduces correct ERF binary data" do
    t = Erf::Erf.new(StringIO.new @erf)
    io = StringIO.new
    t.write_to(io)
    io.seek(0)
    n = io.read
    wellformed_verify n
    n.should == @erf
  end

  it "reads ERF with locstr_size = 0 and locstr_count > 0" do
    old_debug = NWN.setting(:debug, "0")
    @erf[12,4] = [0].pack("V")
    wellformed_verify @erf, false
    NWN.setting(:debug, old_debug)
  end

  it "reads ERF with locstr_size > 0 and locstr_count = 0" do
    old_debug = NWN.setting(:debug, "0")
    @erf[8,4] = [0].pack("V")
    wellformed_verify @erf, false
    NWN.setting(:debug, old_debug)
  end
end

describe "Erf V1.0" do
  before do
    @erf = WELLFORMED_ERF.dup
  end

  it_should_behave_like "Erf::Erf"

  it "accepts valid filenames" do
    t = Erf::Erf.new(StringIO.new @erf)
    t.add_file("a" * 1 + ".txt", StringIO.new("blargh"))
    t.add_file("a" * 16 + ".txt", StringIO.new("blargh"))
  end

  it "fails on invalid filenames" do
    t = Erf::Erf.new(StringIO.new @erf)
    proc { t.add_file("a" * 0 + ".txt", StringIO.new("blargh")) }.should raise_error ArgumentError
    proc { t.add_file("a" * 17 + ".txt", StringIO.new("blargh")) }.should raise_error ArgumentError
  end

  it "returns unknown for unknown-N file types" do
    @erf[174 + 16 + 4, 2] = [9995].pack("v")
    t = Erf::Erf.new(StringIO.new @erf)
    t.content[0].filename.should == "resref.unknown-9995"
  end
end

describe "Erf V1.1" do
  before do
    @erf = WELLFORMED_ERF_11.dup
  end

  it_should_behave_like "Erf::Erf"

  it "accepts valid filenames" do
    t = Erf::Erf.new(StringIO.new @erf)
    t.add_file("a" * 1 + ".txt", StringIO.new("blargh"))
    t.add_file("a" * 32 + ".txt", StringIO.new("blargh"))
  end

  it "fails on invalid filenames" do
    t = Erf::Erf.new(StringIO.new @erf)
    proc { t.add_file("a" * 0 + ".txt", StringIO.new("blargh")) }.should raise_error ArgumentError
    proc { t.add_file("a" * 33 + ".txt", StringIO.new("blargh")) }.should raise_error ArgumentError
  end

  it "returns unknown for unknown-N file types" do
    @erf[174 + 32 + 4, 2] = [9995].pack("v")
    t = Erf::Erf.new(StringIO.new @erf)
    t.content[0].filename.should == "resref.unknown-9995"
  end
end
