require 'domain_object'
require 'repository'

String.inflections do |inflect|
  inflect.irregular '_version', '_versions'
end

class Version < DomainObject
  extend Repository::Sequel::ClassFinders

  INITIAL_VERSION = 0
  UTC_OFFSET = 0

  add_attribute BasicAttributes::GenericAttribute.new(:_version, Integer)
  add_attribute BasicAttributes::GenericAttribute.new(:_version_created_at, DateTime)
  add_attribute BasicAttributes::GenericAttribute.new(:_locked_by, String)
  add_attribute BasicAttributes::GenericAttribute.new(:_locked_at, DateTime)

  def initialize(args)
    self.class.attribute_descriptors.each do |k,v|
      instance_variable_set("@#{k}".to_sym, args[k] || v.default)
    end
  end

  def self.create
    Version.new(_version:INITIAL_VERSION,
                _version_created_at:utc_tstamp,
                _locked_by:nil, _locked_at:nil)
  end

  def self.utc_tstamp
    DateTime.now.new_offset(UTC_OFFSET)
  end

  def is_new?
    @_version == INITIAL_VERSION
  end

  def lock!(session)
    @_locked_by = session
  end

  def unlock!
    @_locked_by = nil
  end

  def increment!
    if @_locked_by.nil?
      @_version += 1
      @_version_created_at = Version.utc_tstamp
    #else
      #  raise ConcurrentModificationException
    end
  end

end