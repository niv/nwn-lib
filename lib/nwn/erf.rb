require 'enumerator'

module NWN
  module Erf
    ValidTypes = %w{ERF HAK MOD}

    # This reads and writes NWN::Resources::Container
    # as valid ERF binary data.
    class Erf < NWN::Resources::Container

      attr_accessor :localized_strings
      attr_accessor :description_str_ref

      attr_accessor :file_type
      attr_accessor :file_version
      attr_accessor :day_of_year
      attr_accessor :year

      # Create a new Erf object, optionally reading a existing file from +io+.
      def initialize io = nil
        super()
        @localized_strings = {}
        @io = io
        @file_type, @file_version = "ERF", "V1.0"
        @year = Time.now.year - 1900
        @description_str_ref = 0xffffffff
        @day_of_year = Time.now.yday
        read_from io if io
      end

      def add_file filename, io = nil
        fnlen = filename_length @file_version
        raise ArgumentError, "Invalid filename: #{filename.inspect}" if
          filename.size == 0 || filename.size > (fnlen + 4)
        super(filename, io)
      end

      def add o
        fnlen = filename_length @file_version
        raise ArgumentError, "Invalid filename: #{o.filename.inspect}" if
          o.resref.size == 0 || o.resref.size > fnlen
        super(o)
      end

    private

      def filename_length version
        case version
          when "V1.0"
            16
          when "V1.1"
            32
        else
          raise IOError, "Invalid ERF version: #{version}"
        end
      end


      def read_from io
        @file_type, @file_version,
        locstr_count, locstr_size,
        entry_count,
        offset_to_locstr, offset_to_keys,
        offset_to_res,
        @year, @day_of_year, @description_str_ref =
          @io.read(160, "header").unpack("A4 A4 VV VV VV VV V a116")

        raise IOError, "Cannot read erf stream: invalid type #{@file_type.inspect}" unless
          NWN::Erf::ValidTypes.index(@file_type)

        fnlen = filename_length @file_version

        @io.seek(offset_to_locstr)
        locstr = @io.e_read(locstr_size, "locstr_size")

        for lstr in 0...locstr_count do
          if locstr.nil? || locstr.size == 0
            NWN.log_debug "locstr table: not enough entries (expected: #{locstr_count}, got: #{lstr})"
            break
          end

          if locstr.size < 8
            NWN.log_debug "locstr table: not enough entries (expected: #{locstr_count}, got: #{lstr})" +
              " partial data: #{locstr.inspect}"
            break
          end

          lid, strsz = locstr.unpack("V V")
          if strsz > locstr.size - 8
            NWN.log_debug "locstr table: given strsz is bigger than available data, truncating"
            strsz = locstr.size - 8
          end
          str = locstr.unpack("x8 a#{strsz}")[0]

          # This just means that the given locstr size was encoded wrongly -
          # the old erf.exe is known to do that.
          NWN.log_debug "Expected locstr size does not match actual " +
            "string size (want: #{strsz}, got #{str.size} of #{str.inspect})" if strsz != str.size

          @localized_strings[lid] = str
          locstr = locstr[8 + str.size .. -1]
        end

        keylist_entry_size = fnlen + 4 + 2 + 2
        @io.seek(offset_to_keys)
        keylist = @io.e_read(keylist_entry_size * entry_count, "keylist")
        keylist = keylist.unpack("A#{fnlen} V v v" * entry_count)

        resourcelist_entry_size = 4 + 4
        @io.seek(offset_to_res)
        resourcelist = @io.e_read(resourcelist_entry_size * entry_count, "reslist")
        resourcelist = resourcelist.unpack("I I" * entry_count)

        _index = 0
        keylist.each_slice(4) {|resref, res_id, res_type, unused|
          co = NWN::Resources::ContentObject.new(resref, res_type, @io)
          offset, size = resourcelist[_index * 2], resourcelist[_index * 2 + 1]
          co.offset = offset
          co.size_override = size
          add co

          _index += 1
        }
      end

    public

      # Writes this Erf to a io stream.
      def write_to io
        fnlen = filename_length @file_version

        locstr = @localized_strings.map {|x| [x[0], x[1].size, x[1]].pack("V V a*") }.join("")
        keylist = @content.map {|c|
          NWN.log_debug "truncating filename #{c.resref}, longer than #{fnlen}" if c.resref.size > fnlen
          [c.resref, @content.index(c), c.res_type, 0].pack("a#{fnlen} V v v")
        }.join("")

        offset = 160 + locstr.size + keylist.size + 8 * @content.size

        reslist = @content.map {|c|
          r = [offset, c.size].pack("V V")
          offset += c.size
          r
        }.join("")

        offset_to_locstr = 160
        offset_to_keylist = offset_to_locstr + locstr.size
        offset_to_resourcelist = offset_to_keylist + keylist.size

        header = [@file_type, @file_version,
          @localized_strings.size, locstr.size,
          @content.size,
          offset_to_locstr, offset_to_keylist,
          offset_to_resourcelist,
          @year, @day_of_year, @description_str_ref, ""].pack("A4 A4 VV VV VV VV V a116")

        io.write(header)
        io.write(locstr)
        io.write(keylist)
        io.write(reslist)

        @content.each {|c|
          io.write(c.get)
        }
      end
    end
  end
end
