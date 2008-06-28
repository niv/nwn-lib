module NWN
  module Gff
    # This error gets thrown if reading or writing fails.
    class GffError < Exception; end

    # This error gets thrown if a supplied value does not
    # fit into the given data type, or you are trying to assign
    # a type to something that does not hold type.
    #
    # Example: You're trying to pass a value greater than 2**32
    # into a int.
    class GffTypeError < Exception; end

    # Gets raised if you are trying to access a path that does
    # not exist.
    class GffPathInvalidError < Exception; end

    # This hash lists all possible NWN::Gff::Element types.
    Types = {
      0 => :byte,
      1 => :char,
      2 => :word,
      3 => :short,
      4 => :dword,
      5 => :int,
      6 => :dword64,
      7 => :int64,
      8 => :float,
      9 => :double,
      10 => :cexostr,
      11 => :resref,
      12 => :cexolocstr,
      13 => :void,
      14 => :struct,
      15 => :list,
    }.freeze

#:stopdoc:
# Used internally to figure out if a field is stored directly
# or by reference.
    ComplexTypes = [6, 7, 9, 10, 11, 12, 13, 14, 15].freeze
    SimpleTypes = (Types.keys - ComplexTypes)
    SimpleTypes.freeze
#:startdoc:

    Formats = {
      :byte => "Cxxx",
      :char => "Cxxx",
      :word => 'Sxx',
      :short => 'sxx',
      :dword => 'I',
      :int => 'i',
      :dword64 => 'II',
      :int64 => 'q',
      :float => 'f',
      :double => 'd',
    }.freeze
  end
end

# A GFF object encapsulates a whole GFF identity, with a type,
# version, and a root structure.
# This object also provides easy accessors for labels and values.
class NWN::Gff::Gff
  include NWN::Gff

  attr_accessor :type
  attr_accessor :version

  # Create a new GFF object from the given +struct+.
  # This is normally not needed unless you are creating
  # GFF objects entirely from hand.
  #
  # See NWN::Gff::Reader.
  def initialize struct, type, version = "V3.2"
    @hash = struct
    @type = type
    @version = version
  end

  # Return the root struct of this GFF.
  def root_struct
    @hash
  end

  # A simple accessor that can be used to
  # retrieve or set properties in the struct, delimited by slashes.
  #
  # Will raise a GffPathInvalidError if the given path cannot be found,
  # and GffTypeError if some type fails to validate.
  #
  # Examples (with +gff+ assumed to be a item):
  #  gff['/Tag']
  #    will retrieve the Tag of the given object
  #  gff['/Tag'] = 'Test'
  #    Set the Tag to 'Test'
  #  gff['/PropertiesList']
  #    will retrieve an array of Gff::Elements
  #  gff['/PropertiesList[1]']
  #    will yield element 2 in the list
  #  gff['/'] = NWN::Gff::Element.new('Property', :byte, 14)
  #    will add a new property at the root struct with the name of 'Property', or
  #    overwrite an existing one with the same label.
  #  gff['/PropertiesList[0]'] = 'Test'
  #    This will raise an error (obviously)
  def get_or_set k, new_value = nil, new_type = nil, new_label = nil, new_str_ref = nil
    puts "get_or_set(#{k} = #{new_value})"
    h = self.root_struct
    path = []
    value_path = [h]
    current_value = nil

    k.split('/').each {|v|
      next if v == ""
      path << v

      if current_value.is_a?(Gff::Element) && current_value.type == :list # && v =~ /\[(\d+)\]$/
        puts "value = #{$1}"
        current_value = current_value.value[$1.to_i]
      end

      if h.is_a?(Gff::Element)
        case h.type
          when :cexolocstr
            current_value = h.value.select {|vx| vx.language.to_i == v.to_i}
            current_value = current_value[0] != nil ? current_value[0].text : ''

          when :list
            raise GffPathInvalidError, "List-selector access not implemented yet."

          else
            raise GffPathInvalidError,
              "Tried to access sub-label of a non-complex field: /#{path.join('/')}"

          end
      elsif h.is_a?(Gff::Struct)

        if v =~ /^(.+?)\[(\d+)\]$/
          current_value = h[$1.to_s]
          if current_value.is_a?(Gff::Element) && !current_value.type == :list
            raise GffPathInvalidError, "Tried to access list-index of a non-list at /#{path.join('/')}"
          end
          current_value = current_value.value[$2.to_i]
        else
          current_value = h[v]
        end
      else
        raise GffPathInvalidError, "Unknown sub-field type #{h.class.to_s} at /#{path.join('/')}"
      end

      value_path << current_value
      h = current_value

      raise GffPathInvalidError,
        "Cannot find path: /#{path.join('/')}" if current_value.nil? && !new_value.is_a?(Gff::Element)
    }

    if path.size == 0
      if new_value.is_a?(Gff::Element)
        value_path << h
      else
        raise GffPathInvalidError, "Do not operate on the root struct unless through adding items."
      end
    end

    old_value = current_value.nil? ? nil : current_value.dup

    if new_value.is_a?(Gff::Element)
      new_value.validate
      value_path[-2].delete(current_value)
      value_path[-2][new_value.label] = new_value
    else

      if !new_label.nil?
        # Set a new label
        value_path[-2].delete(current_value.label)
        current_value.label = new_label
        value_path[-2][new_label] = current_value
      end

      if !new_type.nil?
        # Set a new datatype
        raise GffTypeError, "Cannot set a type on a non-element." unless current_value.is_a?(Gff::Element)
        test = current_value.dup
        test.type = new_type
        test.validate

        current_value.type = new_type

      end

      if !new_str_ref.nil?
        # Set a new str_ref
        raise GffTypeError, "specified path is not a CExoStr" unless current_value.is_a?(Gff::CExoString)
        current_value._str_ref = new_str_ref.to_i
      end

      if !new_value.nil?

        case current_value
          when Gff::Element
            test = current_value.dup
            test.value = new_value
            test.validate
            current_value.value = new_value

          when String #means: cexolocstr assignment
            if value_path[-2].is_a?(Gff::Element) && value_path[-2].type == :cexolocstr
              value_path[-2].value.select{|xy| xy.language == path[-1].to_i }[0].text = new_value
            else
              raise GffPathInvalidError, "Dont know how to set #{new_value.class} on #{path.inspect}."
            end
          else
            raise GffPathInvalidError, "Don't know what to do with #{current_value.class} -> #{new_value.class} at /#{path.join('/')}"
        end

      end
    end

    old_value
  end

  def [] k
    get_or_set k
  end

  def []= k, v
    get_or_set k, v
  end

end

# A Element wraps a GFF label->value pair,
# provides a +.type+ and, optionally,
# a +._str_ref+ for CExoLocStrings.
#
# Fields:
# [+label+]  The label of this element, for reference.
# [+type+]   The type of this element. (See NWN::Gff)
# [+value+]  The value of this element.
class NWN::Gff::Element
  attr_accessor :label, :type, :value
  attr_accessor :_str_ref

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

# A Gff::Struct is a hash of label->Element pairs,
# with an added +.struct_id+.
class NWN::Gff::Struct < Hash
  attr_accessor :struct_id
  def initialize *a
    @struct_id = 0
    super
  end
end

# A CExoLocString is a localised CExoString.
#
# Attributes:
# [+language+] The language ID
# [+text+]     The text for this language.
#
# ExoLocStrings in the wild are usually arrays of NWN::Gff:CExoLocString
# (one for each language supplied).
# Note that a CExoLocString is NOT a GFF list, although both are
# represented as arrays.
class NWN::Gff::CExoLocString < Struct.new(:language, :text)
end

# A class that parses binary GFF bytes into ruby-friendly data structures.
class NWN::Gff::Reader
  include NWN::Gff

  attr_reader :hash
  attr_reader :gff

  # Create a new Reader with the given +bytes+ and immediately parse it.
  # This is not needed usually; use Reader.read instead.
  def initialize bytes
    @bytes = bytes
    read_all
  end

  # Reads +bytes+ as gff data and returns a NWN::Gff:Gff object.
  def self.read bytes
    self.new(bytes).gff
  end

  private

  def read_all
    type, version,
    struct_offset, struct_count,
    field_offset, field_count,
    label_offset, label_count,
    field_data_offset, field_data_count,
    field_indices_offset, field_indices_count,
    list_indices_offset, list_indices_count =
      @bytes.unpack("a4a4 VV VV VV VV VV VV")

    raise GffError, "Unknown version #{@version}; not a gff?" unless
      version == "V3.2"

    raise GffError, "struct offset at wrong place, not a gff?" unless
      struct_offset == 56

    struct_len = struct_count * 12
    field_len  = field_count * 16
    label_len  = label_count * 16

    @structs = @bytes[struct_offset, struct_len].unpack("V*")
    @fields  = @bytes[field_offset, field_len].unpack("V*")
    @labels  = @bytes[label_offset, label_len].unpack("A16" * label_count)
    @field_data = @bytes[field_data_offset, field_data_count]
    @field_indices = @bytes[field_indices_offset, field_indices_count].unpack("V*")
    @list_indices = @bytes[list_indices_offset, list_indices_count].unpack("V*")
    # puts "FieldDataOffset = #{field_data_offset}, Count = #{field_data_count}"
    @hash = read_struct 0
    @gff = Gff.new(@hash, type, version)
  end

  # This iterates through a struct and reads all fields into a hash, which it returns.
  def read_struct index
    struct = Gff::Struct.new

    type = @structs[index * 3]
    data_or_offset = @structs[index * 3 + 1]
    count = @structs[index * 3 + 2]

    raise GffError, "struct index #{index} outside of struct_array" if
      index * 3 + 3 > @structs.size + 1

    if count == 1
      lbl, vl = * read_field(data_or_offset)
      struct[lbl] = vl
    else
      return 1 if count == 0
      raise GffError, "struct index not divisable by 4" if
        data_or_offset % 4 != 0
      data_or_offset /= 4
      for i in data_or_offset...(data_or_offset+count)
        lbl, vl = * read_field(@field_indices[i])
        struct[lbl] = vl
      end
    end

    struct.struct_id = type
    struct
  end

  # Reads the field at +index+ and returns [label_name, Gff::Element]
  def read_field index
    gff = {}

    field = Element.new

    index *= 3
    type = @fields[index]
    label_index = @fields[index + 1]
    data_or_offset = @fields[index + 2]
    # puts "Reading field #{index}"
    # puts "Label_index = #{label_index}, label = #{@labels[label_index]}"
    # puts "type = #{type}, data_or_offset = #{data_or_offset}"
    raise GffError, "Label index #{label_index} outside of label array" if
      label_index > @labels.size

    raise GffError, "Field data offset #{data_or_offset} outside of field data block (#{@field_data.size})" if
      ComplexTypes.index(type) && data_or_offset > @field_data.size

    raise GffError, "Unknown field type #{type}." unless Types[type]
    type = Types[type]

    label = @labels[label_index]

    value = case type
      when :byte, :char
        data_or_offset & 0xff

      when :word
        data_or_offset & 0xffff

      when :short
        [(data_or_offset & 0xffff)].pack("S").unpack("s")[0]

      when :dword
        data_or_offset

      when :int
        [data_or_offset].pack("I").unpack("i")[0]

      when :float
        [data_or_offset].pack("V").unpack("f")[0]

      when :dword64
        len = 8
        v1, v2 = @field_data[data_or_offset, len].unpack("II")
        v1 * (2**32) + v2

      when :int64
        len = 8
        @field_data[data_or_offset, len].unpack("q")[0]

      when :double
        len = 8
        @field_data[data_or_offset, len].unpack("d")[0]

      when :cexostr
        len = @field_data[data_or_offset, 4].unpack("V")[0]
        @field_data[data_or_offset + 4, len]

      when :resref
        len = @field_data[data_or_offset, 1].unpack("C")[0]
        @field_data[data_or_offset + 1, len]

      when :cexolocstr
        total_size, str_ref, str_count =
          @field_data[data_or_offset, 12].unpack("VVV")
        all = @field_data[data_or_offset + 12, total_size]
        field._str_ref = str_ref

        r = []
        str_count.times {
          id, len = all.unpack("VV")
          str = all[8, len].unpack("a*")[0]
          all = all[(8 + len)..-1]
          r << Gff::CExoLocString.new(id, str)
        }
        len = total_size + 4
        r

      when :void
        len = @field_data[data_or_offset, 4].unpack("V")
        void = @field_data[data_or_offset + 4, len].unpack("H*")
        raise "void: #{void.inspect}"

      when :struct
        read_struct data_or_offset

      when :list
        list = []

        raise GffError, "List index not divisable by 4" unless
          data_or_offset % 4 == 0

        data_or_offset /= 4

        raise GffError, "List index outside list indices" if
          data_or_offset > @list_indices.size

        count = @list_indices[data_or_offset]

        raise GffError, "List index overflow the list indices array" if
          data_or_offset + count > @list_indices.size

        data_or_offset += 1

        for i in data_or_offset...(data_or_offset + count)
          list << read_struct(@list_indices[i])
        end

        list

    end

    raise GffError, "Field data overflows from the field data block area\
      offset = #{data_or_offset + len}, len = #{@field_data.size}" if
      len && data_or_offset + len > @field_data.size

    field.label = label
    field.type = type
    field.value = value

    [label, field]  #::Gff::Element.new(type,label,value)
  end
end


class NWN::Gff::Writer
  include NWN::Gff

  attr_reader :bytes

  def initialize(gff)
    @gff = gff

    @structs = []
    @fields = []
    @labels = []
    @field_indices = []
    @list_indices = []
    @field_data = ""

    write_all
  end

  # Takes a NWN::Gff::Gff object and dumps it as raw bytes,
  # including the header.
  def self.dump(gff)
    self.new(gff).bytes
  end

private

  def get_label_id_for_label str
    @labels << str unless @labels.index(str)
    @labels.index(str)
  end

  def add_data_field type, label, content
    label_id = get_label_id_for_label label
    @fields.push Types.index(type), label_id, content
    (@fields.size - 1) / 3
  end

  def write_all
    data = []
    write_struct @gff.root_struct

    c_offset = 0
    data << [
      @gff.type,
      @gff.version,

      # Offset of Struct array as bytes from the beginning of the file
      c_offset += 56,
      # Number of elements in Struct array
      @structs.size / 3,

      # Offset of Field array as bytes from the beginning of the file
      fields_start = c_offset += @structs.size / 3 * 12,
      # Number of elements in Field array
      @fields.size / 3,

      # Offset of Label array as bytes from the beginning of the file
      c_offset += @fields.size / 3 * 12,
      # Number of elements in Label array
      @labels.size,

      # Offset of Field Data as bytes from the beginning of the file
      c_offset += @labels.size * 16,
      # Number of bytes in Field Data block
      @field_data.size,

      # Offset of Field Indices array as bytes from the beginning of the file
      c_offset += @field_data.size,
      # Number of bytes in Field Indices array
      @field_indices.size * 4,

      # Offset of List Indices array as bytes from the beginning of the file
      c_offset += @field_indices.size * 4,
      # Number of bytes in List Indices array
      @list_indices.size * 4

    ].pack("a4a4 VV VV VV VV VV VV")

    data << @structs.pack("V*")
    data << @fields.pack("V*")
    data << @labels.pack("a16" * @labels.size)
    data << @field_data
    data << @field_indices.pack("V*")
    data << @list_indices.pack("V*")

    @bytes = data.join("")
  end

  def write_struct struct
    raise GffError, "struct invalid: #{struct.inspect}" unless struct.is_a?(Gff::Struct)
    raise GffError, "struct_id missing from struct" unless struct.struct_id

    # This holds all field label ids this struct has as a member
    fields_of_this_struct = []

    # This will hold the index of this struct
    index = @structs.size / 3

    @structs.push struct.struct_id, 0, 0

    struct.sort.each {|k,v|
      raise GffError, "Empty label." if !k || k == ""

      case v.type
        # simple data types
        when :byte, :char, :word, :short, :dword, :int, :float
          format = Formats[v.type]
          fields_of_this_struct << add_data_field(v.type, k, [v.value].pack(format).unpack("V")[0])

        # complex data types
        when :dword64, :int64, :double, :void
          $stderr.puts "Warning: complex datatypes dword64, int64, double and void are untested."

          fields_of_this_struct << add_data_field(v.type, k, @field_data.size)
          format = Formats[v.type]
          @field_data << case v.type
            when :dword64
              [
                ( v.value / (2**32) ) & 0xffffffff,
                v.value % (2**32)
              ].pack("II")
            when :void
              [ v.value.size, v.value ].pack("VH*")
            else
              [v.value].pack(format)
          end

          raise GffError, "unhandled complex datatype #{v.type}"

        when :struct
          raise GffError, "type = struct, but value not a hash" unless
            v.value.is_a?(Gff::Struct)

          fields_of_this_struct << add_data_field(v.type, k, write_struct(v.value))

        when :list
          raise GffError, "type = list, but value not an array" unless
            v.value.is_a?(Array)

          fields_of_this_struct << add_data_field(v.type, k, 4 * @list_indices.size)

          count = v.value.size
          tmp = @list_indices.size
          @list_indices << count
          count.times {
            @list_indices << 0
          }

          v.value.each_with_index do |kk, idx|
            vv = write_struct(kk)
            @list_indices[ idx + tmp + 1 ] = vv
          end

        when :resref
          fields_of_this_struct << add_data_field(v.type, k, @field_data.size)
          @field_data << [v.value.size, v.value].pack("Ca*")

        when :cexostr
          fields_of_this_struct << add_data_field(v.type, k, @field_data.size)
          @field_data << [v.value.size, v.value].pack("Va*")

        when :cexolocstr
          raise GffError, "type = cexolocstr, but value not an array" unless
            v.value.is_a?(Array)

          fields_of_this_struct << add_data_field(v.type, k, @field_data.size)

          # total size (4), str_ref (4), str_count (4)
          total_size = 8 + v.value.inject(0) {|t,x| t + x.text.size + 8}
          @field_data << [
            total_size,
            v._str_ref,
            v.value.size
          ].pack("VVV")

          v.value.each {|s|
            @field_data << [s.language, s.text.size, s.text].pack("VVa*")
          }


        else
          raise GffError, "Unknown data type: #{v.type}"
      end
    }

    # id/type, data_or_offset, nr_of_fields
    @structs[3 * (index) + 2] = fields_of_this_struct.size

    if fields_of_this_struct.size < 1
    elsif fields_of_this_struct.size == 1
      @structs[3 * (index) + 1] = fields_of_this_struct[0]
    else
      # Offset into field_indices starting where are number of nr_of_fields
      # dwords as indexes into @fields
      @structs[3 * (index) + 1] = 4 * (@field_indices.size)
      @field_indices.push *fields_of_this_struct
    end

    index
  end

end
