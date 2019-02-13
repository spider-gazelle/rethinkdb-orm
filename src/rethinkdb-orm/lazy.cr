class RethinkORM::Lazy(M)
  forward_missing_to value

  def initialize(@loader : -> M)
    @loaded = false
  end

  private def loaded?
    @loaded
  end

  private getter loader

  private def value
    return @value if loaded?

    @value = loader.call
    @loaded = true
    @value
  end
end
