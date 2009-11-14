require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Key::Key", :shared => true do
  def wellformed_verify binary
    t = Key::Key.new(StringIO.new(binary), Dir.tmpdir)

    t.file_type.should == "KEY"
    t.file_version.should == "V1"
    t.content.size.should == 2
    t.content[0].resref.should == "abcdef"
    t.content[1].resref.should == "123456"
    t.content[0].get.should == "abcdefghij"
    t.content[1].get.should == "0123456789"
  end

  it "should work" do
    wellformed_verify @key
  end

  before do
    @bif0 = File.join(Dir.tmpdir, "bif0.bif")
    File.open(@bif0, "w") do |f|
      f.write(WELLFORMED_BIF_0)
    end
  end

  after do
    File.unlink(@bif0)
  end
end

describe "Key V1.0" do
  before do
    @key = WELLFORMED_KEY.dup
  end

  it_should_behave_like "Key::Key"
end
