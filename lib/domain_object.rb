class DomainObject
  PRIMARY_KEY = {:identifier=>:id, :type=>Integer}

  def self.pk
    PRIMARY_KEY[:identifier]
  end
end