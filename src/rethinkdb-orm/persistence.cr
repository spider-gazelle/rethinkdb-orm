require "crystal-rethinkdb"

require "./connection"
require "./utils/id_generator"

module RethinkORM::Persistence
  # Flag to allow lazy querying of table status
  @@table_created = false

  # Id generated on save or set on load
  def new_record?
    if destroyed?
      false
    else
      @id.nil?
    end
  end

  def persisted?
    !(new_record? || destroyed?)
  end

  getter? destroyed = false

  macro included

    # Set the uuid generator for models
    @@uuid_generator = IdGenerator

    # Allow user defined uuid generator
    def uuid_generator=(generator : Class)
      @@uuid_generator = generator
    end

    # Creates the model
    #
    # Raises a RethinkORM::Error::DocumentNotSaved if failed to created
    def self.create!(**attributes)
      document = new(**attributes)
      raise RethinkORM::Error::DocumentNotSaved.new("Failed to create document!") unless document.save
      document
    end

    # Creates the model
    #
    def self.create(**attributes)
      document = new(**attributes)
      document.save
      document
    end

    # Removes all records from the table
    #
    def self.clear
      Connection.raw do |q|
        q.table(@@table_name).delete
      end
    end
  end

  # Saves the model.
  #
  # If the model is new, a record gets created in the database, otherwise
  # the existing record gets updated.
  def save(**options)
    raise RethinkORM::Error::DocumentNotSaved.new("Cannot save a destroyed document!") if destroyed?
    return false unless valid?

    new_record? ? __create(**options) : __update(**options)
  end

  # Saves the model.
  #
  # If the model is new, a record gets created in the database, otherwise
  # the existing record gets updated.
  # Raises RethinkORM::Error:DocumentInvalid on validation failure
  def save!(**options)
    raise RethinkORM::Error::DocumentInvalid.new(self, "Failed to save the document") unless self.save(**options)
    self
  end

  # Updates the model
  #
  # Non-atomic updates are required for multidocument updates
  def update(**attributes)
    assign_attributes(**attributes)
    save
  end

  # Updates the model in place
  #
  # Throws RethinkORM::Error::DocumentInvalid on update failure
  def update!(**attributes)
    updated = self.update(**attributes)
    raise RethinkORM::Error::DocumentInvalid.new(self, "Failed to update the document") unless updated
    self
  end

  # Highly inefficient serialization of model subset.
  # FIXME: optimise
  protected def subset_json(fields : Enumerable(String) | Enumerable(Symbol))
    string_keys = fields.is_a?(Enumerable(String)) ? fields : fields.map(&.to_s)
    JSON.parse(self.to_json).as_h.select!(string_keys).to_json
  end

  # Atomically update fields, without running callbacks
  def update_fields(**attributes)
    raise RethinkORM::Error::DocumentNotSaved.new("Cannot update fields of a new document!") if new_record?

    assign_attributes(**attributes)
    update_body = subset_json(attributes.keys)

    response = Connection.raw_json(update_body) do |q, doc|
      q.table(@@table_name)
        .get(@id)
        .update(doc)
    end

    replaced = response["replaced"]?.try(&.as_i?) || 0
    updated = response["updated"]?.try(&.as_i?) || 0
    clear_changes_information if replaced > 0 || updated > 0
    self
  end

  # Destroy object, run destroy callbacks and update associations
  #
  def destroy
    return self if destroyed?
    return self if new_record?

    run_destroy_callbacks do
      __delete
      self
    end
  end

  # Only deletes document from table. No callbacks or updated associations
  #
  def delete
    return self if destroyed?
    return self if new_record?

    __delete
  end

  # Reload the model in place.
  #
  # Throws
  # - RethinkORM::Error::DocumentNotSaved : If document was not previously persisted
  # - RethinkORM::Error::DocumentNotFound : If document fails to load
  #
  def reload!
    raise RethinkORM::Error::DocumentNotSaved.new("Cannot reload unpersisted document") unless persisted?
    loaded = self.class.find!(@id)

    # TODO: Make this faster by updating active-model to accept generic hashes, or at least the attributes hash of the same class
    new_attributes = loaded.attributes.reduce({} of String => String) do |attrs, kv|
      key, value = kv
      unless value.nil?
        attrs[key.to_s] = value.to_s
      end
      attrs
    end

    assign_attributes(new_attributes)

    clear_changes_information
    reset_associations

    self
  end

  # Internal update function, runs callbacks and pushes update to RethinkDB
  #
  protected def __update(**options)
    return false unless valid?
    return true unless changed?

    run_update_callbacks do
      run_save_callbacks do
        response = Connection.raw_json(self.to_json) do |q, doc|
          q.table(@@table_name)
            .get(@id)
            .update(doc, **options)
        end

        # TODO: Extend active-model to include previous changes
        # TODO: Update associations
        replaced = response["replaced"]?.try(&.as_i?) || 0
        updated = response["updated"]?.try(&.as_i?) || 0
        unchanged = response["unchanged"]?.try(&.as_i?) || 0
        success = replaced > 0 || updated > 0 || unchanged > 0

        clear_changes_information if success
        success
      end
    end
  end

  # Internal create function, runs callbacks and pushes new model to RethinkDB
  #
  protected def __create(**options)
    run_create_callbacks do
      run_save_callbacks do
        # TODO: Allow user to tag an attribute as primary key.
        #       Requires either changing default primary key or using secondary index
        @id ||= @@uuid_generator.next(self)

        response = Connection.raw_json(self.to_json) do |q, doc|
          q.table(@@table_name).insert(doc, **options)
        end

        # Set primary key if receiveing generated_key
        @id ||= response["generated_keys"]?.try(&.[0]?).try(&.to_s)

        success = (response["inserted"]?.try(&.as_i?) || 0) > 0

        clear_changes_information if success
        success
      end
    end
  end

  # Delete document in table, update model metadata
  #
  protected def __delete
    response = Connection.raw do |q|
      q.table(@@table_name)
        .get(@id)
        .delete
    end

    deleted = response["deleted"]?.try(&.as_i?) || 0
    @destroyed = deleted > 0
    clear_changes_information if @destroyed
    @destroyed
  end
end
