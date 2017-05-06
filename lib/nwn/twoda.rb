class Integer
  # Returns the level that this amount experience resolves to.
  # Depends on a set-up TwoDA::Cache, and reads from <tt>exptable</tt>.
  def xp_to_level
    NWN::TwoDA.get('exptable').rows.each {|row|
      level, exp = row.Level.to_i, row.XP.to_i
      return level - 1 if exp > self
    }
    return nil
  end

  # Returns the amount of experience that this level resolves to.
  # Depends on a set-up TwoDA::Cache, and reads from <tt>exptable</tt>.
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
        col = meth.to_s
        assignment = if col =~ /(.+?)=$/
          col = $1
          true
        else
          false
        end

        if idx = @table.column_name_to_id(col)
          if assignment
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
      def columns; @columns; end
      def columns=(c)
        @columns = c
        @columns_lookup = @columns.map(&:downcase)
      end

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
        @columns_lookup = []
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
      # This will cope with all misformatting in the same way
      # that NWN1 itself does. NWN2 employs slightly different
      # parsing rules, and may or may not be compatible in the
      # fringe cases.
      #
      # Will raise an ArgumentError if the given +bytes+ do
      # not contain a valid 2DA header, or the file is so badly
      # misshaped that it will not ever be parsed correctly by NWN1.
      def parse bytes
        magic, *data = *bytes.split(/\r?\n/).map {|v| v.strip }

        raise ArgumentError, "Not valid 2da: No valid header found (got: #{magic[0,20].inspect}..)" if
          magic !~ /^2DA\s+V2.0$/

        # strip all empty lines; they are regarded as comments
        data.reject! {|ln| ln.strip == ""}

        header = data.shift

        header = colsplit(header.strip)
        data.map! {|line|
          colsplit(line.strip)
        }

        new_row_data = []

        id_offset = 0
        idx_offset = 0
        data.each_with_index {|row, idx|
          id = row.shift

          NWN.log_debug "Warning: invalid ID in line #{idx}: #{id.inspect}" if id !~ /^\d+$/

          id = id.to_i + id_offset

          # Its an empty row - NWN strictly numbers by counted lines - then so do we.
          while id > idx + idx_offset
            NWN.log_debug "Warning: missing ID at #{id - id_offset}, fixing that for you."
            idx_offset += 1
          end

          # NWN automatically increments duplicate IDs - so do we.
          while id < idx + idx_offset
            NWN.log_debug "Warning: duplicate ID found at row #{idx} (id: #{id}); fixing that for you."
            id_offset += 1
            id += 1
          end

          # NWN fills in missing columns with an empty value - so do we.
          NWN.log_debug "Warning: row #{id} (real: #{id - id_offset}) misses " +
            "#{header.size - row.size} columns at the end, fixed" if
              row.size < header.size

          row << "" while row.size < header.size

          new_row_data << k_row = Row.new(row)
          k_row.table = self

          k_row.map! {|cell|
            cell = case cell
              when nil; raise "Bug in parser: nil-value for cell"
              when "****"; ""
              else cell
            end
          }

          NWN.log_debug "Warning: row #{idx} has too many cells (has #{k_row.size}, want <= #{header.size})" if
            k_row.size > header.size

          k_row.pop while k_row.size > header.size
        }

        self.columns = header
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
      alias_method :[], :by_row


      # Set a cell or row value.
      #
      # [+row+]     The row to operate on (starts at 0)
      # [+column+]  Optional column name or index.
      # [+value+]   New value, either a full row, or a single value.
      #
      # Examples:
      #  TwoDA.get('portraits')[1, "BaseResRef"] = "hi"
      #  TwoDA.get('portraits')[1] = %w{1 2 3 4 5 6}
      def []= row, column = nil, value = nil
        if value.nil?
          value = column
          raise ArgumentError, "Expected array for setting a whole row" unless value.is_a?(Array)
        end

        if value.is_a?(Array)
          raise ArgumentError, "Given array size does not match table columns (got: #{value.size}, want: #{self.columns.size})" unless value.size == self.columns.size
          new_row = Row.new
          new_row.concat(value.map {|x| x.to_s})

          @rows[row] = new_row

        else
          col = column_name_to_id column
          @rows[row][col] = value

        end
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
          when String, Symbol
            @columns_lookup.index(column.to_s.downcase) or raise ArgumentError,
              "Not a valid column name: #{column}"
          when Integer
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
            cell = cell ? 1 : 0 if cell.is_a?(TrueClass) || cell.is_a?(FalseClass)
            cell = "****" if cell == ""
            cell = '"%s"' % cell if cell =~ /\s/
            cell = cell.to_s
            rv << cell + " " * (max_cell_size_by_column[column_idx] - cell.size)
          }
          ret << rv.join("").rstrip
        }

        # Append an empty newline.
        ret << ""

        ret.join(case NWN.setting("2da_newline")
          when "0", false
            "\r\n"
          when "1"
            "\n"
          when "2"
            "\r"
          when nil
            @newline
        end)
      end

    private

      def colsplit(line)
        line = String.new(line) rescue
          raise(ArgumentError, "Argument must be a string")
        line.lstrip!
        words = []
        until line.empty?
          field = ''
          loop do
        if line.sub!(/\A"(([^"\\]|\\.)*)"/, '') then
          snippet = $1.gsub(/\\(.)/, '\1')
        elsif line =~ /\A"/ then
          raise ArgumentError, "Unmatched double quote: #{line}"
        elsif line.sub!(/\A\\(.)?/, '') then
          snippet = $1 || '\\'
        elsif line.sub!(/\A([^\s\\"]+)/, '') then
          snippet = $1
        else
          line.lstrip!
          break
        end
        field.concat(snippet)
          end
          words.push(field)
        end
        words
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
      # path spec is a colon-separated list of paths, just like $PATH.
      def self.setup root_directories
        @_roots = root_directories.split(File::PATH_SEPARATOR).
          compact.reject {|x| "" == x.strip }
      end

      # Get the 2da file with the given name. +name+ is without extension.
      # This being a cache, modifications to the returned Table will be reflected
      # in further calls to Cache.get.
      def self.get(name)
        raise Exception,
          "You need to set up the cache first through the environment variable NWN_LIB_2DA_LOCATION." unless
            @_roots.size > 0
        @_cache[name.downcase] ||= read_2da(name.downcase)
      end

      def self.read_2da name # :nodoc:
        @_roots.each {|root|
          file = root + File::SEPARATOR + name + '.2da'
          next unless FileTest.exists?(file)
          return Table.parse(IO.read(file))
        }
        raise Errno::ENOENT, name + ".2da"
      end

      private_class_method :read_2da
    end
  end
end
