module NWN
  module Tlk
    Languages = {
      0 => :english,
      1 => :french,
      2 => :german,
      3 => :italian,
      4 => :spanish,
      5 => :polish,
      128 => :korean,
      129 => :chinese_traditional,
      130 => :chinese_simplified,
      131 => :japanese,
    }.freeze

    ValidGender = [:male, :female].freeze

    # Tlk wraps a File object that points to a .tlk file.
    class Tlk
      HEADER_SIZE = 20
      DATA_ELEMENT_SIZE = 4 + 16 + 4 + 4 + 4 + 4 + 4

      # The number of strings this Tlk holds.
      attr_reader :size

      # The language_id of this Tlk.
      attr_reader :language

      attr_reader :cache

      # Cereate
      def initialize io
        @io = io

        # Read the header
        @file_type, @file_version, language_id,
          string_count, string_entries_offset =
            @io.e_read(HEADER_SIZE, "header").unpack("A4 A4 I I I")

        raise IOError, "The given IO does not describe a valid tlk table" unless
          @file_type == "TLK" && @file_version == "V3.0"

        @size = string_count
        @language = language_id
        @entries_offset = string_entries_offset

        @cache = {}
      end

      # Returns a TLK entry as a hash with the following keys:
      #  :text          string: The text
      #  :sound         string: A sound resref, or "" if no sound is specified.
      #  :sound_length  float: Length of the given resref (or 0.0 if no sound is given).
      #
      # id is the numeric offset within the Tlk, starting at 0.
      # The maximum is Tlk#size - 1.
      def [](id)
        return { :text => "", :sound => "", :sound_length => 0.0, :volume_variance => 0, :pitch_variance => 0} if id == 0xffffffff

        return @cache[id] if @cache[id]

        raise ArgumentError, "No such string ID: #{id.inspect} (size: #{@size})" if id > (self.size-1) || id < 0
        seek_to = HEADER_SIZE + (id) * DATA_ELEMENT_SIZE
        @io.seek(seek_to)
        data = @io.e_read(DATA_ELEMENT_SIZE, "tlk entry = #{id}")

        flags, sound_resref, v_variance, p_variance, offset,
          size, sound_length = data.unpack("I A16 I I I I f")
        flags = flags.to_i

        @io.seek(@entries_offset + offset)
        text = @io.e_read(size, "tlk entry = #{id}, offset = #{@entries_offset + offset}")

        text = flags & 0x1 > 0 ? text : ""
        sound = flags & 0x2 > 0 ? sound_resref : ""
        sound_length = flags & 0x4 > 0 ? sound_length.to_f : 0.0

        @cache[id] = {
          :text => text, :sound => sound, :sound_length => sound_length,
          :volume_variance => v_variance, :pitch_variance => p_variance
        }
      end

      # Add a new entry to this Tlk and return the strref given to it.
      # To override existing entries, use tlk[][:text] = ".."
      def add text, sound = "", sound_length = 0.0, v_variance = 0, p_variance = 0
        next_id = self.size + 1
        $stderr.puts "put in cache: #{next_id}"
        @cache[next_id] = {:text => text, :sound => sound, :sound_length => 0.0, :volume_variance => v_variance, :pitch_variance => p_variance}
        @size += 1
        next_id
      end

      # Write this Tlk to +io+.
      # Take care not to write it to the same IO object you are reading from.
      def write_to io
        header = [
          @file_type,
          @file_version,
          @language,
          self.size,
          HEADER_SIZE + (self.size) * DATA_ELEMENT_SIZE
        ].pack("A4 A4 I I I")
        io.write(header)

        offsets = []
        offset = 0
        for i in 0...@size do
          entry = self[i]
          offsets[i] = offset
          offset += entry[:text].size
        end

        entries = []
        for i in 0...@size do
          entry = self[i]
          text, sound, sound_length = entry[:text], entry[:sound], entry[:sound_length]
          flags = 0
          flags |= 0x01 if text.size > 0
          flags |= 0x02 if sound.size > 0
          flags |= 0x04 if sound_length > 0.0

          ev_s = [
            flags,
            sound, #resref
            entry[:volume_variance],
            entry[:pitch_variance],
            offsets[i],
            text.size,
            sound_length
          ].pack("I a16 I I I I f")

          io.write(ev_s)
        end

        for i in 0...@size do
          io.write(self[i][:text])
        end
      end
    end

    # A TlkSet wraps a set of File objects, each pointing to the respective tlk file, making
    # retrieval easier.
    class TlkSet
      # The default male Tlk.
      attr_reader :dm
      # The default female Tlk, (or the default male).
      attr_reader :df
      # The custom male Tlk, or nil.
      attr_reader :cm
      # The custom female Tlk, if specified (cm if no female custom tlk has been specified, nil if none).
      attr_reader :cf

      def initialize tlk, tlkf = nil, custom = nil, customf = nil
        @dm = Tlk.new(tlk)
        @df = tlkf ? Tlk.new(tlkf) : @dm
        @cm = custom ? Tlk.new(custom) : nil
        @cf = customf ? Tlk.new(customf) : @cm
      end

      def [](id, gender = :male)
        raise ArgumentError, "Invalid Tlk ID: #{id.inspect}" if id > 0xffffffff
        (if id < 0x01000000
          gender == :female && @df ? @df : @dm
        else
          raise ArgumentError, "Wanted a custom ID, but no custom talk table has been specified." unless @cm
          id -= 0x01000000
          gender == :female && @cf ? @cf : @cm
        end)[id]
      end
    end
  end
end

