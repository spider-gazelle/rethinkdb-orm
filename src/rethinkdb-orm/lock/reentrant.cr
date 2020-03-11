require "../lock"

module RethinkORM
  class Lock::Reentrant < Lock
    table "locks"

    attribute lock_count : Int32

    def initialize(
      key : String,
      expire : Time::Span? = nil,
      timeout : Time::Span? = nil,
      instance_token : String = Lock.new_instance_token
    )
      @key = key
      @id = Digest::SHA1.base64digest(key)
      @instance_token = instance_token
      @expire = expire if expire
      @timeout = timeout if timeout
    end

    def try_lock(expire : Time::Span = self.expire)
      set_expiration(expire)

      result = Lock::Reentrant.table_query do |q|
        q.get(self.id.as(String)).replace do |doc|
          r.branch(
            # Instance token matches?
            doc[:instance_token].default(nil).eq(self.instance_token),
            # Update the expiry, and the lock_count
            doc.merge({
              expires_at: expiry_epoch,
              lock_count: doc[:lock_count] + 1,
            }),
            # Otherwise..
            r.branch(
              # If lock is expired?
              doc.eq(nil).or(r.epoch_time(doc[:expires_at]) < r.now),
              # Replace lock with own lock
              lock_attributes.merge({:lock_count => 1}),
              # Leave the lock
              doc
            )
          )
        end
      end

      @locked = true # HACK: satisfy `refresh` and` synchronize`

      inserted = result["inserted"]?.try &.raw.as(Int64)
      replaced = result["replaced"]?.try &.raw.as(Int64)

      if inserted && replaced
        inserted + replaced == 1
      else
        false
      end
    end

    def unlock
      set_expiration(use_previous: true)

      result = Lock::Reentrant.table_query do |q|
        q.get(self.id.as(String)).replace do |doc|
          r.branch(
            # If token matches?
            doc[:instance_token].default(nil).eq(self.instance_token),
            # Then
            r.branch(
              # If lock count > 1
              doc[:lock_count] > 1,
              # Decrement lock
              doc.merge({
                :expires_at => expiry_epoch,
                :lock_count => doc[:lock_count] - 1,
              }),
              # Otherwise, delete lock
              nil
            ),
            # Otherwise, leave lock
            doc
          )
        end
      end

      deleted = result["deleted"]?.try &.raw.as(Int64)
      replaced = result["replaced"]?.try &.raw.as(Int64)

      @locked = if deleted && replaced
                  !(replaced + deleted == 1)
                else
                  true
                end

      raise Error::LockLost.new(self.key.as(String)) if @locked
    end
  end
end
