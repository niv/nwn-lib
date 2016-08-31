require File.join(File.dirname(__FILE__), 'spec_helper')

class StubContainer < Resources::Container
  def initialize files
    super()
    files.each {|fn, content|
      io = StringIO.new(content)
      self.add_file fn, io
    }
  end
end

describe "ContentObject" do
  subject do
    Resources::ContentObject.new_from("case.txt", StringIO.new("test"))
  end

  it "returns filenames lowercase" do
    subject.filename.should == "case.txt"
  end

  it "returns the proper size for StringIO" do
    subject.size.should == 4
  end
end

describe "Resources::Container" do
  subject do
    StubContainer.new('a_1.txt' => 'a', 'CASE.tXt' => 'case', 't_1.txt' => 'a')
  end

  it "disregards case" do
    subject.get('case.txt').should == "case"
    subject.get('CASE.txt').should == "case"
    subject.get('CASE.tXt').should == "case"
  end
end

describe Resources::Manager do
  before do
    subject.add_container StubContainer.new('a_1.txt' => 'a', 'CASE.tXt' => 'case', 't_1.txt' => 'a')
    subject.add_container StubContainer.new('b_1.txt' => 'b', 't_1.txt' => 'b')
  end

  it "observes ordering of added containers" do
    subject.get('a_1.txt').should == "a"
    subject.get('t_1.txt').should == "b"
  end

  it "fails on invalid filenames" do
    proc {subject.get('invalid')}.should raise_error Errno::ENOENT
  end

  it "disregards case" do
    subject.get('case.txt').should == "case"
    subject.get('CASE.txt').should == "case"
    subject.get('CASE.tXt').should == "case"
  end
end
