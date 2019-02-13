class RethinkORM::Error < Exception
  getter message

  def initialize(@message : String? = "")
    super(message)
  end

  class DocumentExists < Error
  end

  class DocumentNotFound < Error
  end

  class DocumentInvalid < Error
  end

  class DocumentNotSaved < Error
  end

  class DatabaseError < Error
  end
end
