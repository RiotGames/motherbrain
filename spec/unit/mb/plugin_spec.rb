require 'spec_helper'

describe MB::Plugin do
  describe "ClassMethods" do
    subject { MB::Plugin }

    describe "::load" do
      subject(:plugin) {
        described_class.load(@context, &data)
      }

      let(:data) {
        proc {
          name 'reset'
          version '1.2.3'
          description 'a good plugin'
          author 'Jamie Winsor'
          email 'jamie@vialstudios.com'
        }
      }

      its(:name) { should eql('reset') }
      its(:version) { subject.to_s.should eql('1.2.3') }
      its(:description) { should eql('a good plugin') }
      its(:author) { should eql('Jamie Winsor') }
      its(:email) { should eql('jamie@vialstudios.com') }

      context "when the string contains an invalid Plugin description" do
        let(:data) {
          proc {
            name 1
            version '1.2.3'
          }
        }

        it "raises an PluginLoadError error" do
          -> { plugin }.should raise_error(MB::PluginLoadError)
        end
      end
    end

    describe "::from_file" do
      subject(:plugin) {
        described_class.from_file(@context, file)
      }

      let(:file) {
        tmp_path.join("pvpnet-1.2.3.rb")
      }

      let(:data) {
        <<-EOH
          name 'reset'
          version '1.2.3'
          description 'a good plugin'
          author 'Jamie Winsor'
          email 'jamie@vialstudios.com'
        EOH
      }

      before(:each) do
        File.write(file, data)
      end

      it { should be_a MB::Plugin }

      context "when the file does not exist" do
        let(:badfile) do
          tmp_path.join("notexistant.file")
        end

        it "raises a PluginLoadError" do
          lambda {
            described_class.from_file(@context, badfile)
          }.should raise_error(MB::PluginLoadError)
        end
      end
    end
  end

  describe "DSL evaluate: cluster_bootstrap" do
    subject do
      MB::Plugin.new(@context) do
        cluster_bootstrap do
          # block
        end
      end
    end

    it "has a ClusterBootstrapper for the value of bootstrapper" do
      subject.bootstrapper.should be_a(MB::ClusterBootstrapper)
    end
  end
end
