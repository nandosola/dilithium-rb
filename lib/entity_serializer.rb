class EntitySerializer

  def self.to_hash(entity)
    h = {}
    entity.instance_variables.each do |attr|
      attr_name = attr.to_s[1..-1].to_sym
      attr_value = entity.instance_variable_get(attr)
      h[attr_name] =  attr_value
    end
    h
  end

  def self.clone(entity)
    # deep-clones references too
    Marshal.load(Marshal.dump(entity))
  end

end