# This is a loose adaption of readbytes.rb, but with more flexibility and
# StringIO support.

# MissingDataError is raised when IO#readbytes fails to read enough data.
class MissingDataError < IOError
  def initialize(mesg, data) # :nodoc:
    @data = data
    super(mesg)
  end

  # The read portion of an IO#e_read attempt.
  attr_reader :data
end


[IO, StringIO].each {|klass|
  klass.class_eval do
    # Reads exactly +n+ bytes.
    #
    # If the data read is nil an EOFError is raised.
    #
    # If the data read is too short a MissingDataError is raised and the read
    # data is obtainable via its #data method.
    def e_read(n, mesg = nil)
      str = read(n)
      if str == nil
        raise EOFError, "End of file reached"
      end
      if str.size < n
        raise MissingDataError.new("data truncated" + (mesg ? ": " + mesg : nil), str)
      end
      str
    end
  end
}
