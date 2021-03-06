require File.join(File.dirname(__FILE__), 'spec_helper')

describe "nwn-erf" do
  include BinHelper
  # Create temporary testcase files.
  before do
    @tmpdir = Dir.mktmpdir

    @target = File.join(@tmpdir, "nwn-lib-spec-target.erf")

    @tmp0s = []
    @tmp1s = []
    for x in %w{aaa.tga bbbb.erf ccc.bmp 44.txt} do
      File.open(File.join(@tmpdir, x), "w") do |fn|
        fn.write(x)
      end
      @tmp0s << File.join(@tmpdir, x)
    end
    for x in %w{bbbbbbbbbbbbbbbbbbbb.bmp} do
      File.open(File.join(@tmpdir, x), "w") do |fn|
        fn.write(x)
      end
      @tmp1s << File.join(@tmpdir, x)
    end
    @tmp0s.sort!
    @tmp1s.sort!
  end

  after do
    FileUtils.rm_r @tmpdir
  end

  it "packs -0" do
    run("-0", "-c", "-f", @target, *@tmp0s)
  end

  it "fails to pack -0 with 1.1 filenames" do
    run_fail("-0", "-c", "-f", @target, *(@tmp0s + @tmp1s))
  end

  it "packs -1" do
    run("-1", "-c", "-f", @target, *(@tmp0s + @tmp1s))
  end

  it "lists -0" do
    run("-c", "-f", @target, *@tmp0s)
    run_bin("-l", "-f", @target) do |i,o,e|
      o = o.read
      o.split(/\n/).sort.should == @tmp0s.map {|x| File.basename(x) }
    end
  end

  it "lists -1" do
    run("-1", "-c", "-f", @target, *@tmp1s)
    run_bin("-l", "-f", @target) do |i,o,e|
      o = o.read
      o.split(/\n/).sort.should == @tmp1s.map {|x| File.basename(x) }
    end
  end

  it "extracts -0" do
    run("-c", "-f", @target, *@tmp0s)
    @tmp0s.each {|f| File.unlink(f) }
    run("-x", "-f", @target)
    @tmp0s.each {|f| FileTest.exists?(f).should == true }
    @tmp0s.each {|f| IO.read(f, :encoding => "BINARY").should == File.basename(f) }
  end

  it "extracts -1" do
    workon = @tmp0s + @tmp1s
    run("-1", "-c", "-f", @target, *workon)
    workon.each {|f| File.unlink(f) }
    run("-x", "-f", @target)
    workon.each {|f| FileTest.exists?(f).should == true }
    workon.each {|f| IO.read(f, :encoding => "BINARY").should == File.basename(f) }
  end

  it "creates haks" do
    run("-H", "-c", "-f", @target, *@tmp0s)
    IO.read(@target, :encoding => "BINARY").should =~ /^HAK/
  end

  it "creates mods" do
    run("-M", "-c", "-f", @target, *@tmp0s)
    IO.read(@target, :encoding => "BINARY").should =~ /^MOD/
  end

  it "creates erfs (by default)" do
    run("-E", "-c", "-f", @target, *@tmp0s)
    IO.read(@target, :encoding => "BINARY").should =~ /^ERF/
    run("-c", "-f", @target, *@tmp0s)
    IO.read(@target, :encoding => "BINARY").should =~ /^ERF/
  end

  it "adds files from existing archives" do
    run("-c", "-f", @target, *(@tmp0s[1 .. -1]))
    run("-a", "-f", @target, @tmp0s[0])
    run_bin("-l", "-f", @target) do |i,o,e|
      o = o.read
      o.split(/\n/).sort.should == @tmp0s.map {|x| File.basename(x) }
    end
  end

  it "removes files from existing archives" do
    run("-c", "-f", @target, *@tmp0s)
    run("-r", "-f", @target, File.basename(@tmp0s[0]))
    run_bin("-l", "-f", @target) do |i,o,e|
      o = o.read
      o.split(/\n/).sort.should == @tmp0s[1 .. -1].map {|x| File.basename(x) }
    end
  end

end
