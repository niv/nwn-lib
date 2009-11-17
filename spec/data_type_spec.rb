require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Struct#data_type" do

  before(:each) do
    @manual = Gff::Struct.new(0x0, 'root', 'V3.1') do |s|
      s.add_struct 'a', Gff::Struct.new(0x1) do |a|
        a.v.add_struct 'b', Gff::Struct.new(0x02) do |b|
          b.v.add_field 'hi', :int, 1
        end
      end
    end
  end

  it "has the proper data types when building inline" do
    verify @manual
  end

unless Gff::InputFormats[:json] && Gff::OutputFormats[:json]
  $stderr.puts "Partial or no json support, not running json specs!"
else

  it "keeps explicit data types for json" do
    @manual['a'].v['b'].v.data_type = 'EXPLICIT'
    json = StringIO.new
    Gff.write(json, :json, @manual)
    json.seek(0)
    n = Gff.read(json, :json)
    n['a'].v.path.should == '/a'
    n['a'].v.data_type.should == nil
    n['a'].v['b'].v.data_type.should == 'EXPLICIT'
  end

  it "has the proper data type when reading from json" do
    struct = <<EOS
{
  "a": {
    "type": "struct",
    "value": {
      "b": {
        "type": "struct",
        "value": {
          "hi": {
            "type": "int",
            "value": 1
          },
          "__struct_id": 2
        }
      },
      "__struct_id": 1
    }
  },
  "__data_version": "V3.1",
  "__data_type": "root",
  "__struct_id": 0
}
EOS

    struct = Gff.read(StringIO.new(struct), :json)

    verify struct
  end

end

  it "keeps explicit data types for yaml" do
    (@manual / 'a/b').v.data_type = 'EXPLICIT'
    json = StringIO.new
    Gff.write(json, :yaml, @manual)
    json.seek(0)
    n = Gff.read(json, :yaml)
    (n / 'a/b/hi').path.should == "/a/b/hi"
    (n / 'a$').data_type.should == nil
    (n / 'a/b$').data_type.should == "EXPLICIT"
  end

  it "has the proper data type when reading from yaml" do
    struct = <<EOS
--- !nwn-lib.elv.es,2008-12/struct
__data_type: root
__data_version: V3.1
__struct_id: 0
a:
  type: :struct
  value: !nwn-lib.elv.es,2008-12/struct
    __data_type: ATYPE
    __struct_id: 1
    b:
      type: :struct
      value: !nwn-lib.elv.es,2008-12/struct {__data_type: BTYPE, __struct_id: 2, hi: {type: :int, value: 1}}
EOS
    struct = Gff.read(StringIO.new(struct), :yaml)

    verify struct
  end

  it "has the proper data type when reading from yaml with overriden data_type" do
    struct = <<EOS
--- !nwn-lib.elv.es,2008-12/struct
__data_type: root
__data_version: V3.1
__struct_id: 0
a:
  type: :struct
  value: !nwn-lib.elv.es,2008-12/struct
    __data_type: DTYPE
    __struct_id: 1
    b:
      type: :struct
      value: !nwn-lib.elv.es,2008-12/struct {__data_type: BTYPE, __struct_id: 2, hi: {type: :int, value: 1}}
EOS
    struct = Gff.read(StringIO.new(struct), :yaml)

    (struct / 'a$').data_type.should == 'DTYPE'
    (struct / 'a$').path.should == '/a'
  end

  def verify struct
    struct.data_type.should == 'root'
    struct.data_version.should == 'V3.1'
    (struct / 'a').path.should == '/a'
    (struct / 'a').v.path.should == '/a'
    (struct / 'a$').path.should == '/a'
    (struct / 'a/b$').path.should == '/a/b'
    (struct / 'a/b/hi').path.should == '/a/b/hi'
    (struct / 'a/b/hi$').should == 1
  end
end
