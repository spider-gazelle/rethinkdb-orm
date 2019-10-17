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
    getter model

    def initialize(@model : RethinkORM::Base, message)
      super(message)
    end

    def inspect_errors
      @model.errors.map do |e|
        {
          field:   e.field,
          message: e.message,
        }
      end
    end
  end

  class DocumentNotSaved < Error
  end

  class DatabaseError < Error
  end
end
