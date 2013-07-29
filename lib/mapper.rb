class SequelMapper
  def transaction &block
    DB.transaction &block
  end

  def save(obj)
    obj.save
  end

  def delete(obj)
    obj.delete
  end

  def reload(obj)
    obj.refresh
  end
end
