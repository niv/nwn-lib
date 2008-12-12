# This module contains scripting functions and helpers.
#
# Include this if you want to eval nwn-gff-dsl scripts.
module NWN::Gff::Scripting

  # This script only runs for the following conditions (see #satisfy).
  def want *what
    unless satisfy(*what)
      log "Wants #{what.inspect}, cannot satisfy - continuing."
      throw(:exit)
    end
  end

  # Same as want, but error out (don't continue processing).
  def need *what
    fail("Needs #{what.inspect}, cannot satisfy.") unless satisfy(*what)
  end

  # This checks if the currently-operating field or struct
  # satisfies one of the given conditions.
  #
  # Conditions can be:
  # * A symbol describing the data_type, eg :utc
  # * A symbol describing the field_type, eg :int
  # * A module or class name
  def satisfy *what
    what.each {|w|
      case w
        when Class, Module
          return true if self.is_a?(w)

        when Symbol
          case self
            when NWN::Gff::Struct
              return true if self.data_type.downcase == w.to_s.downcase
            when NWN::Gff::Field
              return true if self.field_type.to_sdowncase == w.to_s.downcase
          end
      end

    }

    return false
  end

  # Log a friendly message to stderr.
  # Use this instead of puts, since SAFE levels greater than 0
  # will prevent you from doing logging yourself.
  def log *args
    if $SAFE > 0
      Thread.current[:stderr] << [$script, caller, *args]
    else
      $stderr.puts [$script, ": ", *args].join("")
    end
  end
end
