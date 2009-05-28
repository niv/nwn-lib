require File.join(File.dirname(__FILE__), 'spec_helper')

describe TwoDA::Table do
  before do
    NWN.setting(:debug, "0")
  end
  after do
    NWN.setting(:debug, nil)
  end

  it "parses wellformed files" do
    proc { subject.parse(TWODA_WELLFORMED) }.should_not raise_error ArgumentError
  end

  it "parses misnumbered IDs as NWN does" do
    subject.parse(TWODA_MISALIGNED)
    subject.rows.map {|v| v.Col1 }.should == %w{a b c d e f g h}
  end
  
  it "skips rows with missing IDs as NWN does" do
    subject.parse(TWODA_MISSING_ID)
    subject.rows.map {|v| v.Col1 }.should == ["", "b", "c", "d"]
  end

  it "parses whitespace in tables correctly" do
    proc { subject.parse(TWODA_WHITESPACE) }.should_not raise_error
  end

  it "fills in missing columns correctly" do
    subject.parse(TWODA_MISSING_COLUMN)
    subject.rows[1].Col3.should == ""
  end

  it "ignores superflous cell values" do
    subject.parse(TWODA_TOO_MANY_CELLS)
    subject.rows[0].size.should == 1
    subject.rows[1].size.should == 1
  end

  it "parses non-quoted and quoted trailing cells with whitespaces correctly" do
    subject.parse(TWODA_TOO_MANY_CELLS)
    subject.rows[0].Col1.should == "a1"
    subject.rows[1].Col1.should == "a2"
    subject.rows[2].Col1.should == "a2     b2    c1"
  end

  it "parses starred values correctly" do
    subject.parse(TWODA_EMPTY_AND_QUOTES)
    subject.rows[0].Col1.should == ""
  end

  it "parses quoted cells correctly" do
    subject.parse(TWODA_EMPTY_AND_QUOTES)
    subject.rows[2].Col1.should == ""
    subject.rows[3].Col1.should == "g g"
    subject.rows[3].Col2.should == "h"
  end

  it "allows setting a whole row by column id, and cast arguments" do
    subject.parse(TWODA_WELLFORMED)
    subject[0] = [1, 2]
    subject[0].should == ["1", "2"]
    proc { subject[0] = [1, 2, 3] }.should raise_error ArgumentError
  end

  it "allows setting a cell by id and column name, and cast arguments" do
    subject.parse(TWODA_WELLFORMED)
    subject[0, 'Col1'] = "a"
    subject[0, 'Col1'].should == "a"
    proc { subject['Col1', 0] = "a" }.should raise_error TypeError
  end

  it "should print newlines as specified in NWN_LIB_2DA_NEWLINE" do
    subject.parse(TWODA_WELLFORMED)
    ENV['NWN_LIB_2DA_NEWLINE'] = nil
    subject.to_2da.should =~ /^2DA V2.0\r\n\r\n +C/
    ENV['NWN_LIB_2DA_NEWLINE'] = "0"
    subject.to_2da.should =~ /^2DA V2.0\r\n\r\n +C/
    ENV['NWN_LIB_2DA_NEWLINE'] = "1"
    subject.to_2da.should =~ /^2DA V2.0\n\n +C/
    ENV['NWN_LIB_2DA_NEWLINE'] = "2"
    subject.to_2da.should =~ /^2DA V2.0\r\r +C/
  end
end
