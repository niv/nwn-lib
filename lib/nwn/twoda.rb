require 'shellwords'

class Integer
  def xp_to_level
    NWN::TwoDA.get('exptable').rows.each {|row|
      level, exp = row.Level.to_i, row.XP.to_i
      return level - 1 if exp > self
    }
    return nil
  end

  def level_to_xp
    NWN::TwoDA.get('exptable').by_col("XP", self - 1).to_i
  end
end

module NWN
  module TwoDA

    # A Row is simply an Array with some helpers.
    # It wraps a data row in a TwoDA::Table.
    #
    # You can access Table columns in a row by simply
    # calling a method with the same name.
    #
    # For example (spells.2da):
    #
    #  table.rows.select {|x| x.Wiz_Sorc == "9" }
    #
    # selects all level 9 arcane spells.
    class Row < Array
      attr_accessor :table

      # Returns the id of this row.
      def ID
        @table.rows.index(self)
      end

      def method_missing meth, *args
        if idx = @table.columns.index(meth.to_s.downcase) || idx = @table.columns.index(meth.to_s)
          if meth.to_s =~ /=$/
            self[idx] = args.shift or raise ArgumentError,
              "Need a paramenter for assignments .."
          else
            self[idx]
          end
        else
          super
        end
      end
    end

    class Table
      CELL_PAD_SPACES = 4

      # An array of all column names present in this 2da table.
      attr_accessor :columns

      # An array of row arrays, without headers.
      attr_accessor :rows

      # What to use to set up newlines.
      # Alternatively, specify the environ variable NWN_LIB_2DA_NEWLINE
      # with one of the following:
      #  0 for windows newlines: \r\n
      #  1 for unix newlines: \n
      #  2 for caret return only: \r
      # defaults to \r\n.
      attr_accessor :newline

      # Create a new, empty 2da table.
      def initialize
        @columns = []
        @rows = []
        @newline = "\r\n"
      end

      # Creates a new Table object from a given IO source.
      #
      # [+file+] A IO object pointing to a 2da file.
      def self.read_from io
        self.parse io.read()
      end

      # Dump this table to a IO object.
      def write_to io
        io.write(self.to_2da)
      end

      # Parse a existing string containing a full 2da table.
      # Returns a TwoDA::Table.
      def self.parse bytes
        obj = self.new
        obj.parse bytes
        obj
      end

      # Parses a string that represents a valid 2da definition.
      # Replaces any content this table may already have.
      def parse bytes
        magic, *data = *bytes.split(/\r?\n/).map {|v| v.strip }

        raise ArgumentError, "Not valid 2da: No valid header found" if
          magic != "2DA V2.0"

        # strip all empty lines; they are regarded as comments
        data.reject! {|ln| ln.strip == ""}

        header = data.shift

        header = Shellwords.shellwords(header.strip)
        data.map! {|line|
          r = Shellwords.shellwords(line.strip)
          # The last cell can be without double quotes even if it contains whitespace
          r[header.size..-1] = r[header.size..-1].join(" ") if r.size > header.size
          r
        }

        new_row_data = []

        id_offset = 0
        idx_offset = 0
        data.each_with_index {|row, idx|
          id = row.shift.to_i + id_offset

          raise ArgumentError, "Invalid ID in row #{idx}" unless id >= 0

          # Its an empty row - this is actually valid; we'll fill it up and dump it later.
          while id > idx + idx_offset
            new_row_data << Row.new([""] * header.size)
            idx_offset += 1
          end

          # NWN automatically increments duplicate IDs - so do we.
          while id + id_offset < idx
            $stderr.puts "Warning: duplicate ID found at row #{idx} (id: #{id}); fixing that for you."
            id_offset += 1
            id += 1
          end

          # NWN fills in missing columns with an empty value - so do we.
          row << "" while row.size < header.size

          new_row_data << k_row = Row.new(row)
          k_row.table = self

          k_row.map! {|cell|
            cell = case cell
              when nil; nil
              when "****"; ""
              else cell
            end
          }

          raise ArgumentError,
            "Row #{idx} has too many cells for the given header (has #{k_row.size}, want <= #{header.size})" if
              k_row.size != header.size
        }

        @columns = header
        @rows = new_row_data
      end


      # Retrieve data by row.
      #
      # [+row+]    The row to retrieve (starts at 0)
      # [+column+] The column to retrieve (name or id), or nil for all columns.
      def by_row row, column = nil
        column = column_name_to_id column
        column.nil? ? @rows[row.to_i] : (@rows[row.to_i].nil? ? nil : @rows[row.to_i][column])
      end


      # Retrieve data by column.
      #
      # [+column+] The column to retrieve (name or id).
      # [+row+]    The row to retrieve (starts at 0), or nil for all rows.
      def by_col column, row = nil
        column = column_name_to_id column
        raise ArgumentError, "column must not be nil." if column.nil?
        row.nil? ? @rows.map {|v| v[column] } : (@rows[row.to_i].nil? ? nil : @rows[row.to_i][column])
      end


      # Translate a column name to its array offset; will validate
      # and raise an ArgumentError if the given argument is invalid
      # or the column cannot be resolved.
      def column_name_to_id column
         case column
          when String
            @columns.index(column) or raise ArgumentError, "Not a valid column name: #{column}"
          when Fixnum
            column
          when NilClass
            nil
          else
            raise ArgumentError, "Invalid column type: #{column} as #{column.class}"
        end
      end

      # Returns this table as a valid 2da to be written to a file.
      def to_2da
        ret = []

        # Contains the maximum string length by each column,
        # from which we can calulate the padding we need that
        # things align properly.
        id_cell_size = @rows.size.to_s.size + CELL_PAD_SPACES
        max_cell_size_by_column = @columns.map {|col|
          ([col] + by_col(col)).inject(0) {|max, cell|
            cell = '"%s"' % cell if cell =~ /\s/
            cell.to_s.size > max ? cell.to_s.size : max
          } + CELL_PAD_SPACES
        }

        ret << "2DA V2.0"
        ret << ""

        rv = []
        rv << " " * id_cell_size
        @columns.each_with_index {|column, column_idx|
          rv << column + " " * (max_cell_size_by_column[column_idx] - column.size)
        }
        ret << rv.join("").rstrip

        @rows.each_with_index {|row, row_idx|
          rv = []
          rv << row_idx.to_s + " " * (id_cell_size - row_idx.to_s.size)
          row.each_with_index {|cell, column_idx|
            cell = "****" if cell == ""
            cell = '"%s"' % cell if cell =~ /\s/
            rv << cell + " " * (max_cell_size_by_column[column_idx] - cell.size)
          }
          ret << rv.join("").rstrip
        }

        # Append an empty newline.
        ret << ""

        ret.join(case ENV['NWN_LIB_2DA_NEWLINE']
          when "0"
            "\r\n"
          when "1"
            "\n"
          when "2"
            "\r"
          when nil
            @newlines
        end)
      end
    end

    # An alias for TwoDA::Cache.get
    def self.get name
      NWN::TwoDA::Cache.get(name)
    end

    # This is a simple 2da cache.
    module Cache
      @_cache = {}
      @_roots = []

      # Set the file system path spec where all 2da files reside.
      # Call this on application startup.
      # path spec is a colon-separated list of pathes, just like $PATH.
      def self.setup root_directories
        @_roots = root_directories.split(':').compact.reject {|x| "" == x.strip }
      end

      # Get the 2da file with the given name. +name+ is without extension.
      def self.get(name)
        raise Exception,
          "You need to set up the cache first through the environment variable NWN_LIB_2DA_LOCATION." unless
            @_roots.size > 0
        @_cache[name.downcase] ||= read_2da(name.downcase)
      end

      def self.read_2da name # :nodoc:
        @_roots.each {|root|
          file = root + '/' + name + '.2da'
          next unless FileTest.exists?(file)
          return Table.parse(IO.read(file))
        }
        raise Errno::ENOENT, name + ".2da"
      end

      private_class_method :read_2da
    end
  end
end
