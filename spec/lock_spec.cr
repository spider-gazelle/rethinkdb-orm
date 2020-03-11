require "uuid"
require "./spec_helper"

module RethinkORM
  describe Lock do
    Spec.before_each do
      Lock.clear
    end

    it "locks with try_lock" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock2 = Lock.new(id)

      lock1.try_lock.should be_true
      lock2.try_lock.should be_false
      lock1.unlock
      lock2.try_lock.should be_true
    end

    it "locks with synchronize and a block" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock2 = Lock.new(id)

      lock1.synchronize do
        lock2.try_lock.should be_false
      end
      lock2.try_lock.should be_true
    end

    it "lock/refresh/unlock methods return nil" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)

      lock1.lock.should be_nil
      lock1.refresh.should be_nil
      lock1.unlock.should be_nil
    end

    it "prevents locking twice" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)

      lock1.lock
      expect_raises(Error::LockInvalidOp, /already locked/) { lock1.lock }
    end

    it "prevents unlocking an unlocked lock" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      expect_raises(Error::LockInvalidOp, /not locked/) { lock1.unlock }
    end

    it "prevents refreshing when not locked" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      expect_raises(Error::LockInvalidOp, /not locked/) { lock1.refresh }
    end

    it "times out if it cannot get the lock" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock2 = Lock.new(id)
      lock1.lock(expire: 10.seconds)
      expect_raises(Error::LockUnavailable) { lock2.lock(timeout: 0.5.seconds) }
    end

    it "does not timeout if it can get the lock" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock1.lock(timeout: 0.1.seconds)
      lock1.unlock
      lock1.lock(timeout: 0.seconds)
      lock1.unlock
    end

    it "steals the lock if necessary" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock2 = Lock.new(id)
      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      expect_raises(Error::LockLost) { lock1.unlock }
      lock2.unlock
      Lock.count.should eq 0
    end

    it "steals the lock if necessary 2" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      lock2 = Lock.new(id)
      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      lock2.unlock
      expect_raises(Error::LockLost) { lock1.unlock }
      Lock.count.should eq 0
    end

    it "refreshes locks" do
      id = UUID.random.to_s
      lock1 = Lock.new(key: id, instance_token: "hello")
      lock2 = Lock.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock1.refresh(expire: 60.seconds)
      expect_raises(Error::LockUnavailable) { lock2.lock(timeout: 1.seconds) }
    end

    it "does not allow refresh to happen on a lost lock" do
      id = UUID.random.to_s
      lock1 = Lock.new(key: id)
      lock2 = Lock.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "does not allow refresh to happen on a lost lock 2" do
      id = UUID.random.to_s
      lock1 = Lock.new(key: id)
      lock2 = Lock.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      lock2.unlock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "allows recovering expired locks" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)

      lock1.lock(expire: 0.1.seconds)
      sleep 0.1
      expired_lock = Lock.expired.first
      expired_lock.lock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "prevents save/update/delete/destroy" do
      id = UUID.random.to_s
      lock1 = Lock.new(id)
      expect_raises(NotImplementedError) { lock1.save }
      expect_raises(NotImplementedError) { lock1.update }
      expect_raises(NotImplementedError) { lock1.delete }
      expect_raises(NotImplementedError) { lock1.destroy }
    end

    describe "when specifying default expire value" do
      it "uses the expires default value" do
        id = UUID.random.to_s
        lock1 = Lock.new(id, expire: 0.1.seconds)
        lock1.lock
        lock2 = Lock.new(id)
        lock2.lock
        expect_raises(Error::LockLost) { lock1.unlock }
      end
    end

    describe "when specifying default timeout value" do
      it "uses the expires default value" do
        id = UUID.random.to_s
        lock1 = Lock.new(id)

        lock1.lock
        lock2 = Lock.new(id, timeout: 0.seconds)
        expect_raises(Error::LockUnavailable) { lock2.lock }
      end
    end

    describe "when looking for a lock" do
      it "finds it by key" do
        id = UUID.random.to_s
        lock1 = Lock.new(id)
        lock1.lock

        found = Lock.find!(id)
        found.id.should eq lock1.id
        found.key.should eq lock1.key
        found.instance_token.should_not eq lock1.instance_token
      end
    end
  end

  describe Lock::Reentrant do
    it "locks with try_lock" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id, instance_token: "bye")
      lock1a = lock1
      lock1b = Lock::Reentrant.new(key: id, instance_token: "hello")

      lock1a.try_lock.should be_true
      lock1b.try_lock.should be_true

      lock2.try_lock.should be_false
      lock1a.try_lock.should be_true

      lock1a.unlock
      lock1a.unlock

      lock2.try_lock.should be_false

      lock1b.unlock

      lock2.try_lock.should be_true
      lock2.unlock

      Lock::Reentrant.count.should eq 0
    end

    it "locks with synchronize and a block" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.synchronize do
        lock2.try_lock.should be_false
      end
      lock2.try_lock.should be_true
    end

    it "lock/refresh/unlock methods return nil" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")

      lock1.lock.should be_nil
      lock1.refresh.should be_nil
      lock1.unlock.should be_nil
    end

    it "times out if it cannot get the lock" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 10.seconds)
      expect_raises(Error::LockUnavailable) { lock2.lock(timeout: 0.5.seconds) }
    end

    it "steals the lock if necessary" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      expect_raises(Error::LockLost) { lock1.unlock }
      lock2.unlock
      Lock::Reentrant.count.should eq 0
    end

    it "steals the lock if necessary 2" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      lock2.unlock
      expect_raises(Error::LockLost) { lock1.unlock }
      Lock::Reentrant.count.should eq 0
    end

    it "refreshes locks" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock1.refresh(expire: 60.seconds)
      expect_raises(Error::LockUnavailable) { lock2.lock(timeout: 1.seconds) }
    end

    it "does not allow refresh to happen on a lost lock" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "does not allow refresh to happen on a lost lock 2" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")
      lock2 = Lock::Reentrant.new(key: id)

      lock1.lock(expire: 0.2.seconds)
      lock2.lock
      lock2.unlock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "allows recovering expired locks" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")

      lock1.lock(expire: 0.1.seconds)
      sleep 0.1
      expired_lock = Lock::Reentrant.expired.first
      expired_lock.lock
      expect_raises(Error::LockLost) { lock1.refresh }
    end

    it "prevents save/update/delete/destroy" do
      id = UUID.random.to_s
      lock1 = Lock::Reentrant.new(key: id, instance_token: "hello")

      expect_raises(NotImplementedError) { lock1.save }
      expect_raises(NotImplementedError) { lock1.update }
      expect_raises(NotImplementedError) { lock1.delete }
      expect_raises(NotImplementedError) { lock1.destroy }
    end
  end
end
