module MotherBrain
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Plugin
    class << self
      # Create a new plugin instance from the given content
      #
      # @raise [PluginLoadError]
      #
      # @yieldreturn [MotherBrain::Plugin]
      def load(&block)
        new(&block).validate!
      rescue Errno::ENOENT => error
        ErrorHandler.wrap PluginLoadError.new
      rescue => error
        ErrorHandler.wrap error
      end

      # Load a plugin from the given file
      #
      # @param [String] path
      #
      # @raise [PluginLoadError]
      #
      # @return [MotherBrain::Plugin]
      def from_file(path)
        block = proc {
          eval(File.read(path))
        }
        load(&block)
      rescue => error
        ErrorHandler.wrap error, file_path: path
      end

      def key_for(name, version)
        "#{name}-#{version}".to_sym
      end
    end

    NODE_GROUP_ID_REGX = /^(.+)::(.+)$/.freeze

    include Chozo::VariaModel

    attribute :name,
      type: String,
      required: true

    attribute :version,
      type: Solve::Version,
      required: true,
      coerce: lambda { |m|
        Solve::Version.new(m)
      }

    attribute :description,
      type: String,
      required: true

    attribute :author,
      type: [String, Array]

    attribute :email,
      type: [String, Array]

    attribute :bootstrap_routine,
      type: MB::Bootstrap::Routine

    attr_reader :components
    attr_reader :commands
    attr_reader :dependencies

    def initialize(&block)
      @components   = Set.new
      @commands     = Set.new
      @dependencies = HashWithIndifferentAccess.new

      if block_given?
        dsl_eval(&block)
      end
    end

    # @return [Symbol]
    def id
      self.class.key_for(self.name, self.version)
    end

    # @param [String] name
    #
    # @return [MB::Component, nil]
    def component(name)
      components.find { |component| component.name == name }
    end

    # @param [String] name
    #
    # @raise [ComponentNotFound] if a component of the given name is not a part of this plugin
    #
    # @return [MB::Component]
    def component!(name)
      component = component(name)

      if component.nil?
        raise ComponentNotFound, "Component '#{name}' not found on plugin '#{self.name}' (#{self.version})"
      end

      component
    end

    # @param [#to_s] name
    #
    # @return [Boolean]
    def has_component?(name)
      component(name.to_s).present?
    end

    # @param [String] name
    #
    # @return [MB::Command]
    def command(name)
      command = commands.find { |command| command.name == name }

      if command.nil?
        raise CommandNotFound, "Command '#{name}' not found on component '#{self.name}'"
      end

      command
    end

    # Finds the nodes for the given environment for each {Component} of the plugin groups them
    # by Component#name and Group#name into a Hash where the keys are Component#name and 
    # values are a hash where the keys are Group#name and the values are a Hash representing
    # a node from Chef.
    #
    # @param [#to_s] environment
    #
    # @raise [MB::EnvironmentNotFound] if the target environment does not exist
    # @raise [MB::ChefConnectionError] if there was an error communicating to the Chef Server
    #
    # @example
    #
    #   {
    #     "activemq" => {
    #       database_masters" => [
    #         {
    #           "name" => "db-master1",
    #           ...
    #         }
    #       ],
    #       "database_slaves" => [
    #         {
    #           "name" => "db-slave1",
    #           ...
    #         },
    #         {
    #           "name" => "db-slave2",
    #           ...
    #         }
    #       ]
    #     }
    #   }
    #
    # @return [Hash]
    def nodes(environment)
      unless Application.ridley.environment.find(environment)
        raise EnvironmentNotFound, "Environment: '#{environment}' not found on '#{Application.ridley.server_url}'"
      end

      {}.tap do |nodes|
        self.components.each do |component|
          nodes[component.name] = component.nodes(environment)
        end
      end
    rescue Faraday::Error::ClientError, Ridley::Errors::RidleyError => e
      raise ChefConnectionError, "Could not connect to Chef server '#{Application.ridley.server_url}': #{e}"
    end

    # @param [MB::Component] component
    def add_component(component)
      self.components.add(component)
    end

    # @param [MB::Command] command
    def add_command(command)
      self.commands.add(command)
    end

    # @param [#to_s] name
    # @param [Solve::Constraint] constraint
    def add_dependency(name, constraint)
      self.dependencies[name.to_s] = Solve::Constraint.new(constraint)
    end

    # Completely validate a loaded plugin and raise an exception of errors
    #
    # @return [self]
    def validate!
      errors = validate

      if errors.any?
        ErrorHandler.wrap PluginSyntaxError,
          backtrace: [],
          plugin_name: try(:name),
          plugin_version: try(:version),
          text: messages_from_errors(errors)
      end

      self
    end

    # Creates an error message from an error hash, where the keys are attributes
    # and the values are an array of error messages.
    #
    # @param [Hash] errors
    # @return [String]
    def messages_from_errors(errors)
      buffer = []

      errors.each do |attribute, messages|
        buffer |= messages
      end

      buffer.join "\n"
    end

    def to_s
      "#{self.name} (#{self.version})"
    end

    private

      def dsl_eval(&block)
        CleanRoom.new(self).instance_eval(&block)
      end

    # A clean room bind the Plugin DSL syntax to. This clean room can later to
    # populate an instance of Plugin.
    #
    # @author Jamie Winsor <jamie@vialstudios.com>
    # @api private
    class CleanRoom < CleanRoomBase
      dsl_attr_writer :name
      dsl_attr_writer :version
      dsl_attr_writer :description
      dsl_attr_writer :author
      dsl_attr_writer :email

      # @param [#to_s] name
      # @param [#to_s] constraint
      def depends(name, constraint)
        real_model.add_dependency(name, constraint)
      end

      # @param [#to_s] name
      def command(name, &block)
        real_model.add_command Command.new(name, real_model, &block)
      end

      # @param [#to_s] name
      def component(name, &block)
        real_model.add_component Component.new(name, &block)
      end

      def cluster_bootstrap(&block)
        real_model.bootstrap_routine = Bootstrap::Routine.new(real_model, &block)
      end
    end
  end
end
