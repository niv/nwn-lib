# A Gff::Struct is a hash of label->Element pairs with some
# meta-information in local variables.
module NWN::Gff::Struct
  DEFAULT_DATA_VERSION = "V3.2"

  # The file-type this struct represents.
  # This is usually the file extension for root structs,
  # and nil for sub-structs.
  attr_accessor :data_type

  # The file version. Usually "V3.2" for root structs,
  # and nil for sub-structs.
  attr_accessor :data_version

  # GFF struct type
  attr_accessor :struct_id

  # The field this struct is value of.
  # It is most likely a Field of :list, or
  # :nil if it is the root struct.
  # Setting this to a value detaches this struct from
  # the old parent (though the old parent Field may still
  # point to this object).
  attr_reader :element

  # Returns the path to this struct (which is usually __data_type)
  def path
    @data_type.to_s
  end

  def element= e #:nodoc:
    @element = e
    @data_type = self.element.parent.path + "/" + self.element.l
  end

  # Dump this struct as GFF binary data.
  #
  # Optionally specify data_type and data_version
  def to_gff data_type = nil
    NWN::Gff::Writer.dump(self, data_type)
  end

  # Create a new struct.
  # Usually, you can leave out data_type and data_version for non-root structs,
  # because that will be guess-inherited based on the existing associations.
  #
  # You can pass a block to this method, which will receive the newly-created
  # Struct as the only argument.
  def self.new struct_id = 0xffffffff, data_type = nil, data_version = nil
    s = {}.extend(self)
    s.struct_id = struct_id
    s.data_type = data_type
    s.data_version = data_version
    yield(s) if block_given?
    s
  end

  # Create a new field.
  # Alternatively, you can use the shorthand methods:
  #   add_#{type} - add_int, add_byte, ..
  # For example:
  #  some_struct.add_field 'ID', :byte, 5
  # is equivalent to:
  #  some_struct.add_byte 'ID', 5
  #
  # You can pass a block to this method, which will receive the newly-created
  # Field as an argument.
  #
  # This allows for code like this:
  #  Gff::Struct.new(0) do |s|
  #    s.add_byte "Byte", 5
  #    s.add_list "Some_List", [] do |l|
  #      l.v << Gff::Struct.new ...
  #      ..
  #    end
  #  end
  def add_field label, type, value, &block
    self[label] = NWN::Gff::Field.new(label, type, value)
    self[label].parent = self
    yield(self[label]) if block_given?
    self[label]
  end

  def method_missing meth, *av, &block # :nodoc:
    if meth.to_s =~ /^add_(.+)$/
      if NWN::Gff::Types.index($1.to_sym)
        av.size == 2 or super
        t = $1.to_sym
        f = add_field(av[0], t, av[1], &block)
        return f
      else
        super
      end
    end

    super
  end

  def to_s
    "<NWN::Gff::Struct #{self.data_type}/#{self.data_version}, #{self.keys.size} fields>"
  end
end
