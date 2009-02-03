# This module contains scripting functions and helpers.
#
# Include this if you want to eval nwn-gff-dsl scripts.
module NWN::Gff::Scripting

  class Sandbox
    include NWN
    include NWN::Gff::Scripting
  end

  # Run a script in a sandboxish environ.
  # Returns true if the code modified run_on in any way.
  def self.run_script code, run_on = nil, arguments = []
    $code = code
    $argv = arguments
    $standalone = run_on.nil?
    run_on ||= Sandbox.new

    $script_obj_hash = run_on.hash
    catch(:exit) {
      begin
        run_on.instance_eval $code
      rescue => e
        raise
      end
    }
    $script_obj_hash != run_on.hash
  end

  # This script only runs for the following conditions (see #satisfy).
  def want *what
    obj = satisfy(*what)
    unless obj
      log "Wants #{what.inspect}, cannot satisfy - continuing."
      throw(:exit)
    end
    obj
  end

  # Same as want, but error out (don't continue processing).
  def need *what
    satisfy(*what) or raise ArgumentError, "Needs #{what.inspect}, cannot satisfy - aborting."
  end

  # Call this to prevent nwn-gff from emitting output.
  def stop_output
    if $standalone
      log "warn: no need to stop_output on standalone scripts"
    else
      log "#{$base_script}: not emitting any data."
    end
    $stop_output = true
  end
  
  def will_output?
    !$stop_output
  end

  # This checks if the currently-operating field or struct
  # satisfies one of the given conditions.
  #
  # When you're running in standalone mode, the first argument
  # is expected to be a file or IO stream that needs to satisfy
  # the given conditions.
  #
  # Example:
  #  need ARGV.shift, :bic, :utc, :uti
  # will require the user to supply a filename as the first argument
  # to the standalone script, which needs to resolve to a bic, utc, or
  # uti data_type.
  #
  # Conditions can be:
  # * A symbol describing the data_type, eg :utc
  # * A symbol describing the field_type, eg :int
  # * A module or class name
  #
  # Returns the object that satisfies the asked-for conditions,
  # or nil if none can be given.
  def satisfy *what
    if $standalone
      fn = what.shift
      io = case fn
        when String
          IO.read(fn)
        when IO
          fn
        else
          return nil
          #raise ArgumentError, "When running in standalone mode, " +
          #  "`need', `want' and `satisfy' need a filename or a IO " +
          #  "object to read from (usually the first script argument)."
      end
      obj = NWN::Gff.read(io, NWN::Gff.guess_file_format(fn))
    else
      obj = self
    end

    what.each {|w|
      case w
        when Class, Module
          return obj if obj.is_a?(w)

        when Symbol
          case obj
            when NWN::Gff::Struct
              return obj if obj.data_type.downcase == w.to_s.downcase
            when NWN::Gff::Field
              return obj if obj.field_type.to_sdowncase == w.to_s.downcase
          end
      end

    }

    return nil
  end


  # Log a friendly message to stderr.
  # Use this instead of puts, since SAFE levels greater than 0
  # will prevent you from doing logging yourself.
  def log *args
    if $options
      $stderr.puts [$base_script, " on ", $options[:infile], ": ", *args].join("")
    else
      $stderr.puts [$base_script, ": ", *args].join("")
    end
  end

end
