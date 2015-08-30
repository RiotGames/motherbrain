module MotherBrain
  module Gear
    class Service
      # @api private
      class ActionRunner
        include MB::Mixin::Services

        attr_reader :environment
        attr_reader :nodes
        attr_reader :toggle_callbacks
        attr_reader :service_recipe
        attr_reader :environment_attributes
        attr_reader :node_attributes

        # @param [String] environment
        # @param [Array<Ridley::Node>] nodes
        def initialize(environment, nodes, &block)
          @environment = environment
          @nodes       = Array(nodes)

          @environment_attributes = Array.new
          @node_attributes        = Array.new
          @toggle_callbacks       = Hash.new

          if block_given?
            dsl_eval(&block)
          end
        end

        def reset(job)
          toggle_callbacks.keys.concurrent_map do |chunk|
            toggle_callbacks[chunk].map { |callback| callback.call(job) }
          end
        end

        def run(job)
          set_node_attributes(job)
          set_environment_attributes(job)
        end

        # Set an environment level attribute to the given value. The key is represented
        # by a dotted path.
        #
        # @param [String] key
        # @param [Object] value
        #
        # @option options [Boolean] :toggle (false)
        #   set this environment attribute only for a single chef run
        def add_environment_attribute(key, value, options = {})
          @environment_attributes << { key: key, value: value, options: options }
        end

        # Set a node level attribute on all nodes for this action to the given value.
        # The key is represented by a dotted path.
        #
        # @param [String] key
        # @param [Object] value
        #
        # @option options [Boolean] :toggle (false)
        #   set this node attribute only for a single chef run
        def add_node_attribute(key, value, options)
          @node_attributes << { key: key, value: value, options: options }
        end

        def set_service_recipe(recipe)
          @service_recipe = recipe
        end

        private

          def dsl_eval(&block)
            CleanRoom.new(self).instance_eval(&block)
          end

          class CleanRoom < CleanRoomBase
            dsl_attr_writer :component

            def service_recipe(recipe)
              real_model.set_service_recipe(recipe)
            end

            def environment_attribute(key, value, options = {})
              options = options.reverse_merge(toggle: false)
              real_model.add_environment_attribute(key, value, options)
            end

            def node_attribute(key, value, options = {})
              options = options.reverse_merge(toggle: false)
              real_model.add_node_attribute(key, value, options)
            end
          end

          def set_environment_attributes(job)
            return unless environment_attributes.any?

            unless env_chef_object = ridley.environment.find(environment)
              raise MB::EnvironmentNotFound.new(environment)
            end
            toggle_callbacks[environment] ||= []

            environment_attributes.each do |attribute|
              key, value, options = attribute[:key], attribute[:value], attribute[:options]

              if options[:toggle]
                toggle_callbacks[environment] << ->(job) {
                  message = "Toggling (removing) environment attribute '#{key}' on #{environment}"
                  job.set_status(message)
                  env_chef_object.delete_default_attribute(key)
                  env_chef_object.save
                }
              end

              job.set_status("Setting environment attribute '#{key}' to #{value.inspect} in #{environment}")
              env_chef_object.set_default_attribute(key, value)
            end

            job.set_status("Saving environment #{environment}")
            env_chef_object.save
          end

          # Set all node level attributes to the given node
          #
          # @param [Ridley::Job] job
          #  a job to send status updates to
          # @param [Ridley::NodeObject] node
          #   the node to set the attribute on
          def set_node_attributes(job)
            return if node_attributes.empty?

            nodes.concurrent_map do |node|
              node.reload
              toggle_callbacks[node.name] ||= []

              node_attributes.each do |attribute|
                key, value, options = attribute[:key], attribute[:value], attribute[:options]

                if options[:toggle]
                  original_value = node.chef_attributes.dig(key)

                  toggle_callbacks[node.name] << ->(job) {
                    message = if original_value.nil?
                      "Toggling off node attribute '#{key}' on #{node.name}"
                    elsif !options[:force_value_to].nil?
                      "Forcing node attribute to '#{options[:force_value_to]}' on #{node.name}"
                    else
                      "Toggling node attribute '#{key}' back to '#{original_value.inspect}' on #{node.name}"
                    end
                    job.set_status(message)
                    value_to_set = options[:force_value_to].nil? ? original_value : options[:force_value_to]
                    node.set_chef_attribute(key, value_to_set)
                    node.save
                  }
                end

                job.set_status("Setting node attribute '#{key}' to #{value.inspect} on #{node.name}")
                node.set_chef_attribute(key, value)
              end

              node.save
            end
          end
      end
    end
  end
end
