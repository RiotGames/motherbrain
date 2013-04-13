module MotherBrain
  # @author Jamie Winsor <reset@riotgames.com>
  module Provisioner
    autoload :Manager, 'mb/provisioner/manager'
    autoload :Manifest, 'mb/provisioner/manifest'

    class << self
      def included(base)
        base.extend(ClassMethods)
        base.send(:include, Celluloid)
        base.send(:include, MB::Logging)
        base.send(:include, MB::Mixin::Services)
      end
    end

    module ClassMethods
      # The identifier for the Provisioner
      #
      # @return [Symbol]
      attr_reader :provisioner_id

      # @param [#to_sym] provisioner_id
      def register_provisioner(provisioner_id, options = {})
        @provisioner_id = provisioner_id.to_sym
        Provisioners.register(self, options)
      end

      # Validate that the return created nodes contains the expected number of nodes and the proper
      # instance types
      #
      # @param [Array<Hash>] created
      # @param [Provisioner::Manifest] manifest
      #
      # @raise [UnexpectedProvisionCount] if an unexpected amount of nodes was returned by the
      #   request to the provisioner
      def validate_create(created, manifest)
        unless created.length == manifest.node_count
          raise UnexpectedProvisionCount.new(manifest.node_count, created.length)
        end
      end
    end

    # Request a provisioner to generate a set of nodes described by the given manifest
    #
    # @param [String] environment
    #   name of the set of nodes to be created
    # @param [MB::Provisioner::Manifest] manifest
    #   manifest describing how many and what kind of nodes to create
    #
    # @example
    #   [
    #     {
    #       instance_type: "m1.large",
    #       public_hostname: "cloud-1.riotgames.com"
    #     },
    #     {
    #       instance_type: "m1.small",
    #       public_hostname: "cloud-2.riotgames.com"
    #     }
    #   ]
    #
    # @return [Array]
    #   an array of hashes representing nodes generated of given sizes
    def up(job, env_name, manifest, plugin, options = {})
      raise AbstractFunction
    end

    # Destroy a set of provisioned nodes
    #
    # @param [String] environment
    #   name of the set of nodes to destroy
    #
    # @raise [MB::ProvisionError]
    #   if a caught error occurs during provisioning
    #
    # @return [Boolean]
    def down(job, env_name)
      raise AbstractFunction
    end

    # Delete an environment from Chef server
    #
    # @param [String] env_name
    #   name of the environment to remove
    def delete_environment(env_name)
      ridley.environment.delete(env_name)
    end
  end
end
