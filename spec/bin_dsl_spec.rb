require File.join(File.dirname(__FILE__), 'spec_helper')

describe "nwn-dsl" do
  include BinHelper

  it "runs empty scripts" do
    t = Tempfile.new(["nwn-lib", "dsl"])
    t.close
    run(t.path)
  end

  it "runs want/need scripts" do
    t = Tempfile.new(["nwn-lib", "dsl"])
    t.write("need ARGV.shift, :bic")
    t.close
    run_bin(t.path, WELLFORMED_GFF_PATH) do |i,o,e|
      e = e.read
      o = o.read
      e.should == "#{t.path}: satisfied #{WELLFORMED_GFF_PATH} -> <NWN::Gff::Struct BIC/V3.2, 129 fields>\n"
      o.should == ""
    end
  end

  it "logs to stderr" do
    t = Tempfile.new(["nwn-lib", "dsl"])
    t.write("log 'hey'")
    t.close
    run_bin(t.path, WELLFORMED_GFF_PATH) do |i,o,e|
      e = e.read
      o = o.read
      e.should == "#{t.path}: hey\n"
      o.should == ""
    end
  end

end
