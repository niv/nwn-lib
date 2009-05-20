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
        @year = Time.now.year
        @description_str_ref = 0xffffffff
        @day_of_year = Time.now.yday
        read_from io if io
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
        header = @io.read(160)
        raise IOError, "Cannot read header: Not a erf file?" unless
          header && header.size == 160

        @file_type, @file_version,
        locstr_count, locstr_size,
        entry_count,
        offset_to_locstr, offset_to_keys,
        offset_to_res,
        @year, @day_of_year, @description_str_ref = header.
          unpack("A4 A4 VV VV VV VV V a116")

        raise IOError, "Cannot read erf stream: invalid type #{@file_type.inspect}" unless
          NWN::Erf::ValidTypes.index(@file_type)

        fnlen = filename_length @file_version

        @io.seek(offset_to_locstr)
        locstr = @io.read(locstr_size)

        for lstr in 0...locstr_count do
          raise IOError, "locstr table does not contain enough entries or locstr_size is too small" if
            locstr.nil? || locstr.size < 8

          lid, strsz = locstr.unpack("V V")
          str = locstr.unpack("x8 a#{strsz}")[0]
          raise IOError,
            "Expected locstr size does not match actual string size (want: #{strsz}, got #{str.size} of #{str.inspect})" if
              strsz != str.size

          @localized_strings[lid] = str
          locstr = locstr[8 + str.size .. -1]
        end

        keylist_entry_size = fnlen + 4 + 2 + 2
        @io.seek(offset_to_keys)
        keylist = @io.read(keylist_entry_size * entry_count)
        raise IOError, "keylist too short" if keylist.size != keylist_entry_size * entry_count
        keylist = keylist.unpack("A#{fnlen} V v v" * entry_count)
        keylist.each_slice(4) {|resref, res_id, res_type, unused|
          @content << NWN::Resources::ContentObject.new(resref, res_type, @io)
        }

        resourcelist_entry_size = 4 + 4
        @io.seek(offset_to_res)
        resourcelist = @io.read(resourcelist_entry_size * entry_count)
        raise IOError, "resource list too short" if resourcelist.size != resourcelist_entry_size * entry_count
        resourcelist = resourcelist.unpack("I I" * entry_count)
        _index = -1
        resourcelist.each_slice(2) {|offset, size|
          _index += 1
          @content[_index].offset = offset
          @content[_index].size_override = size
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
        reslist = @content.map {|c| [c.offset, c.size].pack("V V") }.join("")

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
