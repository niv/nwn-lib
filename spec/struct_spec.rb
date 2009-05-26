require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Struct" do

  it "accepts a block and yields the resulting struct" do
    ret = Gff::Struct.new(0xdeadbeef) do |s|
      s.add_byte 'Halp', 0xff
    end
    ret.should == {"Halp"=>{"label"=>"Halp", "value"=>255, "type"=>:byte}}
    ret.struct_id.should == 0xdeadbeef
  end

  it "can retrieve list entries by_path" do
    ret = Gff::Struct.new
    ret.add_list 'Path', [] do |list|
      list.v << Gff::Struct.new do |s|
        s.add_byte 'Val', 0xff
      end
    end

    ret.by_path('Path[0]/Val').should == {"label"=>"Val", "value"=>255, "type"=>:byte}
    proc {
      ret.by_path('Path[1]/Val')
    }.should raise_error Gff::GffPathInvalidError
    proc {
      ret.by_path('PathWTF/$55?')
    }.should raise_error Gff::GffPathInvalidError

    ret.by_path('Path[0]/Val').should equal ret.by_path('/Path[0]/Val')
  end

  it "sets proper parent/child tree links" do
    ret = Gff::Struct.new
    list = ret.add_list 'Path', []
    list.add_struct 1 do |l|
      l.add_byte 'Val', 0xff
    end

    list = ret.by_path('/Path')
    list.parent.should == ret

    struct = ret.by_path('/Path[0]')
    struct.element.should == list

    byte = ret.by_path('/Path[0]/Val')
    byte.parent.should == struct

    ret.by_path('/Path[0]/Val').path.should == '/Path[0]/Val'
  end

  GffFieldValidations.each {|type, values|
    valid, invalid = * values

    it "can create #{type.inspect} fields dynamically" do
      ret = Gff::Struct.new
      ret.send('add_' + type.to_s, 'Test', valid[0])
      ret.should == {"Test"=>{"label"=>"Test", "value"=>valid[0], "type"=>type}}
    end
  }

  it "returns proper fields" do
    t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
    t['Plot'].should respond_to :t
    t['Plot'].should respond_to :l
    t['Plot'].should respond_to :v
    t['Plot'].l.should == "Plot"
    t['Plot'].t.should == :byte
  end

  it "yields all and correct values in each_by_flat_path" do
    t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
    t.each_by_flat_path do |k,v|
      k.class.should == String
      k.should =~ %r{^/}
    end
  end

  it "responds_to to_gff" do
    t = Gff::Reader.read(StringIO.new WELLFORMED_GFF)
    Gff::Reader.read(StringIO.new t.to_gff).should == t
  end
end
