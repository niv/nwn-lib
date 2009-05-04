# A Field wraps a GFF label->value pair, providing:
# * +.field_type+ describing the field type (e.g. :int)
# * +.field_value+ holding the value of this Field

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
  # The parent struct.
  # This is set internally by Gff::Reader on load.
  attr_accessor :parent

  # Create a new NWN::Gff::Field
  def self.new label, type, value
    s = {}.extend(self)
    s['label'], s['type'], s['value'] = label, type, value
    s.extend_meta_classes
    s
  end

  def field_type
    self['type']
  end
  alias :t :field_type

  def field_type= t
    self['type'] = t
  end
  alias :t= :field_type=

  def field_value
    self['value']
  end
  alias :v :field_value

  def field_value= v
    NWN::Gff::Field.valid_for?(v, field_type) or raise ArgumentError,
      "Given field_value is not valid for type #{field_type.inspect}."

    self['value'] = v
  end
  alias :v= :field_value=

  def field_label
    self['label']
  end
  alias :l :field_label

  def field_label= l
    self['label']= l
  end
  alias :l= :field_label=

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
    return if field_type == :struct

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

  # Validate if this field value is within the bounds of the set type.
  def valid?
    NWN::Gff::Field.valid_for? self.v, self.t
  end

  # Validate this field, and raise an Excpetion if not valid.
  def validate
    valid? or raise NWN::Gff::GffError,
      "#{self.path rescue $!.to_s + '/' + self.v.label}: " +
        "value '#{self.v.inspect}' not valid for type '#{self.t.inspect}'"
  end

  # Validate if +value+ is within bounds of +type+.
  def self.valid_for? value, type
    case type
      when :byte, :char
        value.is_a?(Integer) && value >= 0 && value <= 255

      when :short
        value.is_a?(Integer) && value >= -0x8000 && value <= 0x7fff
      when :word
        value.is_a?(Integer) && value >= 0 && value <= 0xffff

      when :int
        value.is_a?(Integer) && value >= -0x80000000 && value <= 0x7fffffff
      when :dword
        value.is_a?(Integer) && value >= 0 && value <= 0xffffffff

      when :int64
        value.is_a?(Integer) && value >= -0x800000000000 && value <= 0x7fffffffffff
      when :dword64
        value.is_a?(Integer) && value >= 0 && value <= 0xffffffffffff

      when :float, :double
        value.is_a?(Float)

      when :resref
        value.is_a?(String) && (0..16).member?(value.size)

      when :cexostr
        value.is_a?(String)

      when :cexolocstr
        value.is_a?(Hash) &&
          value.keys.reject {|x| x.is_a?(Fixnum) && x >= 0 }.size == 0 &&
          value.values.reject {|x| x.is_a?(String) }.size == 0

      when :struct
        value.is_a?(Hash)

      when :list
        value.is_a?(Array)

      when :void
        value.is_a?(String)

      else
        false
    end
  end
end
