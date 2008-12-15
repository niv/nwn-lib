module NWN::Gff
  @YAMLStructDefaults = {}

#:stopdoc:
  # This gets called for each parsed struct to set their container element
  # values (see also gff/reader.rb, line 233-ish).
  def self.__yaml_postparse parent, struct
    struct.each {|label,element|
      case element.field_type
        when :list, :struct
          [element.field_value].flatten.each {|item|
            __yaml_postparse(element, item)
            item.element = element
          }
      end
    }
  end
#:startdoc:

  # This loads structs defaults from the given file, which will
  # be used for field_type inferring and autocompletion/filtering of default values.
  # A sample file has been provided with nwn-lib, called gff-bioware.yml
  def self.load_struct_defaults file
    @YAMLStructDefaults = YAML.load(IO.read(file))
    new = {}
    @YAMLStructDefaults.each {|k,v|
      new[Regexp.new(k + '$')] = v
    }
    @YAMLStructDefaults = new
  end

  def self.get_struct_defaults
    @YAMLStructDefaults || {}
  end

  def self.get_struct_defaults_for path, key
    sd = NWN::Gff.get_struct_defaults
    sd.keys.each {|rx|
      next unless path =~ rx
      return sd[rx][key] if sd[rx][key] != nil
    }
    nil
  end

  def self.get_struct_default_type path, key
    dd = get_struct_defaults_for(path, key)
    dd.is_a?(Array) ? dd[0] : dd
  end

  def self.get_struct_default_value path, key
    dd = get_struct_defaults_for(path, key)
    dd.is_a?(Array) ? dd[1] : nil
  end

  def self.get_struct_always_fields path
    dd = get_struct_defaults_for(path, '__always')
    dd || []
  end
end

module NWN::Gff::Struct
  # Returns true if we can later infer the struct_id with the given path.
  def can_infer_struct_id?
    v = NWN::Gff.get_struct_defaults_for(self.path, '__struct_id')
    v == @struct_id || v == "iterative" || v == "inline"
  end

  # Returns true if we can infer the data version of this struct (if it has parent).
  def can_infer_data_version?
    @data_version == DEFAULT_DATA_VERSION || (
      @element && @element.parent && @element.parent.data_version == @data_version
    )
  end
end

module NWN::Gff::Cexolocstr
  def field_value_as_compact
    !can_infer_str_ref? ? field_value.merge({'str_ref' => str_ref}) : field_value
  end
end

module NWN::Gff::Field
  YAMLCompactableFields = [:byte, :char, :word, :short, :dword, :int, :void,
    :dword64, :int64, :float, :double, :cexostr, :resref, :cexolocstr, :list]

  # Returns true if we can later infer the field type.
  def can_infer_type?
    expected = NWN::Gff.get_struct_default_type(@parent.path, field_label)

    raise NWN::Gff::GffError, "#{field_label} has field_type " +
      "#{field_type.inspect}, but infer data says #{expected.inspect}." if
        expected && expected != field_type

    expected == field_type
  end

  # Returns true if we can later infer the default value.
  def can_infer_value?
    NWN::Gff.get_struct_default_value(@parent.path, field_label) == field_value
  end

  # Returns true if we can infer the str ref later on.
  def can_infer_str_ref?
    !has_str_ref? || (d = NWN::Gff.get_struct_defaults_for(@parent.path, field_label) && d && d[2] != nil)
  end

  # Can we print this field without any syntactic gizmos?
  def can_compact_print?

    YAMLCompactableFields.index(field_type) &&
      # exolocs print their str_ref along with their language keys
      (field_type == :cexolocstr || can_infer_str_ref?) &&
      can_infer_type?
  end

  def can_compact_as_list?
     NWN::Gff.get_struct_defaults_for(self.path, '__compact') != nil &&
      field_value.reject {|x|
        x.can_infer_struct_id?
      }.size == 0
  end

  def get_compact_as_list_field
    NWN::Gff.get_struct_defaults_for(self.path, '__compact')
  end

  def field_value_as_compact
    field_value
  end
end
