module DatabaseUtils

  # Returns an entity associated DB table name
  #
  # Example:
  #   Employee => :employees
  #
  # Params:
  # - entity: entity for converting class to table name
  # Returns:
  #   Symbol with table name
  def self.to_table_name(entity)
    #TODO : extract this to an utilities class/module
    klazz = case entity
              # TODO refactor to a single class method in IdPk
              when BaseEntity
                entity.class
              when Association::ReferenceEntity  #TODO make this inherit from IdPK
                entity.type
              when Class
                entity
            end
    klazz.to_s.split('::').last.underscore.downcase.pluralize.to_sym
  end

  def self.to_reference_name(attr)
    "#{attr.name.to_s.singularize}_id".to_sym
  end
end