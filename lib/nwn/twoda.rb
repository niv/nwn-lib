require 'shellwords'

module NWN
  module TwoDA
    class Table

      # An array of all column names present in this 2da table.
      attr_accessor :columns

      # An array of row arrays, without headers.
      attr_accessor :rows

      # Create a new, empty 2da table.
      def initialize
        @columns = []
        @rows = []
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
        magic, empty, header, *data = *bytes.split(/\r?\n/).map {|v| v.strip }

        raise ArgumentError, "Not valid 2da: No valid header found" if
          magic != "2DA V2.0"


        if empty != ""
          $stderr.puts "Warning: second line of 2da not empty, continuing anyways."
          data = [header].concat(data)
          header = empty
        end

        header = Shellwords.shellwords(header.strip)
        data.map! {|line|
          Shellwords.shellwords(line.strip)
        }

        data.reject! {|line|
          line.size == 0
        }

        offset = 0
        data.each_with_index {|row, idx|
          if (idx + offset) != row[0].to_i
            $stderr.puts "Warning: row #{idx} has a non-matching ID #{row[0]} (while parsing #{row[0,3].join(' ')})."
            offset += (row[0].to_i - idx)
          end

          # [1..-1]: Strip off the ID
          data[row[0].to_i] = row = row[1..-1]

          raise ArgumentError,
            "Row #{idx} does not have the appropriate amount of cells (has: #{row.size}, want: #{header.size}) (while parsing #{row[0,3].join(' ')})." if
              row.size != header.size
        }

        @columns = header
        @rows = data
      end


      # Retrieve data by row.
      #
      # [+row+]    The row to retrieve (starts at 0)
      # [+column+] The column to retrieve (name or id), or nil for all columns.
      def by_row row, column = nil
        column = column_name_to_id column
        column.nil? ? @rows[row.to_i] : @rows[row.to_i][column]
      end


      # Retrieve data by column.
      #
      # [+column+] The column to retrieve (name or id).
      # [+row+]    The row to retrieve (starts at 0), or nil for all rows.
      def by_col column, row = nil
        column = column_name_to_id column
        raise ArgumentError, "column must not be nil." if column.nil?
        row.nil? ? @rows.map {|v| v[column] } : @rows[row.to_i][column]
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
        ret << "2DA V2.0"
        ret << ""
        ret << "    " + @columns.join("    ")
        @rows.each_with_index {|row, idx|
          ret << [idx].concat(row).join("    ")
        }
        ret.join("\r\n")
      end

    end
  end
end
