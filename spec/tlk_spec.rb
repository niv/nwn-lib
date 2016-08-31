require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Tlk::Tlk" do

  def wellformed_verify binary
    t = Tlk::Tlk.new(StringIO.new binary)

    t.language.should == 0
    t.size.should == 5
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
