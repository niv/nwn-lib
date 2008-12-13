# A Field wraps a GFF label->value pair, providing:
# * +.field_type+ describing the field type (e.g. :int)
# * +.field_value+ holding the value of this Field
# * +.str_ref+ containing a str_ref for applicable fields

# and, if loaded by Gff::Reader or through YAML:
# * +.field_label+ holding the label
# * +.parent+ holding the struct this Field is child of.
#
# Note that it is ADVISED to use the provided accessors,
# since they do some structure-keeping in the background.
# If you do NOT want it to do that, use hash-notation for access:
#
#  field['value'], field['type'], field['str_ref'], field['label']
module NWN::Gff::Field
  DEFAULT_STR_REF = 0xffffffff

  # The parent struct.
  # This is set internally by Gff::Reader on load.
  attr_accessor :parent

  def field_type
    self['type']
  end
  def field_type= t
    self['type'] = t
  end
  def field_value
    self['value']
  end
  def field_value= v
    self['value'] = v
    extend_meta_classes
  end
  def field_label
    self['label']
  end
  def field_label= l
    self['label']= l
  end
  def str_ref
    self['str_ref'] || DEFAULT_STR_REF
  end
  def str_ref= s
    self['str_ref'] = s.to_i
  end

  def has_str_ref?
    str_ref != DEFAULT_STR_REF
  end

  # Returns the path to this field, including all parents structs.
  # For example: UTI/PropertiesList/CostTable
  def path
    raise NWN::Gff::GffError, "field not bound to a parent" unless @parent
    parent_path = @parent.path
    parent_path + "/" + field_label
  end

  # This extends this field object and its' value with the
  # appropriate meta classes, depending on field_type.
  def extend_meta_classes
    field_klass_name = field_type.to_s.capitalize
    field_klass = NWN::Gff.const_defined?(field_klass_name) ?
      NWN::Gff.const_get(field_klass_name) : nil
    field_value_klass = NWN::Gff.const_defined?(field_klass_name + 'Value') ?
      NWN::Gff.const_get(field_klass_name + 'Value') : nil

    self.extend(field_klass) unless field_klass.nil? ||
      self.is_a?(field_klass)

    field_value.extend(field_value_klass) unless field_value_klass.nil? ||
      field_value.is_a?(field_value_klass)
  end

  # Validate if +value+ is within bounds of +type+.
  def self.valid_for? value, type
    case type
      when :char, :byte
        value.is_a?(Fixnum)
      when :short, :word
        value.is_a?(Fixnum)
      when :int, :dword
        value.is_a?(Fixnum)
      when :int64, :dword64
        value.is_a?(Fixnum)
      when :float, :double
        value.is_a?(Float)
      when :resref
        value.is_a?(String) && (1..16).member?(value.size)
      when :cexostr
        value.is_a?(String)
      when :cexolocstr
        value.is_a?(Array)
      when :struct, :list
        value.is_a?(Array)
      when :void
        true
      else
        false
    end
  end
end
