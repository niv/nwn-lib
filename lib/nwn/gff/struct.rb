# A Gff::Struct is a hash of label->Element pairs with some
# meta-information in local variables.
module NWN::Gff::Struct
  DEFAULT_DATA_VERSION = "V3.2"

  # Each Gff::Struct has a data_type, which describes the type of data the struct contains.
  # For top-level structs, this equals the data type written to the GFF file ("UTI",
  # for example); for sub structures, this is usually the top-level data type + the
  # field label ("UTI/PropertiesList", for example).
  #
  # This is set for completeness' sake, but is not required to save the struct.
  # Scripts could use this, for example, to reliably re-attach a Item within
  # /ItemList/ somewhere else, or export it as .uti.
  attr_accessor :data_type

  # The file version. Usually "V3.2" for root structs,
  # and nil for sub-structs.
  attr_accessor :data_version

  # GFF struct type. The default is 0xffffffff.
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


  # Iterates this struct, yielding flat, absolute
  # pathes and the Gff::Field for each element found.

  # Example:
  # "/AddCost" => {"type"=>:dword, ..}
  def each_by_flat_path prefix = "/", &block
    sort.each {|label, field|
      field.each_by_flat_path do |ll, lv|
        yield(prefix + label + ll, lv)
      end
    }
  end

  # Retrieve an object from within the given tree.
  # Path is a slash-separated destination, given as
  # a string
  #
  # Prefixed/postfixed slashes are optional.
  #
  # Examples:
  # /
  # /AddCost
  # /PropertiesList/
  # /PropertiesList[0]/CostValue
  # /LocalizedName/0
  def by_path path
    struct = self
    current_path = ""
    path = path.split('/').map {|v| v.strip }.reject {|v| v.empty?}.join('/')

    path.split('/').each {|v|
      if v =~ /^(.+?)\[(\d+)\]$/
        v, index = $1, $2
      end

      struct = struct[v]
      if index
        struct.field_type == :list or raise NWN::Gff::GffPathInvalidError,
          "Specified a list offset for a non-list item: #{v}[#{index}]."

        struct = struct.field_value[index.to_i]
      end

      raise NWN::Gff::GffPathInvalidError,
        "Cannot find a path to /#{path} (at: #{current_path})." unless struct

      current_path += "/" + v
      current_path += "[#{index}]" if index
    }

    struct
  end

end
