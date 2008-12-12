# A CExoLocString is a localised CExoString.
# It contains pairs of language => text pairs,
# where language is a language_id as specified in the GFF
# documentation pdf.
module NWN::Gff::CExoLocString

  # Removes all nil and empty strings.
  def compact!
    self.each {|lid,str|
      self.delete(lid) if str.nil? || str.empty?
    }
  end
end
