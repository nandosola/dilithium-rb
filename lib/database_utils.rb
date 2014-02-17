# -*- encoding : utf-8 -*-
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
    case entity
      # TODO refactor to a single class method in IdPk
      when BaseEntity, Association::LazyEntityReference, Association::ImmutableEntityReference  #TODO make this inherit from IdPK
        table_name_for(entity.type)
      when Class
        table_name_for(entity)
    end
  end

  def self.table_name_for(klazz)
    path = klazz.to_s.split('::')
    last = if path.last == 'Immutable'
             path[-2]
           else
             path.last
           end

    last.underscore.downcase.pluralize.to_sym
  end

  def self.to_reference_name(attr)
    "#{attr.name.to_s.singularize}_id".to_sym
  end
end
