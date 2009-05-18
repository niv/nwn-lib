require File.join(File.dirname(__FILE__), 'spec_helper')

WELLFORMED_ERF = ([
  "HAK", "V1.0",
  locstr_count = 1, locstr_size = 14,
  entry_count = 3,
  offset_to_locstr = 160,
  offset_to_keys = offset_to_locstr + locstr_size,
  offset_to_res  = offset_to_locstr + locstr_size + entry_count * 24,

  100, 126, # year, dayofyear
  0xdeadbeef, "" #description strref, 116 bytes 0-padding
].pack("a4 a4 VV VV VV VV V  a116") + [
  0, 6, "abcdef" # one locstr
].pack("V V a*") + [
  "resref", 0, 10, 0, # keylist: resref.txt, id = 0
  "help",   1,  1, 0, # keylist: help.bmp, id = 1
  "yegods", 2,  4, 0, # keylist: yegods.wav, id = 2
].pack("a16 V v v" * entry_count) + [
  offset_to_res + entry_count * 8, 6,  # offset, size
  offset_to_res + entry_count * 8 + 6, 4,  # offset, size
  offset_to_res + entry_count * 8 + 6 + 4, 6,  # offset, size
].pack("II" * entry_count) + [
  "resref", "help", "yegods"
].pack("a* a* a*")).freeze



describe "Erf::Erf" do

  def wellformed_verify binary, expect_locstr = true
    t = nil
    t = Erf::Erf.new(StringIO.new binary)

    t.file_type.should == "HAK"
    t.file_version.should == "V1.0"
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
    wellformed_verify WELLFORMED_ERF
  end

  it "reproduces correct ERF binary data" do
    t = Erf::Erf.new(StringIO.new WELLFORMED_ERF)
    io = StringIO.new
    t.write_to(io)
    io.seek(0)
    proc {
      wellformed_verify io.read
    }.should_not raise_error IOError
  end

  it "does not read ERF with locstr_size = 0 and locstr_count > 0" do
    b = WELLFORMED_ERF.dup
    b[12,4] = [0].pack("V")
    proc {
      wellformed_verify b
    }.should raise_error IOError
  end

  it "reads ERF with locstr_size > 0 and locstr_count = 0" do
    b = WELLFORMED_ERF.dup
    b[8,4] = [0].pack("V")
    proc {
      wellformed_verify b, false
    }.should_not raise_error IOError
  end
end
