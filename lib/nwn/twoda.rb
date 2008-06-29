require 'shellwords'

module NWN
  module TwoDA
    class Table

      # An array of all column names present in this 2da table.
      attr_reader :columns

      # An array of row arrays, without headers.
      attr_reader :rows


      # Creates a new Table object from a given file.
      #
      # [+file+] A readable, valid .2da file.
      def self.new_from_file file
        self.new IO.read(file)
      end


      # Parses a string that represents a valid 2da definition.
      def initialize bytes
        magic, empty, header, *data = *bytes.split(/\r?\n/).map {|v| v.strip }

        raise ArgumentError, "Not valid 2da: No valid header found" if
          magic != "2DA V2.0"

        raise ArgumentError,
          "Not avalid 2da: Second line should be empty."  unless
            empty == ""

        header = Shellwords.shellwords(header.strip)
        data.map! {|line|
          Shellwords.shellwords(line.strip)
        }

        data.each_with_index {|row, idx|
          raise ArgumentError, "2da non-continoous: row #{idx} has a non-matching ID #{row[0]}." if idx != row[0].to_i
          # [1..-1]: Strip off the ID
          data[idx] = row = row[1..-1]

          raise ArgumentError,
            "Row #{idx} does not have the appropriate amount of cells (has: #{row.size}, want: #{header.size})." if
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

    end
  end
end
