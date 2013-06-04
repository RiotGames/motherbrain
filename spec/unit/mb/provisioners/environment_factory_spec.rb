require 'spec_helper'

describe MB::Provisioner::EnvironmentFactory do
  let(:manifest) {
    MB::Provisioner::Manifest.new.from_json(manifest_hash.to_json)
  }
  let(:manifest_hash) {
    {
      nodes: [
        {
          type: "m1.large",
          count: 4,
          components: ["activemq::master"]
        },
        {
          type: "m1.large",
          count: 2,
          components: ["activemq::slave"]
        },
        {
          type: "m1.small",
          count: 2,
          components: ["nginx::server"]
        }
      ]
    }
  }

  describe "ClassMethods" do
    subject { described_class }

    describe "::convert_manifest" do
      it "returns an array of hashes" do
        subject.convert_manifest(manifest).should be_a(Array)
        subject.convert_manifest(manifest).should each be_a(Hash)
      end

      it "contains an element for the amount of each node group and instance type" do
        subject.convert_manifest(manifest).should have(8).items
      end

      describe "with different ordering" do
        let(:manifest_hash) {
          {
            nodes: [
              { groups: "default", type: "none" },
              { type: "none", groups: "default", count: 2 }
            ]
          }
        }

        it "it still works" do
          subject.convert_manifest(manifest).should be_a(Array)
        end
      end
    end
  end

  let(:options) do
    {
      api_url: "https://ef.riotgames.com",
      api_key: "58dNU5xBxDKjR15W71Lp",
      ssl: {
        verify: false
      }
    }
  end

  subject { described_class.new(options) }

  describe "#up" do
    let(:job) { double('job') }
    let(:env_name) { "mbtest" }
    let(:plugin) { double('plugin') }

    before(:each) do
      job.stub(:set_status)
    end

    context "if given skip_bootstrap option" do
      it "skips the bootstrap process" do
        connection = double('connection')
        environment = double('environment')
        converted_manifest = double('converted_manifest')
        subject.stub(connection: connection)
        described_class.should_receive(:convert_manifest).with(manifest).and_return(converted_manifest)
        described_class.should_receive(:handle_created).with(environment).and_return(Array.new)
        described_class.should_receive(:validate_create).and_return(true)
        connection.stub_chain(:environment, :create).with(env_name, converted_manifest).and_return(Hash.new)
        connection.stub_chain(:environment, :created?).with(env_name).and_return(true)
        connection.stub_chain(:environment, :find).with(env_name, force: true).and_return(environment)

        subject.up(job, env_name, manifest, plugin, skip_bootstrap: true)
      end
    end
  end

  describe "#down" do
    let(:job) { double('job') }
    let(:env_name) { "mbtest" }

    before(:each) do
      job.stub(:set_status)
    end

    it "sends a destroy command to environment factory with the given environment" do
      connection = double('connection')
      subject.stub(connection: connection)
      subject.should_receive(:destroyed?).with(env_name).and_return(true)
      connection.stub_chain(:environment, :destroy).with(env_name).and_return(Hash.new)

      subject.down(job, env_name)
    end
  end
end
