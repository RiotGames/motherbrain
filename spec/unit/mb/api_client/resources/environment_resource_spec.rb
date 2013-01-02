require 'spec_helper'

describe MB::ApiClient::EnvironmentResource do
  subject { MB::ApiClient.new.environment }

  describe "#bootstrap" do
    let(:plugin_id) { "activemq" }
    let(:env_id) { "rspec-environment" }
    let(:manifest) { MB::Bootstrap::Manifest.new }

    it "sends a PUT to /environments/{id}.json" do
      req_body = MultiJson.encode(
        manifest: manifest,
        plugin: {
          name: plugin_id,
          version: nil
        },
        force: nil,
        hints: nil
      )

      stub_request(:put, "http://0.0.0.0:1984/environments/#{env_id}.json").
        with(body: req_body).
        to_return(status: 200, body: MultiJson.encode({}))

      subject.bootstrap(env_id, plugin_id, manifest)
    end
  end

  describe "#destroy" do
    let(:env_id) { "rspec-environment" }

    it "sends a DELETE to /environments/{id}.json" do
      stub_request(:delete, "http://0.0.0.0:1984/environments/#{env_id}.json").
        to_return(status: 200, body: MultiJson.encode({}))

      subject.destroy(env_id).should be_a(Hash)
    end
  end

  describe "#provision" do
    let(:plugin_id) { "activemq" }
    let(:env_id) { "rspec-environment" }
    let(:manifest) { MB::Provisioner::Manifest.new }

    it "sends a POST to /environments/{id}.json" do
      req_body = MultiJson.encode(
        manifest: manifest,
        plugin: {
          name: plugin_id,
          version: nil
        }
      )

      stub_request(:post, "http://0.0.0.0:1984/environments/#{env_id}.json").
        with(body: req_body).
        to_return(status: 200, body: MultiJson.encode({}))

      subject.provision(env_id, plugin_id, manifest)
    end
  end
end
