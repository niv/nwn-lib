require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Gff::Field" do
  GffFieldValidations.each do |t, values|
    valid, invalid = *values
    # No field type ever accepts nil as valid
    invalid << nil

    it "accepts good values for type '#{t.inspect}'" do
      valid.each do |v|
        Gff::Field.valid_for?(v, t).should == true
      end
    end

    it "rejects bad values for type '#{t.inspect}'" do
      invalid.each do |v|
        Gff::Field.valid_for?(v, t).should == false
      end
    end
  end
end
