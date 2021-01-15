class RethinkORM::Error < Exception
  getter message

  def initialize(@message : String? = "")
    super(message)
  end

  class ChangefeedClosed < Error
  end

  class DocumentExists < Error
  end

  class DocumentNotFound < Error
  end

  class DocumentInvalid < Error
    getter model : RethinkORM::Base
    getter errors : Array(NamedTuple(field: Symbol, message: String))

    def initialize(@model, message = "Document has invalid fields")
      @errors = @model.errors.map do |e|
        {
          field:   e.field,
          message: e.message,
        }
      end

      super(message)
    end

    def to_s(io : IO)
      remaining = errors.size
      errors.each do |error|
        remaining -= 1
        io << error[:field].to_s
        io << " " << error[:message]
        io << ", " unless remaining.zero?
      end
    end

    @[Deprecated("Use `errors` instead")]
    def inspect_errors
      errors
    end
  end

  class DocumentNotSaved < Error
  end

  class DatabaseError < Error
  end

  class ConnectError < Error
  end

  class LockInvalidOp < Error
    def initialize(key : String, locked : Bool)
      super("Lock (#{key}) #{locked ? "already" : "not"} locked")
    end
  end

  class LockLost < Error
    def initialize(key : String)
      super("Lock (#{key}) lost ")
    end
  end

  class LockUnavailable < Error
    def initialize(key : String)
      super("Lock (#{key}) unavailable")
    end
  end
end
