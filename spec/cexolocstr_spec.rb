require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Cexolocstr" do

  it "should compact nil and empty strings" do
    str = Gff::Field.new('Test', :cexolocstr, {})
    str.v[0] = "hi"
    str.v[1] = nil
    str.v[4] = ""
    str.v[8] = "test"
    str.v.compact!
    str.v.should == {0=>"hi", 8=>"test"}
  end

end
