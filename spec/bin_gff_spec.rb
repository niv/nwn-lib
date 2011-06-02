require File.join(File.dirname(__FILE__), 'spec_helper')

describe "nwn-gff" do
  include BinHelper
  before do
    @tmp = Dir.tmpdir
  end

  NWN::Gff::InputFormats.each do |in_format, handler|
    inf = in_format.to_s

    NWN::Gff::OutputFormats.each do |out_format, handler|
      otf = out_format.to_s

      it "converts #{inf} to #{otf}" do
        # prepare the temp file
        t = Tempfile.new(@tmp)
        t.close

        run("-lg", "-i", WELLFORMED_GFF_PATH, "-k", inf, "-o", t.path)
        run("-l", inf, "-i", t.path, "-k", otf)
        t.unlink
      end
    end
  end

  it "supports none GNU-style backup" do
    t = Tempfile.new(@tmp)
    t.close
    run("-b", "none", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~").should == false
  end

  it "supports numbered GNU-style backup" do
    t = Tempfile.new(@tmp)
    t.close

    run("-b", "numbered", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~0").should == true
    FileTest.exists?(t.path + "~1").should == false

    run("-b", "numbered", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~0").should == true
    FileTest.exists?(t.path + "~1").should == true
    FileTest.exists?(t.path + "~2").should == false

    File.unlink(t.path + "~0")
    File.unlink(t.path + "~1")
  end

  it "supports existing with no numbered backups GNU-style backup" do
    t = Tempfile.new(@tmp)
    t.close

    FileTest.exists?(t.path + "~").should == false

    run("-b", "existing", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~").should == true

    File.unlink(t.path + "~")

    FileUtils.cp(t.path, t.path + "~0")
    run("-b", "existing", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~").should == false
    FileTest.exists?(t.path + "~0").should == true
    FileTest.exists?(t.path + "~1").should == true
    FileTest.exists?(t.path + "~2").should == false

    File.unlink( t.path + "~0")
    File.unlink( t.path + "~1")
  end


  it "supports simple GNU-style backup" do
    t = Tempfile.new(@tmp)
    t.close

    FileTest.exists?(t.path + "~").should == false

    run("-b", "simple", "-lg", "-i", WELLFORMED_GFF_PATH, "-kg", "-o", t.path)
    FileTest.exists?(t.path).should == true
    FileTest.exists?(t.path + "~").should == true

    File.unlink(t.path + "~")
  end


end
