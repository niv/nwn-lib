# A CExoLocString is a localised CExoString.
# It contains pairs of language => text pairs,
# where language is a language_id as specified in the GFF
# documentation pdf.
class NWN::Gff::CExoLocString
  attr_reader :languages
  def initialize
    @languages = {}
  end

  # Retrieve the text for a given language.
  # Returns "" if no text is set for the given
  # language.
  def [] language_id
    @languages[language_id.to_i] || ""
  end

  # Sets a new language text.
  def []= language_id, text
    @languages[language_id.to_i] = text
  end

  def size
    @languages.size
  end

  def each
    @languages.each {|k,v|
      yield k, v
    }
  end

  def compact
    @languages.compact.reject {|k,v| "" == v}
  end
end
