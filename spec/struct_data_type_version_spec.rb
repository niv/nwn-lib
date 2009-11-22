require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Struct" do
  ReadWriteFormats = (NWN::Gff::OutputFormats.keys & NWN::Gff::InputFormats.keys)
  NoRootNoMetadata = [:gff]

  before(:each) do
    @manual = Gff::Struct.new(0x0, 'root', 'V3.2') do |s|
      s.add_struct 'a', Gff::Struct.new(0x1) do |a|
        a.v.add_struct 'b', Gff::Struct.new(0x02) do |b|
          b.v.add_field 'hi', :int, 1
        end
      end
    end
  end

  def read_write what, format
    out = StringIO.new
    Gff.write(out, format, what)
    out.seek(0)
    n = Gff.read(out, format)
  end

  it "has the proper data structure when building inline" do
    @manual.data_type.should == 'root'
    @manual.data_version.should == 'V3.2'
    (@manual / 'a').path.should == '/a'
    (@manual / 'a').v.path.should == '/a'
    (@manual / 'a$').path.should == '/a'
    (@manual / 'a/b$').path.should == '/a/b'
    (@manual / 'a/b/hi').path.should == '/a/b/hi'
    (@manual / 'a/b/hi$').should == 1
  end

  describe "#data_type" do
    ReadWriteFormats.each do |format|
      it "#{format} keeps explicit root data types" do
        @manual.data_type = 'EXPL'
        n = read_write(@manual, format)
        n.data_type.should == 'EXPL'
      end
    end

    (ReadWriteFormats - NoRootNoMetadata).each do |format|
      it "#{format} keeps explicit non-root data types" do
        (@manual / 'a/b$').data_type = 'EXPL'
        n = read_write(@manual, format)
        (n / 'a/b$').data_type.should == 'EXPL'
      end
    end
  end

  describe "#data_version" do
    ReadWriteFormats.each do |format|
      it "#{format} keeps explicit root data version" do
        @manual.data_version = 'EXPL'
        n = read_write(@manual, format)
        n.data_version.should == 'EXPL'
      end
    end

    (ReadWriteFormats - NoRootNoMetadata).each do |format|
      it "#{format} keeps explicit non-root data version" do
        (@manual / 'a/b$').data_version = 'EXPL'
        n = read_write(@manual, format)
        (n / 'a/b$').data_version.should == 'EXPL'
      end
    end

    ReadWriteFormats.each do |format|
      it "#{format} reads implicit data_version as DEFAULT_DATA_VERSION" do
        n = read_write(@manual, format)

        (@manual / 'a/b$').data_version.should == NWN::Gff::Struct::DEFAULT_DATA_VERSION
        @manual.data_version.should == NWN::Gff::Struct::DEFAULT_DATA_VERSION
        (n / 'a/b$').data_version.should == NWN::Gff::Struct::DEFAULT_DATA_VERSION
        n.data_version.should == NWN::Gff::Struct::DEFAULT_DATA_VERSION
      end
    end
  end
end

