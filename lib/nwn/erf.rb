require 'enumerator'

module NWN
  module Erf
    ValidTypes = %w{ERF HAK MOD}

    Extensions = {
      'res' => 0,
      'bmp' => 1,
      'mve' => 2,
      'tga' => 3,
      'wav' => 4,
      'wfx' => 5,
      'plt' => 6,
      'ini' => 7,
      'mp3' => 8,
      'mpg' => 9,
      'txt' => 10,
      'plh' => 2000,
      'tex' => 2001,
      'mdl' => 2002,
      'thg' => 2003,
      'fnt' => 2005,
      'lua' => 2007,
      'slt' => 2008,
      'nss' => 2009,
      'ncs' => 2010,
      'mod' => 2011,
      'are' => 2012,
      'set' => 2013,
      'ifo' => 2014,
      'bic' => 2015,
      'wok' => 2016,
      '2da' => 2017,
      'tlk' => 2018,
      'txi' => 2022,
      'git' => 2023,
      'bti' => 2024,
      'uti' => 2025,
      'btc' => 2026,
      'utc' => 2027,
      'dlg' => 2029,
      'itp' => 2030,
      'btt' => 2031,
      'utt' => 2032,
      'dds' => 2033,
      'bts' => 2034,
      'uts' => 2035,
      'ltr' => 2036,
      'gff' => 2037,
      'fac' => 2038,
      'bte' => 2039,
      'ute' => 2040,
      'btd' => 2041,
      'utd' => 2042,
      'btp' => 2043,
      'utp' => 2044,
      'dft' => 2045,
      'gic' => 2046,
      'gui' => 2047,
      'css' => 2048,
      'ccs' => 2049,
      'btm' => 2050,
      'utm' => 2051,
      'dwk' => 2052,
      'pwk' => 2053,
      'btg' => 2054,
      'utg' => 2055,
      'jrl' => 2056,
      'sav' => 2057,
      'utw' => 2058,
      '4pc' => 2059,
      'ssf' => 2060,
      'hak' => 2061,
      'nwm' => 2062,
      'bik' => 2063,
      'ndb' => 2064,
      'ptm' => 2065,
      'ptt' => 2066,
      'bak' => 2067,
      'osc' => 3000,
      'usc' => 3001,
      'trn' => 3002,
      'utr' => 3003,
      'uen' => 3004,
      'ult' => 3005,
      'sef' => 3006,
      'pfx' => 3007,
      'cam' => 3008,
      'lfx' => 3009,
      'bfx' => 3010,
      'upe' => 3011,
      'ros' => 3012,
      'rst' => 3013,
      'ifx' => 3014,
      'pfb' => 3015,
      'zip' => 3016,
      'wmp' => 3017,
      'bbx' => 3018,
      'tfx' => 3019,
      'wlk' => 3020,
      'xml' => 3021,
      'scc' => 3022,
      'ptx' => 3033,
      'ltx' => 3034,
      'trx' => 3035,
      'mdb' => 4000,
      'mda' => 4001,
      'spt' => 4002,
      'gr2' => 4003,
      'fxa' => 4004,
      'fxe' => 4005,
      'jpg' => 4007,
      'pwc' => 4008,
      'ids' => 9996,
      'erf' => 9997,
      'bif' => 9998,
      'key' => 9999,
    }.freeze

    class Erf

      attr_accessor :content
      attr_accessor :localized_strings
      attr_accessor :description_str_ref

      attr_accessor :file_type
      attr_accessor :file_version
      attr_accessor :day_of_year
      attr_accessor :year

      # Create a new Erf object, optionally reading a existing file from +io+.
      def initialize io = nil
        @content = []
        @localized_strings = {}
        @io = io
        @file_type, @file_version = "ERF", "V1.0"
        @year = Time.now.year
        @description_str_ref = 0xffffffff
        @day_of_year = Time.now.yday # strftime("%j").to_i
        read_from io if io
      end

      def add filename
        @content << ContentObject.new_from(filename)
      end

      def has?(filename)
        base = File.basename(filename)
        @content.each {|f|
          return true if f.filename.downcase == base.downcase
        }
        return false
      end

      class ContentObject
        attr_accessor :resref
        attr_accessor :res_type
        attr_accessor :io
        attr_accessor :offset
        attr_accessor :size_override

        def self.new_from filename
          stat = File.stat(filename)
          base = File.basename(filename).split(".")[0..-2].join(".")
          ext = File.extname(filename)[1..-1]
          res_type = NWN::Erf::Extensions[ext] or raise ArgumentError,
            "Not a valid extension: #{ext.inspect} (while packing #{filename})"

          ContentObject.new(base, res_type, filename, 0, stat.size)
        end

        def initialize resref, res_type, io = nil, offset = nil, size = nil
          @resref, @res_type = resref, res_type
          @io, @offset = io, offset
          @size_override = size
        end

        # Get the size in bytes of this object.
        def size
          @size_override || (@io.is_a?(IO) ? @io.stat.size : File.stat(@io).size)
        end

        def get
          if @io.is_a?(IO)
            @io.seek(@offset) if @offset
            @io.read(self.size)
          else
            IO.read(@io)
          end
        end

        def filename
          @resref + "." + self.extension
        end

        def extension
          NWN::Erf::Extensions.index(@res_type)
        end
      end

    private

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

        if @file_version == "V1.0"
          @filename_length = 16
#        elsif version == "V1.1"
#          @filename_length = 32
        else
          raise IOError, "Invalid erf version: #{@file_version}"
        end

        raise IOError, "key list not after locstr list" unless
          offset_to_keys == offset_to_locstr + locstr_size

        raise IOError, "Offset to locstr list is not after header" if
          offset_to_locstr != 160

        locstr = @io.read(locstr_size)
        raise IOError, "Cannot read locstr list" unless
          locstr.size == locstr_size

        locstrs = locstr.unpack("V V/a*" * locstr_count)
        locstrs.each_slice(3) {|lid, strsz, str|
          $stderr.puts "Expected string size does not match actual string size (want: #{strsz}, got #{str.size} of #{str.inspect})" if
              str.size != strsz
          @localized_strings[lid] = str
        }


        keylist_entry_size = @filename_length + 4 + 2 + 2
        keylist = @io.read(keylist_entry_size * entry_count)
        keylist = keylist.unpack("A16 V v v" * entry_count)
        keylist.each_slice(4) {|resref, res_id, res_type, unused|
          @content << ContentObject.new(resref, res_type, @io)
        }

        resourcelist_entry_size = 4 + 4
        resourcelist = @io.read(resourcelist_entry_size * entry_count)
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
        locstr = @localized_strings.map {|x| [x[0], x[1].size, x[1]].pack("V V a*") }.join("")
        keylist = @content.map {|c| [c.resref, @content.index(c), c.res_type, 0].pack("a16 V v v") }.join("")
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
