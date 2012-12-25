class NWN::Gff::Writer
  include NWN::Gff

  private_class_method :new

  attr_reader :bytes

  # Takes a NWN::Gff::Gff object and dumps it to +io+,
  # including the header.
  # If +io+ is nil, return the raw bytes, otherwise
  # the number of bytes written.
  def self.dump(gff, io = nil, data_type = nil)
    ret = new(gff, data_type).bytes
    if io
      io.write(ret)
      ret.size
    else
      ret
    end
  end

  def initialize(gff, data_type = nil) #:nodoc:
    @gff = gff
    @data_type = data_type

    @structs = []
    @fields = []
    @labels = []
    @field_indices = []
    @list_indices = []
    @field_data = ""

    write_all
  end

private

  def get_label_id_for_label str
    @labels << str unless @labels.index(str)
    @labels.index(str)
  end

  def add_data_field type, label, content
    label_id = get_label_id_for_label label
    @fields.push Types.key(type), label_id, content
    (@fields.size - 1) / 3
  end

  def write_all
    data = []
    write_struct @gff

    c_offset = 0
    data << [
      @data_type || @gff.data_type,
      @gff.data_version,

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

    ].pack("A4a4 VV VV VV VV VV VV")

    data << @structs.pack("V*")
    data << @fields.pack("V*")
    data << @labels.pack("a16" * @labels.size)
    data << @field_data
    data << @field_indices.pack("V*")
    data << @list_indices.pack("V*")

    @bytes = data.join("")
  end

  def write_struct struct
    raise GffError, "struct invalid: #{struct.inspect}" unless struct.is_a?(NWN::Gff::Struct)
    raise GffError, "struct_id missing from struct" unless struct.struct_id

    # This holds all field label ids this struct has as a member
    fields_of_this_struct = []

    # This will hold the index of this struct
    index = @structs.size / 3

    @structs.push struct.struct_id, 0, 0

    struct.sort.each {|k,v|
      raise GffError, "Empty label." if !k || k == ""

      case v.field_type
        # simple data types
        when :byte, :char, :word, :short, :dword, :int, :float
          format = Formats[v.field_type]
          fields_of_this_struct << add_data_field(v.field_type, k, [v.field_value].pack(format).unpack("V")[0])

        # complex data types
        when :dword64, :int64, :double, :void
          fields_of_this_struct << add_data_field(v.field_type, k, @field_data.size)
          format = Formats[v.field_type]
          @field_data << case v.field_type
            when :dword64
              [
                ( v.field_value / (2**32) ) & 0xffffffff,
                v.field_value % (2**32)
              ].pack("II")
            when :void
              [ v.field_value.size, v.field_value ].pack("Va*")
            else
              [v.field_value].pack(format)
          end

        when :struct
          raise GffError, "type = struct, but value not a hash" unless
            v.field_value.is_a?(Struct)

          fields_of_this_struct << add_data_field(v.field_type, k, write_struct(v.field_value))

        when :list
          raise GffError, "type = list, but value not an array" unless
            v.field_value.is_a?(Array)

          fields_of_this_struct << add_data_field(v.field_type, k, 4 * @list_indices.size)

          count = v.field_value.size
          tmp = @list_indices.size
          @list_indices << count
          count.times {
            @list_indices << 0
          }

          v.field_value.each_with_index do |kk, idx|
            vv = write_struct(kk)
            @list_indices[ idx + tmp + 1 ] = vv
          end

        when :resref
          fields_of_this_struct << add_data_field(v.field_type, k, @field_data.size)
          fv = v.field_value.encode(NWN.setting :in_encoding)
          @field_data << [fv.size, fv].pack("Ca*")

        when :cexostr
          fields_of_this_struct << add_data_field(v.field_type, k, @field_data.size)
          fv = v.field_value.encode(NWN.setting :in_encoding)
          @field_data << [fv.size, fv].pack("Va*")

        when :cexolocstr
          raise GffError, "type = cexolocstr, but value not a hash (#{v.field_value.class})" unless
            v.field_value.is_a?(Hash)

          fields_of_this_struct << add_data_field(v.field_type, k, @field_data.size)

          # total size (4), str_ref (4), str_count (4)
          total_size = 8
          v.field_value.each {|kk,vv|
            total_size += vv.size + 8
          }
          @field_data << [
            total_size,
            v.str_ref,
            v.field_value.size
          ].pack("VVV")

          v.field_value.each {|k,v|
            vn = v.encode(NWN.setting :in_encoding)
            @field_data << [k, vn.size, vn].pack("VVa*")
          }

        else
          raise GffError, "Unknown data type: #{v.field_type}"
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
