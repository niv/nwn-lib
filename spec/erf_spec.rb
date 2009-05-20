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

  it "reproduces correct ERF binary data" do
    t = Erf::Erf.new(StringIO.new @erf)
    io = StringIO.new
    t.write_to(io)
    io.seek(0)
    wellformed_verify io.read
  end

  it "does not read ERF with locstr_size = 0 and locstr_count > 0" do
    @erf[12,4] = [0].pack("V")
    proc {
      wellformed_verify @erf
    }.should raise_error IOError
  end

  it "reads ERF with locstr_size > 0 and locstr_count = 0" do
    @erf[8,4] = [0].pack("V")
    wellformed_verify @erf, false
  end
end

describe "Erf V1.0" do
  before do
    @erf = WELLFORMED_ERF.dup
  end

  it_should_behave_like "Erf::Erf"
end

describe "Erf V1.1" do
  before do
    @erf = WELLFORMED_ERF_11.dup
  end

  it_should_behave_like "Erf::Erf"
end
