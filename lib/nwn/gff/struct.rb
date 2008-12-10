# A Gff::Struct is a hash of label->Element pairs,
# with an added +.struct_id+.
class NWN::Gff::Struct
  attr_accessor :struct_id
  attr_accessor :hash

  def initialize
    @struct_id = 0
    @hash = {}
    super
  end

  def method_missing meth, *a, &block
    @hash.method(meth).call(*a, &block)
  end

  # Sets a NWN::Gff::Element on this struct.
  # Overwrites existing labels.

  # args can be the following:
  # * A single NWN::Gff::Element
  # * A single NWN::Gff::Struct, in which case it will be merged into this one
  # * label, type
  # * label, type, value
  def set *args
    if args.size == 1
      arg = args[0]
      case arg
        when NWN::Gff::Struct
          @hash.merge!(addme)

        when NWN::Gff::Element
          @hash[arg.label] = arg
        else
          raise ArgumentError, "Cannot determine how to handle #{arg.class.to_s}."
      end

    elsif args.size == 2 || args.size == 3
      element = NWN::Gff::Element.new(*args)

      @hash[element.label] = element
    else
      raise ArgumentError, "Cannot determine how to handle #{args.inspect}."
    end
  end
end
