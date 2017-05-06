# This module contains scripting functions and helpers.
#
# Include this if you want to eval nwn-gff-dsl scripts.
module NWN::Gff::Scripting

  class Sandbox #:nodoc:
    include NWN
    include NWN::Gff::Scripting
  end

  # Run a script in a sandboxish environ.
  # Returns true if the code modified run_on in any way.
  def self.run_script code, run_on = nil, arguments = []
    $code = code
    $argv = arguments
    $standalone = run_on.nil?
    $satisfy_loaded = {}
    run_on ||= Sandbox.new

    $script_obj_hash = run_on.hash
    catch(:exit) {
      begin
        run_on.instance_eval $code
      rescue
        raise
      end
    }
    $script_obj_hash != run_on.hash
  end

  # Save the given object if it was loaded via want/need
  def save object
    fn, hash = $satisfy_loaded[object.object_id]
    if fn
      if hash != object.hash
        File.open(fn, "wb") {|f|
          NWN::Gff.write(f, NWN::Gff.guess_file_format(fn), object)
        }
        log "saved #{object.to_s} -> #{fn}"
      else
        log "not saving #{fn}: not modified"
      end
    else
      raise ArgumentError,
        "#save: object #{object.to_s} was not loaded via want/need/satisfy, cannot save"
    end
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
      log "#{$SCRIPT}: not emitting any data."
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
  #
  # If only a filename/string is given and no further arguments,
  # the read object will be returned as-is.
  def satisfy *what
    close_me = false
    if $standalone
      fn = what.shift
      io = case fn
        when String
          close_me = true
          File.new(fn, "rb")
        when IO
          fn
        else
          return nil
          #raise ArgumentError, "When running in standalone mode, " +
          #  "`need', `want' and `satisfy' need a filename or a IO " +
          #  "object to read from (usually the first script argument)."
      end

      obj = begin
        NWN::Gff.read(io, NWN::Gff.guess_file_format(fn))
      ensure
        io.close if close_me
      end
      log "satisfied #{fn} -> #{obj.to_s}"
      $satisfy_loaded[obj.object_id] = [fn, obj.hash]

      return obj if what.size == 1
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

  # You can call this to provide a progress indicator, if your script is long-running.
  # the calculated percentage will be prefixed before each log message.
  #
  # +position+   The number of items in the work queue finished.
  # +total_size+ The total size of the work queue, defaults to ARGV.size.
  def progress position, total_size = nil
    total_size ||= ARGV.size
    $PERCENTAGE_DONE = position.to_f / total_size.to_f * 100
  end

  # Log a friendly message to stderr.
  # Use this instead of puts, since SAFE levels greater than 0
  # will prevent you from doing logging yourself.
  def log *args
    perc = $PERCENTAGE_DONE.nil? ? "" : " (%d%%)" % [ $PERCENTAGE_DONE.to_i ]
    if $options
      $stderr.puts [$SCRIPT, perc, " on ", $options[:infile], ": ", *args].join("")
    else
      $stderr.puts [$SCRIPT, perc, ": ", *args].join("")
    end
  end


  # Ask the user for something.
  # +question+  the Question to ask
  # +match+     a selection of answers to choose from (eg, a hash, the user would choose the key)
  def ask question, match = nil
    object = case match
      when Array
        i = 0 ; Hash[match.map {|x| [i+=1, x]}]

      when Hash, Regexp, Integer, Float
        match

      else
        raise NWN::Gff::GffError, "Do not know how to " +
          "validate against #{match.class}"
    end

    ret = nil
    while true
      y object
      $stderr.print File.basename($SCRIPT) + ": " + question + " "
      ret = $stdin.gets
      ret = ret.rstrip

      break if object.nil? || case object
        when Hash
          if object.keys.index(ret) || (ret != "" && object.keys.index(ret.to_i))
            ret = object[ret] || (ret != "" && object[ret.to_i])
          else
            nil
          end
        when Regexp
          ret =~ match
        when Integer
          ret =~ /^\d+$/
        when Float
          ret =~ /^\d+(.\d+)?$/
      end
    end

    case match
      when Float; ret.to_f
      when Integer; ret.to_i
      else; ret
    end
  end

end
