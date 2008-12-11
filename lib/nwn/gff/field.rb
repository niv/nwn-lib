# A Field wraps a GFF label->value pair,
# provides a +.field_type+ and, optionally,
# a +.str_ref+ for CExoLocStrings.
#
# Fields:
# [+label+]  The label of this element, for reference.
# [+type+]   The type of this element. (See NWN::Gff)
# [+value+]  The value of this element.
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
  end

#:stopdoc:
# Used internally, usually.
  def field_label
    self['label']
  end
  def field_label= l
    self['label']= l
  end
#:startdoc:

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
