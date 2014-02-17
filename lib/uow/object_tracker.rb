# -*- encoding : utf-8 -*-
require 'tsort'
require 'set'

module UnitOfWork
  class ObjectTracker
    include ObjectTrackerExceptions

    attr_reader :allowed_states

    protected
    class TrackedObject
      attr_accessor :object, :state

      def initialize(obj, st, outer)
        @object = obj
        @state = st
        @parent = outer
        check_valid_state(st)
      end

      def state=(st)
        check_valid_state(st)
        @state = st
      end

      def check_valid_state(st)
        unless @parent.allowed_states.include?(st)
          raise InvalidStateException,
                "State is not valid. Allowed states are #{@parent.allowed_states}"
        end
      end
    end

    public
    class TrackedObjectSearchResult
      ARRAY_T = :array; SINGLE_T = :single
      RETURN_TYPES = [ARRAY_T, SINGLE_T]
      attr_reader :object, :state

      class << self
        protected :new
      end

      def initialize(tracked_object)
        @object = tracked_object.object
        @state = tracked_object.state
      end

      def self.factory(results, return_type=ARRAY_T)
        TrackedObjectSearchResult.check_results_array(results)

        if RETURN_TYPES.include?(return_type)

          if SINGLE_T == return_type
            TrackedObjectSearchResult.check_single_or_empty_result(results)
          end

          if results.nil? || results.empty?
            (SINGLE_T == return_type) ? nil : []
          else
            res = results.map {|to| TrackedObjectSearchResult.new(to)}
            (SINGLE_T == return_type) ? res.first : res
          end

        else
          raise ArgumentError, "Unknown return_type: #{return_type}. Valid types are: #{RETURN_TYPES}"
        end
      end

      def self.check_results_array(results)
        unless results.is_a?(Array)
          raise ArgumentError, "First argument must be an Array. Found: #{results.class} instead"
        end
      end

      def self.check_single_or_empty_result(results)
        if 1 < results.count
          raise MultipleTrackedObjectsException, "Found same object #{results.count} times!"
        end
      end
    end

    class ReferenceSorter
      include ObjectTrackerExceptions
      include TSort

      def initialize(results_collection, tracker)
        @obj_tracker = tracker
        @results = results_collection
        @sorted_results = Array.new
      end

      def sort
        sorted_deps = tsort
        root_classes = (Set.new(@results.map{|res| res.object}) - Set.new(sorted_deps)).to_a
        (sorted_deps + root_classes).reduce(@sorted_results) do |memo, entity|
          found_res = @results.select{|res| entity == res.object}
          Array(found_res).empty? ? memo: memo.push(found_res.first)
        end
        @sorted_results
      end

      private
      def process_node(node)
        node.each_reference(true) do |ref|
          actual_ref = case ref
                         when Association::ImmutableEntityReference
                           #TODO Do we really need to resolve this? Or should the TSort ignore any unresolved ImmutableEntityReferences?
                           ref.resolve
                           ref.instance_variable_get(:'@original_entity')
                         when Association::LazyEntityReference
                           #TODO Do we really need to resolve this? Or should the TSort ignore any unresolved LazyEntityReferences?
                           ref.resolved_entity
                         else
                           ref
                       end
          yield actual_ref
        end
      end

      def tsort_each_node(&block)
        @results.each do |res|
          process_node(res.object, &block)
        end
      end

      def tsort_each_child(node, &block)
        check_valid_reference(node)
        process_node(node, &block)
      end

      def check_valid_reference(ref)
        sr = @obj_tracker.fetch_object(ref)
        if ref.id.nil? && sr.nil?
          raise UntrackedReferenceException.new(ref, @obj_tracker)
        end
      end
    end

    def initialize(states_array)
      @allowed_states = states_array
      @tracker = []
    end

    def track(obj, st)
      @tracker<< TrackedObject.new(obj, st, self) if fetch_tracked_object(obj).nil?
    end
    alias_method :<<, :track

    def untrack(obj)
      tracked_object = fetch_tracked_object(obj)
      ObjectTracker.check_not_nil(tracked_object)
      @tracker.delete(tracked_object)
    end
    alias_method :delete, :untrack

    def change_object_state(obj, st)
      tracked_object = fetch_tracked_object(obj)
      ObjectTracker.check_not_nil(tracked_object)
      tracked_object.state = st
    end

    def fetch_by_state(st)
      found_array = @tracker.select {|to| st == to.state}
      TrackedObjectSearchResult.factory(found_array)
    end

    def fetch_in_dependency_order(st)
      search_results = fetch_by_state(st)
      ReferenceSorter.new(search_results, self).sort
    end

    def fetch_all
      TrackedObjectSearchResult.factory(@tracker)
    end

    def fetch_object(obj)
      found_array = @tracker.select {|to| obj == to.object}
      TrackedObjectSearchResult.factory(found_array, TrackedObjectSearchResult::SINGLE_T)
    end

    def fetch_by_class(klazz, search_id=nil)
      filter = lambda do |obj|
        if search_id.nil?
          obj.object.is_a?(klazz)
        else
          obj.object.is_a?(klazz) && search_id == obj.object.id
        end
      end
      found_array = @tracker.select {|to| filter.call(to) }

      if search_id.nil?
        TrackedObjectSearchResult.factory(found_array)
      else
        TrackedObjectSearchResult.factory(found_array, TrackedObjectSearchResult::SINGLE_T)
      end
    end

    private
    def fetch_tracked_object(obj)
      found_array = @tracker.select {|to| obj == to.object}
      TrackedObjectSearchResult.check_single_or_empty_result(found_array)
      found_array[0]
    end

    def self.check_not_nil(obj)
      if obj.nil?
        raise UntrackedObjectException, "Object #{obj.inspect} is not tracked!"
      else
        obj
      end
    end
  end
end
