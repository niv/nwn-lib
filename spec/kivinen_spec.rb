require File.join(File.dirname(__FILE__), 'spec_helper')
require File.join(File.dirname(__FILE__), 'kivinen_expect')

describe "Kivinen Support" do

  it "yields all fields correctly" do
    g = Gff.read(StringIO.new(WELLFORMED_GFF), :gff)

    expected = KIVINEN_EXPECT.dup

    NWN::Gff::Handler::Kivinen.format(g, true) do |label, entry|
      w = expected.shift
      label.should == w[0]
      case entry
        when Float
          entry.should be_within(0.001).of(w[1])
        else
          entry.should == w[1]
      end
    end
  end
end
