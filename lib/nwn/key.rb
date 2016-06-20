module NWN
  module Key

    # A Bif object encapsulates an open file handle pointing
    # to a .bif file. It's contents are indexed on first access,
    # not on creation by NWN::Key::Key (to speed up things).
    class Bif

      # The Key object this Bif belongs to.
      attr_reader :key

      # The IO object pointing to the .bif file.
      attr_reader :io

      # A hash containing the resources contained. Usually not needed,
      # accessed by the encapsulating Key object.
      attr_reader :contained

      def initialize key, io
        @key = key
        @io = io

        @contained = {}

        @file_type, @file_version,
          @var_res_count, @fix_res_count,
          @var_table_offset =
          io.e_read(4 + 4 + 3 * 4, "header").unpack("a4 a4 V V V")

        @io.seek(@var_table_offset)
        data = @io.e_read(@var_res_count * 16, "var res table")
        i = 0
        while (x = data[i, 16]) && x.size == 16
          i += 16
          id, offset, size, restype = x.unpack("V V V V")
          id &= 0xfffff
          @contained[id] = [offset, size, restype]
        end
      end

      def has_res_id? id
        @contained[id] != nil
      end

      def get_res_id id
        offset, size, restype = @contained[id]
        @io.seek(offset)
        @io.e_read(size, "resource #{id} of type #{restype}")
      end
    end

    class Key < NWN::Resources::Container

      # An array of Bif objects contained in this key index.
      # Not needed to access individual files, use Container#content instead.
      attr_reader :bif

      attr_reader :file_type
      attr_reader :file_version
      attr_reader :day_of_year
      attr_reader :year

      # Creates a new Key wrapper. The parameters exepected are an
      # IO object pointing to the .key-file, and the base path in
      # which your data/.bif files can be found. (This is usually your
      # NWN directory, NOT the data/ directory).
      def initialize io, data_path
        super()

        @root = data_path
        @bif = []

        @file_type, @file_version,
          bif_count, key_count,
          offset_to_file_table, offset_to_key_table,
          @year, @day_of_year, reserved =
          io.e_read(8 + (4 * 6) + 32, "header").unpack("A4 A4 VVVVVV a32")

        io.seek(offset_to_file_table)
        data = io.e_read(12 * bif_count, "bif data")

        # Contains all bifs linked in this key
        i = 0
        @file_table = []
        while (x = data[i, 12]) && x.size == 12
          i += 12
          size, name_offset, name_size, drives = x.unpack("VVvv")
          io.seek(name_offset)
          name = io.e_read(name_size, "name table").unpack("A*")[0]
          name.gsub!("\\", File::SEPARATOR)
          name = File.expand_path(@root + File::SEPARATOR + name)

          _io = File.new(name, "r")
          @bif << Bif.new(self, _io)

          @file_table << [size, name, drives]
        end

        @key_table = {}
        io.seek(offset_to_key_table)
        data = io.e_read(22 * key_count, "key table")
        i = 0
        while (x = data[i, 22]) && x.size == 22
          i += 22
          resref, res_type, res_id = x.unpack("A16 v V")
          @key_table[res_id] = [resref, res_type]
        end

        @fn_to_co = {}
        @key_table.each {|res_id, (resref, res_type)|
          bif_index = res_id >> 20
          bif = @bif[bif_index]
          id = res_id & 0xfffff
          bif.contained[id] or fail "#{bif} does not have #{id}"
          ofs, sz, _rt = bif.contained[id]
          o = NWN::Resources::ContentObject.new(resref, res_type, bif.io, ofs, sz)
          if @fn_to_co[o.filename] && @fn_to_co[o.filename][2] < bif_index
            oo, biff = @fn_to_co[o.filename]
            # NWN.log_debug "#{o.filename} in #{biff.io.inspect} shadowed by file of same name in #{bif.io.inspect}"
            remove oo
          end
          @fn_to_co[o.filename] = [o, bif, bif_index]
          add o
        }
      end
    end

    # Get the ContentObject pointing to the given filename.
    # Raises ENOENT if not mapped.
    def get_content_object filename
      filename = filename.downcase
      ret, bif = @fn_to_co[filename]
      raise Errno::ENOENT,
        "No ContentObject with the given filename #{filename.inspect} found." unless
          ret
      ret
    end

    def filenames
      @fn_to_co.indices
    end

  end
end
