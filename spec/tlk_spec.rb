require File.join(File.dirname(__FILE__), 'spec_helper')

WELLFORMED_TLK = ([
  "TLK", "V3.0",
  language_id = 0,
  string_count = 5,
  offset_to_str = 21,
].pack("a4 a4 I I I") + [ # string data table
  # flags, soundresref, volvariance, pitchvariance, offset_to_str, sz, soundlen
  0x1, "", 0, 0, -1 + 40 * string_count, 1, 0.0,
  0x3, "textsnd", 0, 0, -1 + 40 * string_count + 1, 2, 0.0,
  0x7, "textsndlen", 0, 0, -1 + 40 * string_count + 3, 3, 2.0,
  0x1, "", 0, 0, -1 + 40 * string_count + 6, 4, 0.0,
  0x2, "justsnd", 0, 0, -1 + 40 * string_count + 10, 0, 0.0,
].pack("I A16 I I I I f" * string_count) + [
  "1", "22", "333", "4444"
].join("")).freeze


describe "Tlk::Tlk" do

  def wellformed_verify binary
    t = Tlk::Tlk.new(StringIO.new binary)

    t.language.should == 0
    t.highest_id.should == 4
    t[0].should == {:pitch_variance=>0, :text=>"1",     :sound=>"", :sound_length=>0.0, :volume_variance=>0}
    t[1].should == {:pitch_variance=>0, :text=>"22",    :sound=>"textsnd", :sound_length=>0.0, :volume_variance=>0}
    t[2].should == {:pitch_variance=>0, :text=>"333",   :sound=>"textsndlen", :sound_length=>2.0, :volume_variance=>0}
    t[3].should == {:pitch_variance=>0, :text=>"4444",  :sound=>"", :sound_length=>0.0, :volume_variance=>0}
    t[4].should == {:pitch_variance=>0, :text=>"",      :sound=>"justsnd", :sound_length=>0.0, :volume_variance=>0}
    proc { t[5] }.should raise_error ArgumentError
  end

  it "reads wellformed TalkTables" do
    wellformed_verify WELLFORMED_TLK
  end

  it "reproduces correct TalkTable binary data" do
    t = Tlk::Tlk.new(StringIO.new WELLFORMED_TLK)
    io = StringIO.new
    t.write_to(io)
    io.seek(0)
    wellformed_verify io.read
  end

end
