class RethinkORM::Error < Exception
  getter message

  def initialize(@message : String? = "")
    super(message)
  end

  class DocumentExists < Error
  end

  class DocumentInvalid < Error
  end

  class DocumentNotSaved < Error
  end
end
