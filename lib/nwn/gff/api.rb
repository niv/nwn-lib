
module NWN::Gff::Field
#:stopdoc:
  # Used by NWN::Gff::Struct#by_flat_path
  def each_by_flat_path &block
    case field_type
      when :cexolocstr
        yield("", self)
        field_value.sort.each {|lid, str|
          yield("/" + lid.to_s, str)
        }

      when :struct
        yield("", self)
        field_value.each_by_flat_path {|v, x|
          yield(v, x)
        }

      when :list
        yield("", self)
        field_value.each_with_index {|item, index|
          yield("[" + index.to_s + "]", item)
          item.each_by_flat_path("/") {|v, x|
            yield("[" + index.to_s + "]" + v, x)
          }
        }

      else
        yield("", self)
    end
  end
#:startdoc:
end

module NWN::Gff::Struct

  # Iterates this struct, yielding flat, absolute
  # pathes and the Gff::Field for each element found.

  # Example:
  # "/AddCost" => {"type"=>:dword, ..}
  def each_by_flat_path prefix = "/", &block
    sort.each {|label, field|
      field.each_by_flat_path do |ll, lv|
        yield(prefix + label + ll, lv)
      end
    }
  end

  # Retrieve an object from within the given tree.
  # Path is a slash-separated destination, given as
  # a string
  #
  # Prefixed/postfixed slashes are optional.
  #
  # Examples:
  # /
  # /AddCost
  # /PropertiesList/
  # /PropertiesList[0]/CostValue
  def by_path path
    struct = self
    current_path = ""
    path = path.split('/').map {|v| v.strip }.reject {|v| v.empty?}.join('/')

    path.split('/').each {|v|
      if v =~ /^(.+?)\[(\d+)\]$/
        v, index = $1, $2
      end

      struct = struct[v]
      if index
        struct.field_type == :list or raise NWN::Gff::GffPathInvalidError,
          "Specified a list offset for a non-list item: #{v}[#{index}]."

        struct = struct.field_value[index.to_i]
      end

      raise NWN::Gff::GffPathInvalidError,
        "Cannot find a path to /#{path} (at: /#{current_path})." unless struct

      current_path += v
    }

    struct
  end

end
