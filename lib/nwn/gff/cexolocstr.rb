module NWN::Gff::Cexolocstr

end

module NWN::Gff::CexolocstrValue
  # Removes all nil and empty strings.
  def compact!
    self.each {|lid,str|
      self.delete(lid) if str.nil? || str.empty?
    }
  end
end
