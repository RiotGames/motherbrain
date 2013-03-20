require 'spec_helper'

describe MB::CliGateway do
  describe "ClassMethods" do
    subject { described_class }

    describe "::new" do
      describe "specifying a configuration file" do
        let(:location) { tmp_path.join('config.json').to_s }

        before(:each) do
          generate_valid_config(location)
        end

        it "loads the specified config file into the ConfigManager" do
          config = MB::Config.from_file(location)
          invoker = subject.new([], config: location)

          MB::ConfigManager.instance.config._attributes_.should eql(config._attributes_)
        end

        it "raises a ConfigNotFound error when the specified path does not exist" do
          lambda {
            invoker = subject.new([], config: tmp_path.join("not_there.json"))
          }.should raise_error(Chozo::Errors::ConfigNotFound)
        end

        it "raises a ConfigNotFound error when the specified path is a directory" do
          lambda {
            invoker = subject.new([], config: tmp_path)
          }.should raise_error(Chozo::Errors::ConfigNotFound)
        end
      end
    end

    describe "::requires_environment?" do
      context "no arguments" do
        it "should not require an environment" do
          subject.requires_environment?([]).should be_false
        end
      end

      context "base command" do
        ["destroy", "lock", "unlock"].each do |command|
          it "should require an environment for #{command}" do
            subject.requires_environment?([command]).should be_true
          end
        end

        it "should require an environment for configure_environment" do
          subject.requires_environment?(["configure_environment", "manifest"]).should be_true
        end

        it "should not require an environment for versions" do
          subject.requires_environment?(["versions"]).should be_false
        end
      end

      context "plugin argument" do
        it "should not require an environment for a plugin" do
          subject.requires_environment?(["myface"]).should be_false
        end
      end
      
      context "plugin command" do
        it "should require an environment for bootstrap" do
          subject.requires_environment?(["myface", "bootstrap"]).should be_true
        end

        it "should not require an environment for help" do
          subject.requires_environment?(["myface", "help"]).should be_false
        end

        it "should not require an environment for subtask help" do
          subject.requires_environment?(["myface", "help", "bootstrap"]).should be_false
        end
      end
    end

    describe "::start_mb_application?" do
      let(:args) {["myface"]}

      context "not a config task" do
        it "should be true" do
          subject.start_mb_application?(args).should be_true
        end
      end

      context "is a config task" do
        it "should be false" do
          subject::SKIP_CONFIG_TASKS.each do |config_task|
            args = [config_task]
            subject.start_mb_application?(args)
          end
        end
      end
    end

    describe "::register_plugin" do
      let(:name) { "myface" }
      let(:options) { {plugin_version: nil, environment: "test_env"} }
      let(:metadata) do
        double('metadata',
          valid?: true,
          name: name,
          description: "Ivey should use SublimeText 2"
        )
      end

      let(:plugin) { MB::Plugin.new(metadata) }
      let(:plugin_sub_command) { double(name: "#{name} sub command", plugin: name, version: options[:plugin_version]) }

      before(:each) do
        MB.ui.stub(:say)
      end

      context "with a version" do
        before(:each) do
          options[:plugin_version] = "1.2.3"
        end

        context "that doesn't exist" do
          before(:each) do
            MB::Application.stub_chain(:plugin_manager, :find).and_return(nil)
            MB::Application.stub_chain(:plugin_manager, :for_environment).and_return(nil)
          end

          it "should notify the user" do
            MB.ui.should_receive(:say).with("No cookbook with myface (version 1.2.3) plugin was found in your Berkshelf.")
            lambda {
              subject.register_plugin name, options
            }.should raise_error(SystemExit)
          end
        end

        context "that exists" do
          before(:each) do
            MB::Cli::SubCommand.stub(:fabricate).and_return(plugin_sub_command)
            MB::Application.stub_chain(:plugin_manager, :find).and_return(plugin)
            plugin_sub_command.stub(:plugin).and_return(plugin)
          end

          it "should register the plugin" do
            subject.should_receive(:register)
            subject.register_plugin name, options
          end
        end
      end

      context "without a version" do
        context "that doesn't exist" do
          before(:each) do
            MB::Application.stub_chain(:plugin_manager, :find).and_return(nil)
            MB::Application.stub_chain(:plugin_manager, :for_environment).and_return(nil)
          end

          it "should notify the user" do
            MB.ui.should_receive(:say).with("No cookbook with myface plugin was found for the test_env environment.")
            lambda {
              subject.register_plugin name, options
            }.should raise_error(SystemExit)
          end
        end

        context "that exists" do
          before(:each) do
            MB::Cli::SubCommand.stub(:fabricate).and_return(plugin_sub_command)
            MB::Application.stub_chain(:plugin_manager, :for_environment).and_return(plugin)
            plugin_sub_command.stub(:plugin).and_return(plugin)
          end

          it "should register the plugin" do
            subject.should_receive(:register)
            subject.register_plugin name, options
          end
        end
      end
    end
  end
end
