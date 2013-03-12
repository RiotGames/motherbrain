require 'spec_helper'

describe MB::EnvironmentManager do
  describe "#async_configure" do
    let(:environment) { "rspec-test" }
    let(:options) { Hash.new }

    it "asynchronously calls #configure and returns a JobRecord" do
      subject.should_receive(:async).with(:configure, kind_of(MB::Job), environment, options)

      subject.async_configure(environment, options).should be_a(MB::JobRecord)
    end
  end

  describe "#configure" do
    pending
  end

  describe "#find" do    
    context "when the environment is not present on the remote Chef server" do
      let(:env_id) { "rspec" }

      before(:each) do
        MB::Application.ridley.stub_chain(:environment, :find!).
          with(env_id).and_raise(Ridley::Errors::ResourceNotFound)
      end

      it "raises an EnvironmentNotFound error" do
        expect {
          subject.find(env_id)
        }.to raise_error(MB::EnvironmentNotFound, "no environment '#{env_id}' was found")
      end
    end
  end

  describe "#list" do
    pending
  end
end
