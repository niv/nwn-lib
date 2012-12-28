# A Gff::Struct is a hash of label->Element pairs with some
# meta-information in local variables.
module NWN::Gff::Struct
  DEFAULT_DATA_VERSION = "V3.2"

  # The file version. Usually "V3.2". If not given in a source
  # format, DEFAULT_DATA_VERSION is inferred and set for all structs.
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

  def path
    if defined?(@element) && !@element.nil?
      @element.path
    else
      "/"
    end
  end

  # Each Gff::Struct has a data_type, which describes the type of data the struct contains.
  # For top-level structs, this equals the data type written to the GFF file ("UTI",
  # for example); for sub structures, this is usually nil, but can be overriden by
  # users explicitly to carry some meta-data (e.g. explicitly set UTC/ItemList[0] to UTI).
  # This is not done automatically, however.
  #
  # Scripts could use this, for example, to reliably re-attach a Item within
  # /ItemList/ somewhere else, or export it as .uti.
  def data_type
    @data_type
  end

  # Overrides the data type (used by the built-in file format readers).
  def data_type= k
    k = nil if k == ""
    NWN.log_debug("Setting explicit data_type for parented element") if k &&
      defined?(@element) && !@element.nil?
    @data_type = k
  end

  def element= e #:nodoc:
    @element = e
    NWN.log_debug("Re-parenting a struct with explicit data_type #{@data_type.inspect}") if !e.nil? &&
      defined?(@data_type) && !@data_type.nil?
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
  def self.new struct_id = 0xffffffff, data_type = nil, data_version = DEFAULT_DATA_VERSION
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
  def add_field label, type, value = nil, &block
    value ||= NWN::Gff::Field::DEFAULT_VALUES[type] || raise(ArgumentError,
      "type #{type.inspect} requires explicit value")
    self[label] = NWN::Gff::Field.new(label, type, value)
    self[label].parent = self
    yield(self[label]) if block_given?
    if self[label].field_value.is_a?(NWN::Gff::Struct)
      self[label].field_value.element = self[label]
    end
    self[label]
  end


  def method_missing meth, *av, &block # :nodoc:
    if meth.to_s =~ /^add_(.+)$/
      if NWN::Gff::Types.key($1.to_sym)
        av.size >= 1 || av.size <= 2 or raise(NoMethodError,
          "undefined method #{meth} (requires two arguments to infer add_any)")
        t = $1.to_sym
        b = av[1] || NWN::Gff::Field::DEFAULT_VALUES[t] || raise(NoMethodError,
          "undefined method #{meth} (type #{t.inspect} requires explicit value)")
        f = add_field(av[0], t, b, &block)
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
  # paths and the Gff::Field for each element found.

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
  # You can retrieve CExoLocString values by giving the
  # language ID as the last label:
  #  /FirstName/0
  #
  # You can retrieve list values by specifying the index
  # in square brackets:
  #  /SkillList[0]
  #  /SkillList[0]/Rank   => {"Rank"=>{"label"=>"Rank", "value"=>0, "type"=>:byte}}
  #
  # You can directly retrieve field values and types
  # instead of the field itself:
  #  /SkillList[0]/Rank$  => 0
  #  /SkillList[0]/Rank?   => :byte
  #
  # This will raise an error for non-field paths, naturally:
  #  SkillList[0]$        => undefined method `field_value' for {"Rank"=>{"label"=>"Rank", "value"=>0, "type"=>:byte}}:Hash
  #  SkillList[0]?        => undefined method `field_type' for {"Rank"=>{"label"=>"Rank", "value"=>0, "type"=>:byte}}:Hash
  #
  # For CExoLocStrings, you can retrieve the str_ref:
  #  FirstName%           => 4294967295
  # This will return DEFAULT_STR_REF (0xffffffff) if the given path does not have
  # a str_ref.
  def by_path path
    struct = self
    current_path = ""
    path = path.split('/').map {|v| v.strip }.reject {|v| v.empty?}.join('/')

    path, mod = $1, $2 if path =~ /^(.+?)([\$\?%])?$/

    path.split('/').each_with_index {|v, path_index|
      if struct.is_a?(NWN::Gff::Field) && struct.field_type == :cexolocstr &&
          v =~ /^\d+$/ && path_index == path.split('/').size - 1
        struct = struct.field_value[v.to_i]
        break
      end

      v, index = $1, $2 if v =~ /^(.+?)\[(\d+)\]$/

      struct = struct.v if struct.is_a?(NWN::Gff::Field) &&
        struct.field_type == :struct

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

    case mod
      when "$"
        struct.field_value
      when "?"
        struct.field_type
      when "%"
        struct.has_str_ref? ? struct.str_ref :
          NWN::Gff::Cexolocstr::DEFAULT_STR_REF
      else
        struct
    end
  end

  # An alias for +by_path+.
  def / path
    by_path(path)
  end
end
