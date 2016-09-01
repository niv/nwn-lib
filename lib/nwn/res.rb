module NWN
  module Resources

    # This is a generic index to a resource.
    class ContentObject
      attr_accessor :resref
      attr_accessor :res_type
      attr_accessor :io
      attr_accessor :offset
      attr_accessor :size_override

      # Create a new index to +filename+, optionally specifying +io+.
      def self.new_from filename, io = nil
        FileTest.exists?(filename) or raise Errno::ENOENT unless io

        filename = File.expand_path(filename)
        base = File.basename(filename).split(".")[0..-2].join(".").downcase
        ext = File.extname(filename)[1..-1].downcase rescue ""
        res_type = NWN::Resources::Extensions[ext] or raise ArgumentError,
          "Not a valid extension: #{ext.inspect} (while packing #{filename})"

        ContentObject.new(base, res_type, io || filename, 0, io ? io.size : File.stat(filename).size)
      end

      def initialize resref, res_type, io = nil, offset = nil, size = nil
        @resref, @res_type = resref.downcase, res_type
        @io, @offset = io, offset
        @size_override = size

        raise ArgumentError, "Invalid object passed: responds_to :read, want @offset, but does not respond_to :seek" if
          @io.respond_to?(:read) && @offset && @offset != 0 && !@io.respond_to?(:seek)
      end

      # Get the size in bytes of this object.
      def size
        @size ||= (@size_override || (@io.is_a?(IO) ? @io.stat.size : File.stat(@io).size))
      end

      # Get the contents of this object. This is a costly operation, loading
      # the whole buffer. If you want fine-grained access, use ContentObject#io
      # and do it yourself, observing ContentObject#offset and ContentObject#size.
      def get
        if @io.respond_to?(:read)
          @io.seek(@offset ? @offset : 0)
          @io.e_read(self.size, "filename = #{filename}")
        else
          IO.read(@io)
        end
      end

      # Get the canonical filename of this object.
      def filename
        @filename ||= (@resref + "." + (self.extension || "unknown-#{@res_type}"))
      end

      # Get the extension of this object.
      def extension
        @extension ||= NWN::Resources::Extensions.key(@res_type)
      end
    end

    # Wraps n ContentObjects; a baseclass for erf/key encapsulation.
    class Container

      # An array of all ContentObjects indexed by this Container.
      # Do not modify, use add/remove instead.
      attr_reader :content

      # A hash containing filename.downcase => ContentObject.
      # Do not modify, use add/remove instead.
      attr_reader :content_by_filename

      def initialize
        @content = []
        @content_by_filename = {}
      end

      # Returns true if the given filename is contained herein.
      # Case-insensitive.
      def has?(filename)
        @content_by_filename[filename.downcase] != nil
      end

      # Add a content object giving a +filename+ and a optional
      # +io+.
      def add_file filename, io = nil
        add ContentObject.new_from(filename, io)
      end

      # Add a content object giving the ContentObject
      def add o
        @content << o
        @content_by_filename[o.filename.downcase] = o
        @filenames = nil
      end

      # Removes a content object by filename.
      # Raises ENOENT if no object by that name is contained.
      def remove_file filename
        @content_by_filename[filename.downcase] or raise Errno::ENOENT,
          "No ContentObject with the given filename #{filename.inspect} found."

        remove @content_by_filename[filename.downcase]
      end

      def remove o
        @content.delete(o)
        @content_by_filename.delete(o.filename)
        @filenames = nil
      end

      # Returns a list of filenames, all lowercase.
      def filenames
        @filenames ||= @content_by_filename.keys
      end

      # Get the ContentObject pointing to the given filename.
      # Raises ENOENT if not mapped.
      def get_content_object filename
        @content_by_filename[filename.downcase] or raise Errno::ENOENT,
          "No ContentObject with the given filename #{filename.inspect} found."
      end

      # Get the contents of the given filename.
      # Raises ENOENT if not mapped.
      def get filename
        get_content_object(filename).get
      end
    end

    # A Container that directly wraps a directory (e.g. override/).
    # Does not update on changes - caches the directory entries on initialize.
    class DirectoryContainer < Container
      def initialize path
        super()
        @path = path
        Dir[path + File::SEPARATOR + "*.*"].each {|x|
          begin add_file x
          rescue ArgumentError => e
            NWN.log_debug e.to_s
          end
        }
      end
    end

    # The resource manager, providing ordered access to Container objects.
    class Manager
      def initialize
        @path = []
        @_content_cache = nil
      end

      def add_container c
        @path << c
      end

      # Get the ContentObject pointing to the given filename.
      # Raises ENOENT if not mapped.
      def get_content_object filename
        @path.reverse.each {|con|
          con.has?(filename) or next
          return con.get_content_object(filename)
        }
        raise Errno::ENOENT, "No ContentObject with the given filename #{filename.inspect} found."
      end

      # Get the contents of the given filename.
      # Raises ENOENT if not mapped.
      def get filename
        get_content_object(filename).get
      end

      # Get a list of filenames contained inside.
      def content
        @_content_cache ||= @path.inject([]) {|a, x|
          a |= x.filenames
        }
      end
    end

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

  end
end
