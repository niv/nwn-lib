# A GFF object encapsulates a whole GFF identity, with a type,
# version, and a root structure.
# This object also provides easy accessors for labels and values.
class NWN::Gff::Gff
  include NWN::Gff

  attr_accessor :type
  attr_accessor :version

  # Create a new GFF object from the given +struct+.
  # This is normally not needed unless you are creating
  # GFF objects entirely from hand.
  #
  # See NWN::Gff::Reader.
  def initialize struct, type, version = "V3.2"
    @hash = struct
    @type = type.strip
    @version = version
  end

  # Return the root struct of this GFF.
  def root_struct
    @hash
  end

  # A simple accessor that can be used to
  # retrieve or set properties in the struct, delimited by slashes.
  #
  # Will raise a GffPathInvalidError if the given path cannot be found,
  # and GffTypeError if some type fails to validate.
  #
  # Examples (with +gff+ assumed to be a item):
  #  gff['/Tag']
  #    will retrieve the Tag of the given object
  #  gff['/Tag'] = 'Test'
  #    Set the Tag to 'Test'
  #  gff['/PropertiesList']
  #    will retrieve an array of Gff::Elements
  #  gff['/PropertiesList[1]']
  #    will yield element 2 in the list
  #  gff['/'] = NWN::Gff::Element.new('Property', :byte, 14)
  #    will add a new property at the root struct with the name of 'Property', or
  #    overwrite an existing one with the same label.
  #  gff['/PropertiesList[0]'] = 'Test'
  #    This will raise an error (obviously)
  def get_or_set k, new_value = nil, new_type = nil, new_label = nil, newstr_ref = nil
    h = self.root_struct
    path = []
    value_path = [h]
    current_value = nil

    k.split('/').each {|v|
      next if v == ""
      path << v

      if current_value.is_a?(Gff::Element) && current_value.type == :list # && v =~ /\[(\d+)\]$/
        current_value = current_value.value[$1.to_i]
      end

      if h.is_a?(Gff::Element)
        case h.type
          when :cexolocstr
            current_value = h.value.languages[v.to_i] || ''

          when :list
            raise GffPathInvalidError, "List-selector access not implemented yet."

          else
            raise GffPathInvalidError,
              "Tried to access sub-label of a non-complex field: /#{path.join('/')}"

          end
      elsif h.is_a?(Gff::Struct)

        if v =~ /^(.+?)\[(\d+)\]$/
          current_value = h[$1.to_s]
          if current_value.is_a?(Gff::Element) && !current_value.type == :list
            raise GffPathInvalidError, "Tried to access list-index of a non-list at /#{path.join('/')}"
          end
          current_value = current_value.value[$2.to_i]
        else
          current_value = h[v]
        end
      else
        raise GffPathInvalidError, "Unknown sub-field type #{h.class.to_s} at /#{path.join('/')}"
      end

      value_path << current_value
      h = current_value

      raise GffPathInvalidError,
        "Cannot find path: /#{path.join('/')}" if current_value.nil? && !new_value.is_a?(Gff::Element)
    }

    if path.size == 0
      if new_value.is_a?(Gff::Element)
        value_path << h
      else
        raise GffPathInvalidError, "Do not operate on the root struct unless through adding items."
      end
    end

    old_value = current_value.nil? ? nil : current_value.dup

    if new_value.is_a?(Gff::Element)
      new_value.validate
      value_path[-2].delete(current_value)
      value_path[-2][new_value.label] = new_value
    else

      if !new_label.nil?
        # Set a new label
        value_path[-2].delete(current_value.label)
        current_value.label = new_label
        value_path[-2][new_label] = current_value
      end

      if !new_type.nil?
        # Set a new datatype
        raise GffTypeError, "Cannot set a type on a non-element." unless current_value.is_a?(Gff::Element)
        test = current_value.dup
        test.type = new_type
        test.validate

        current_value.type = new_type

      end

      if !newstr_ref.nil?
        # Set a new str_ref
        raise GffTypeError, "specified path is not a CExoStr" unless current_value.is_a?(Gff::CExoString)
        current_value.str_ref = new_str_ref.to_i
      end

      if !new_value.nil?

        case current_value
          when Gff::Element
            test = current_value.dup
            test.value = new_value
            test.validate
            current_value.value = new_value

          when String #means: cexolocstr assignment
            if value_path[-2].is_a?(Gff::Element) && value_path[-2].type == :cexolocstr
              value_path[-2].value[path[-1].to_i] = new_value
            else
              raise GffPathInvalidError, "Dont know how to set #{new_value.class} on #{path.inspect}."
            end
          else
            raise GffPathInvalidError, "Don't know what to do with #{current_value.class} -> #{new_value.class} at /#{path.join('/')}"
        end

      end
    end

    old_value
  end

  # A alias for get_or_set(key).
  def [] k
    get_or_set k
  end

  # A alias for get_or_set(key, value).
  def []= k, v
    get_or_set k, v
  end

end
