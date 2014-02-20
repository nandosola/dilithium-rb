# -*- encoding : utf-8 -*-

module Dilithium

  class VersionAlreadyLockedException < Exception; end
  class VersionNotFoundException < Exception; end

  class SharedVersion
    INITIAL_SEQUENCE = 0
    UTC_OFFSET = 0

    attr_reader :id, :_version, :_version_created_at, :_locked_by, :_locked_at, :versioned_object

    def initialize(args)
      args.each do |k,v|
        instance_variable_set("@#{k}".to_sym, v) if self.respond_to?(k.to_sym)
      end
    end

    def is_new?
      @_version == INITIAL_SEQUENCE
    end

    def ==(other)
      self.class == other.class &&
          @_version == other._version &&
          @_version_created_at == other._version_created_at &&
          @_locked_by == other._locked_by &&
          @_locked_at == other._locked_at
    end

    def self.create(versioned_object)
      SharedVersion.new(id:nil, _version:INITIAL_SEQUENCE, _version_created_at:utc_tstamp,
                        _locked_by:nil, _locked_at:nil, versioned_object:versioned_object)
    end

    def self.utc_tstamp
      DateTime.now.new_offset(UTC_OFFSET)
    end

    def increment
      @_version += 1
      @_version_created_at = SharedVersion.utc_tstamp
    end

    def rw_lock(locker)
      @_locked_by = locker
      @_locked_at = SharedVersion.utc_tstamp
    end

    def unlock
      @_locked_by = nil
      @_locked_at = nil
    end

    def to_h
      {
        id:id, _version:_version, _version_created_at:_version_created_at,
        _locked_by:_locked_by, _locked_at:_locked_at
      }
    end

    # Database-related stuff

    def self.create_table
      unless DB.table_exists?(:_versions)
        DB.create_table(:_versions) do
          primary_key :id
          Integer :_version
          DateTime :_version_created_at
          String :_locked_by
          DateTime :_locked_at
        end
      end
    end

    def self.add_to_table(table_name)
      DB.alter_table(table_name) do
        add_foreign_key :_version_id, :_versions
      end
    end

    def self.resolve(klazz, obj_id)
      # TODO: file a bug report: Sequel's natural_join returns the previous value in SQLite
      table = DatabaseUtils.to_table_name(PersistenceService.inheritance_root_for(klazz))
      obj_h = DB[table].where(:"#{table}__id" => obj_id).join(:_versions, :id=>:_version_id).first
      raise VersionNotFoundException, "#{klazz} with id #{obj_id} has no version associated with it" if obj_h.nil?
      SharedVersion.new(_version:obj_h[:_version], _version_created_at:obj_h[:_version_created_at],
                        _locked_by:obj_h[:_locked_by], _locked_at:obj_h[:_locked_at], id:obj_h[:_version_id])
    end

    def insert!
      @id = DB[:_versions].insert(_version:_version, _version_created_at:_version_created_at,
                                  _locked_by:_locked_by, _locked_at:_locked_at)
    end

    def increment!
      # FIXME Mutex this
      increment
      updated_rows = DB[:_versions].for_update.where(id:id).update(_version:_version,
                                                                   _version_created_at:_version_created_at,
                                                                   _locked_by:_locked_by, _locked_at:_locked_at)
      raise VersionAlreadyLockedException if 0 == updated_rows
    end

    def rw_lock!(locker)
      # FIXME Mutex this
      updated_rows = DB[:_versions].for_update.where(id:id, _locked_by:nil).update(_locked_by:locker,
                                                                                   _locked_at:SharedVersion.utc_tstamp)
      raise VersionAlreadyLockedException if 0 == updated_rows
      rw_lock(locker)
    end

    def unlock!(unlocker)
      # FIXME Mutex this
      updated_rows = DB[:_versions].for_update.where(id:id, _locked_by:unlocker).update(_locked_by:nil, _locked_at:nil)
      raise VersionAlreadyLockedException if 0 == updated_rows
      unlock
    end

  end
end
