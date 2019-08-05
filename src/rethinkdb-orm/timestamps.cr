require "time"

# Creates created_at and updated_at attributes.
# - `updated_at` is set through the `before_update` callback
# - `created_at` is set through the `before_update` callback
#
module RethinkORM::Timestamps
  macro included
    attribute created_at : Time = ->{ Time.utc }, converter: Time::EpochConverter
    attribute updated_at : Time = ->{ Time.utc }, converter: Time::EpochConverter

    before_create do
      self.created_at = self.updated_at = Time.utc
    end

    before_update do
      self.updated_at = Time.utc
    end
  end
end
