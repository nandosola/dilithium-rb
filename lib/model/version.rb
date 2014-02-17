# -*- encoding : utf-8 -*-

require_relative '../../lib/persistence/repository'

String.inflections do |inflect|
  inflect.irregular '_version', '_versions'
end

module Dilithium

class VersionAlreadyLockedException < Exception; end

# TODO: rename to SharedVersion
# FIXME this should really be an Active Record (pattern) object
class Version < DomainObject
  extend Repository::Sequel::ClassFinders

  INITIAL_VERSION = 0
  UTC_OFFSET = 0

  add_attribute BasicAttributes::GenericAttribute.new(:_version, Integer)
  add_attribute BasicAttributes::GenericAttribute.new(:_version_created_at, DateTime)
  add_attribute BasicAttributes::GenericAttribute.new(:_locked_by, String)   # FIXME: rename to _locked_by_transaction
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

  def lock!(locked_by)
    if @_locked_by.nil?
      @_locked_by = locked_by
      @_locked_at = Version.utc_tstamp
    else
      raise VersionAlreadyLockedException, "Cannot lock! - already locked by #{@_locked_by} at #{@_locked_at}" \
        unless @_locked_by == locked_by
    end
  end

  def unlock!
    @_locked_by = nil
    @_locked_at = nil
  end

  # FIXME check locks!
  def increment!
    @_version += 1
    @_version_created_at = Version.utc_tstamp
  end

  def ==(other)
    self.class == other.class &&
      @_version == other._version &&
      @_version_created_at == other._version_created_at &&
      @_locked_by == other._locked_by &&
      @_locked_at == other._locked_at
  end
end
end
