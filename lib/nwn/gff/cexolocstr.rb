module NWN::Gff::Field
  def has_str_ref?
    false
  end
end

module NWN::Gff::Cexolocstr
  DEFAULT_STR_REF = 0xffffffff

  def str_ref
    self['str_ref'] || DEFAULT_STR_REF
  end
  def str_ref= s
    self['str_ref'] = s.to_i
  end
  def has_str_ref?
    str_ref != DEFAULT_STR_REF
  end
end

module NWN::Gff::CexolocstrValue
  # Removes all nil and empty strings.
  def compact!
    self.each {|lid,str|
      self.delete(lid) if str.nil? || str.empty?
    }
  end
end
