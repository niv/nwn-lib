require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Struct#data_type" do

  before(:each) do
    @manual = Gff::Struct.new(0x0, 'root', 'V3.2') do |s|
      s.add_struct 'a', Gff::Struct.new(0x1) do |a|
        a.v.add_struct 'b', Gff::Struct.new(0x02) do |b|
          b.v.add_field 'hi', :int, 1
        end
      end
    end
    @manual.freeze
  end

  it "has the proper data types when building inline" do
    verify @manual
  end

  for out_fmt in (NWN::Gff::OutputFormats.keys & NWN::Gff::InputFormats.keys) - [:gff] do
    it "#{out_fmt} does not lose explicit data types" do
      (@manual / 'a/b$').data_type = 'EXPLICIT'
      out = StringIO.new
      Gff.write(out, out_fmt, @manual)
      out.seek(0)
      n = Gff.read(out, out_fmt)

      (@manual / 'a/b$').data_type.should == 'EXPLICIT'

      (n / 'a$').data_type.should == nil
      (n / 'a/b$').data_type.should == 'EXPLICIT'

      verify n
    end
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
    struct.data_version.should == 'V3.2'
    (struct / 'a').path.should == '/a'
    (struct / 'a').v.path.should == '/a'
    (struct / 'a$').path.should == '/a'
    (struct / 'a/b$').path.should == '/a/b'
    (struct / 'a/b/hi').path.should == '/a/b/hi'
    (struct / 'a/b/hi$').should == 1
  end
end
