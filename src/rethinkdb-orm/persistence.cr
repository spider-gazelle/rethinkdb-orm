require "crystal-rethinkdb"

require "./id_generator"
require "./connection"

module RethinkORM::Persistence

  getter? destroyed = false

  def new_record?
    @__key__.nil?
  end

  def persisted?
    !(new_record? || destroyed?)
  end

  macro included

    # Creates the model
    #
    # Raises a RethinkORM::Error::DocumentNotSaved if failed to created
    def self.create!(**attributes)
      document = new(**attributes)
      raise Error::DocumentNotSaved.new("Failed to create document!") unless document.save
      document
    end

    # Creates the model
    #
    def self.create(**attributes)
      document = new(**attributes)
      document.save
      document
    end

    property uuid_generator = IdGenerator
  end

  # Saves the model.
  #
  # If the model is new, a record gets created in the database, otherwise
  # the existing record gets updated.
  def save(**options)
    raise Error::DocumentInvalid.new("Cannot save a destroyed document!") if destroyed?
    return false unless valid?

    new_record? ? __create(**options) : __update(**options)
    self
  end

  # Saves the model.
  #
  # If the model is new, a record gets created in the database, otherwise
  # the existing record gets updated.
  # Raises RethinkORM::Error:DocumentInvalid on validation failure
  def save!(**options)
    raise Error::DocumentInvalid.new("Failed to save the document", self) unless self.save(**options)
    self
  end

  # Updates the model
  #
  # Non-atomic updates are required for multidocument updates
  def update(*attributes, **options)
    options = {
      non_atomic: false,
    }.merge(options)

    assign_attributes(*attributes)
    __update
  end

  # Updates the model in place
  #
  # Throws Error::DocumentInvalid on update failure
  def update!(*attributes, **options)
    updated = self.update(*attributes, **options)
    raise Error::DocumentInvalid.new("Failed to update the document", self) unless updated
    self
  end

  def destroy(**options)
    return self if destroyed?

    options = {
      non_atomic: false,
    }.merge(options)

    run_destroy_callbacks do
      Connection.raw do |q|
        q.table(@@table_name)
          .get(@__key__)
          .delete
      end
      clear_changes_information
      self
    end
  end

  protected def __update(**options)
    return false unless valid?
    return true unless changed?

    run_update_callbacks do
      run_save_callbacks do
        response = Connection.raw do |q|
          q.table(@@table_name)
            .get(@__key__)
            .update(changed_attributes, **options)
        end

        # TODO: Extend active-model to include previous changes
        # TODO: Update associations
        clear_changes_information
        replaced = response["replaced"].as_i? || 0
        updated = response["updated"].as_i? || 0
        replaced > 0 || updated > 0
      end
    end
  end

  protected def __create(**options)
    run_create_callbacks do
      run_save_callbacks do

        # TODO: Allow user to tag an attribute as primary key
        id = @id || self.uuid_generator.next(self)

        document = self.attributes.merge({:id => id})

        response = Connection.raw do |q|
          q.table(@@table_name).insert(document, **options) 
        end

        # Set primary key
        @__key__ = response["generated_keys"][0]?.try(&.to_s) || id

        # TODO: Create associations
        clear_changes_information

        inserted = response["inserted"].as_i? || 0
        inserted > 0
      end
    end
  end
end
