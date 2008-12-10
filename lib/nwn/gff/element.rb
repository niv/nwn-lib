# A Element wraps a GFF label->value pair,
# provides a +.type+ and, optionally,
# a +.str_ref+ for CExoLocStrings.
#
# Fields:
# [+label+]  The label of this element, for reference.
# [+type+]   The type of this element. (See NWN::Gff)
# [+value+]  The value of this element.
class NWN::Gff::Element
  NonInline = [:struct, :list, :cexolocstr]

  attr_accessor :label, :type, :value, :str_ref

  # The parent struct
  attr_accessor :parent

  def initialize label = nil, type = nil, value = nil
    @label, @type, @value = label, type, value
  end

  def validate path_prefix = "/"
    raise NWN::Gff::GffTypeError, "#{path_prefix}#{self.label}: New value #{self.value} is not compatible with the current type #{self.type}" unless
      self.class.valid_for?(self.value, self.type)
  end

#       0 => :byte,
#       1 => :char,
#       2 => :word,
#       3 => :short,
#       4 => :dword,
#       5 => :int,
#       6 => :dword64,
#       7 => :int64,
#       8 => :float,
#       9 => :double,
#       10 => :cexostr,
#       11 => :resref,
#       12 => :cexolocstr,
#       13 => :void,
#       14 => :struct,
#       15 => :list,

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
