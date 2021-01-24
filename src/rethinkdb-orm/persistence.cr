require "rethinkdb"

require "./connection"
require "./utils/id_generator"

module RethinkORM::Persistence
  # Flag to allow lazy querying of table status
  @@table_created = false

  # :nodoc:
  property _new_flag = false

  # Id generated on save or set on load
  def new_record?
    if destroyed?
      false
    else
      id_local = @id
      _new_flag || id_local.nil? || id_local.try &.empty?
    end
  end

  def persisted?
    !(new_record? || destroyed?)
  end

  property destroyed = false

  def destroyed?
    destroyed
  end

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

  # Serialization of a subset of the model's attributes.
  #
  # FIXME: Optimise
  protected def subset_json(fields : Enumerable(String) | Enumerable(Symbol))
    string_keys = fields.is_a?(Enumerable(String)) ? fields : fields.map(&.to_s)
    JSON.parse(self.to_json).as_h.select!(string_keys).to_json
  end

  # Atomically update specified fields, without running callbacks
  #
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
  def reload!
    raise RethinkORM::Error::DocumentNotSaved.new("Cannot reload unpersisted document") unless persisted?

    found = self.class.table_query &.get(self.id)
    raise RethinkORM::Error::DocumentNotFound.new("Key not present: #{id}") if found.raw.nil?

    assign_attributes_from_trusted_json(found.to_json)

    clear_changes_information
    reset_associations

    self
  end

  # Internal update function, runs callbacks and pushes update to RethinkDB
  #
  protected def __update(**options)
    return true unless changed?

    run_update_callbacks do
      run_save_callbacks do
        return false unless valid?

        response = Connection.raw_json(self.to_json) do |q, doc|
          q.table(@@table_name)
            .get(@id)
            .replace(doc, **options) # Replace allows fields to be set to null
        end

        # TODO: Extend active-model to include previous changes
        # TODO: Update associations
        replaced = response["replaced"]?.try(&.as_i?) || 0
        updated = response["updated"]?.try(&.as_i?) || 0
        unchanged = response["unchanged"]?.try(&.as_i?) || 0
        created = response["created"]?.try(&.as_i?) || 0
        success = replaced > 0 || created > 0 || updated > 0 || unchanged == 1

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
        return false unless valid?

        # TODO: Allow user to tag an attribute as primary key.
        #       Requires either changing default primary key or using secondary index
        id_local = @id

        @id = @@uuid_generator.next(self) if id_local.nil? || id_local.empty?

        response = Connection.raw_json(self.to_json) do |q, doc|
          q.table(@@table_name).insert(doc, **options)
        end

        # Set primary key if receiveing generated_key
        @id ||= response["generated_keys"]?.try(&.[0]?).try(&.to_s)

        success = (response["inserted"]?.try(&.as_i?) || 0) > 0

        if success
          clear_changes_information
          self._new_flag = false
        end

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
