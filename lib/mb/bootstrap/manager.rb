module MotherBrain
  module Bootstrap
    # @author Jamie Winsor <jamie@vialstudios.com>
    class Manager
      class << self
        # @raise [Celluloid::DeadActorError] if Bootstrap Manager has not been started
        #
        # @return [Celluloid::Actor(Bootstrap::Manager)]
        def instance
          Celluloid::Actor[:bootstrap_manager] or raise Celluloid::DeadActorError, "bootstrap manager not running"
        end

        # @param [Hash] options (Hash.new)
        #
        # @raise [ArgumentError] if any required option or value is missing or invalid
        def validate_options(options = {})
          missing = (REQUIRED_OPTS - options.keys)

          unless missing.empty?
            missing.collect! { |opt| "'#{opt}'" }
            raise ArgumentError, "Missing required option(s): #{missing.join(', ')}"
          end

          missing_values = options.slice(*REQUIRED_OPTS).select { |key, value| !value.present? }

          unless missing_values.empty?
            values = missing_values.keys.collect { |opt| "'#{opt}'" }
            raise ArgumentError, "Missing value for required option(s): '#{values.join(', ')}'"
          end

          unless File.exists?(options[:client_key])
            raise ArgumentError, "Chef Client key required for bootstrap and not found at: '#{options[:client_key]}'"
          end

          unless File.exists?(File.expand_path(options[:validator_path]))
            raise ArgumentError, "Chef Validator required for Bootstrap and not found at: '#{options[:validator_path]}'"
          end
        end
      end

      include Celluloid
      include MB::Logging
      include MB::Locks

      # Required options for {#bootstrap}
      REQUIRED_OPTS = [
        :server_url,
        :client_name,
        :client_key,
        :validator_client,
        :validator_path,
        :ssh
      ].freeze

      def initialize
        log.info { "Bootstrap Manager starting..." }
      end

      # Bootstrap a collection of nodes described in the given manifest by performing
      # each {BootTask} in the proper order
      #
      # @param [Bootstrap::Manifest] manifest
      #   manifest of nodes and what they should become
      # @param [Bootstrap::Routine] routine
      #   routine to follow for the bootstrap process
      # @option options [Hash] :ssh
      #   * :user (String) a shell user that will login to each node and perform the bootstrap command on (required)
      #   * :password (String) the password for the shell user that will perform the bootstrap
      #   * :keys (Array, String) an array of keys (or a single key) to authenticate the ssh user with instead of a password
      #   * :timeout (Float) [5.0] timeout value for SSH bootstrap
      #   * :sudo (Boolean) [True] bootstrap with sudo
      # @option options [String] :server_url
      #   URL to the Chef API to bootstrap the target node(s) to (required)
      # @option options [String] :client_name
      #   name of the client used to authenticate with the Chef API (required)
      # @option options [String] :client_key
      #   filepath to the client's private key used to authenticate with the Chef API (requirec)
      # @option options [String] :organization
      #   the Organization to connect to. This is only used if you are connecting to
      #   private Chef or hosted Chef
      # @option options [String] :validator_client
      #   the name of the Chef validator client to use in bootstrapping (requirec)
      # @option options [String] :validator_path
      #   filepath to the validator used to bootstrap the node (required)
      # @option options [String] :encrypted_data_bag_secret_path (nil)
      #   filepath on your host machine to your organizations encrypted data bag secret
      # @option options [String] :environment ('_default')
      # @option options [Hash] :hints (Hash.new)
      #   a hash of Ohai hints to place on the bootstrapped node
      # @option options [String] :template ("omnibus")
      #   bootstrap template to use
      # @option options [String] :bootstrap_proxy (nil)
      #   URL to a proxy server to bootstrap through
      def bootstrap(environment, manifest, routine, options = {})
        job = Job.new(:bootstrap)

        async.start(environment, manifest, routine, job, options)

        job.ticket
      end

      # @see #bootstrap
      #
      # @param [MotherBrain::Job] job
      def start(environment, manifest, routine, job, options = {})
        job.report_running

        self.class.validate_options(options)
        manifest.validate!(routine)

        task_queue = routine.task_queue.dup

        unless Application.ridley.environment.find(environment)
          raise EnvironmentNotFound, "Environment: '#{environment}' not found on '#{Application.ridley.server_url}'"
        end

        log.info { "Starting bootstrap of nodes on: #{environment}" }
        async.sequential_bootstrap environment, manifest, task_queue, job, options
      rescue => error
        job.report_failure(error)
      end

      def finalize
        log.info { "Bootstrap Manager stopping..." }
      end

      # @see #bootstrap
      #
      # @param [MotherBrain::Job] job
      def sequential_bootstrap(environment, manifest, task_queue, job, options = {})
        chef_synchronize(chef_environment: environment, force: options[:force], job: job) do
          while tasks = task_queue.shift
            job.status = "Bootstrapping #{tasks.collect(&:id).join(', ')}"

            concurrent_bootstrap(manifest, tasks, options)
          end
        end

        job.report_success
      rescue => error
        job.report_failure(error)
      end

      # Concurrently bootstrap a grouped collection of nodes from a manifest and return
      # their results. This function will block until all nodes have finished
      # bootstrapping.
      #
      # @param [Bootstrap::Manifest] manifest
      #   a hash where the keys are node group names and the values are arrays of hostnames
      # @param [BootTask, Array<BootTask>] boot_tasks
      #   a hash where the keys are node group names and the values are arrays of hostnames
      # @option options [String] :environment ('_default')
      # @option options [Hash] :hints (Hash.new)
      #   a hash of Ohai hints to place on the bootstrapped node
      # @option options [String] :template ("omnibus")
      #   bootstrap template to use
      # @option options [String] :bootstrap_proxy (nil)
      #   URL to a proxy server to bootstrap through
      #
      # @return [Hash]
      #   a hash where keys are group names and their values are their Ridley::SSH::ResultSet
      def concurrent_bootstrap(manifest, boot_tasks, options = {})
        workers = Array(boot_tasks).collect do |boot_task|
          nodes = manifest[boot_task.id]

          worker_options = options.merge(
            run_list: boot_task.group.run_list,
            attributes: boot_task.group.chef_attributes
          )

          Worker.new(boot_task.id, nodes, worker_options)
        end

        futures = workers.collect do |worker|
          [
            worker.group_id,
            worker.future.run
          ]
        end

        {}.tap do |response|
          futures.each do |group_id, future|
            response[group_id] = future.value
          end
        end
      ensure
        workers.map { |worker| worker.terminate if worker.alive? }
      end
    end
  end
end
