require 'spec_helper'

describe MB::Bootstrap::Routine do
  let(:plugin) do
    metadata = MB::CookbookMetadata.new do
      name "motherbrain"
      version "0.1.0"
    end

    MB::Plugin.new(metadata)
  end

  let(:activemq) { MB::Component.new('activemq', plugin) }
  let(:mysql) { MB::Component.new('mysql', plugin) }
  let(:nginx) { MB::Component.new('nginx', plugin) }

  let(:amq_master) { MB::Group.new('master') }
  let(:amq_slave) { MB::Group.new('slave') }
  let(:mysql_master) { MB::Group.new('master') }
  let(:mysql_slave) { MB::Group.new('slave') }
  let(:nginx_master) { MB::Group.new('master') }

  before(:each) do
    plugin.stub(:components).and_return([activemq, mysql, nginx])
    activemq.stub(:groups).and_return([amq_master, amq_slave])
    mysql.stub(:groups).and_return([mysql_master, mysql_slave])
    nginx.stub(:groups).and_return([nginx_master])
  end

  describe "DSL evaluation" do
    subject do
      described_class.new(plugin) do
        async do
          bootstrap("activemq::master")
          bootstrap("activemq::slave")
        end

        async do
          bootstrap("mysql::master")
          bootstrap("mysql::slave")
        end

        bootstrap("nginx::master")
      end
    end

    it "has an entry for each bootstrap or async function call" do
      subject.task_queue.should have(3).items
    end

    context "each entry" do
      it "is in FIFO order" do
        subject.task_queue[0].should be_a(Array)
        subject.task_queue[0][0].group_object.should eql(amq_master)
        subject.task_queue[0][0].groups.should eql(["activemq::master"])
        subject.task_queue[0][1].group_object.should eql(amq_slave)
        subject.task_queue[0][1].groups.should eql(["activemq::slave"])
        subject.task_queue[1].should be_a(Array)
        subject.task_queue[1][0].group_object.should eql(mysql_master)
        subject.task_queue[1][0].groups.should eql(["mysql::master"])
        subject.task_queue[1][1].group_object.should eql(mysql_slave)
        subject.task_queue[1][1].groups.should eql(["mysql::slave"])
        subject.task_queue[2].group_object.should eql(nginx_master)
        subject.task_queue[2].groups.should eql(["nginx::master"])
      end
    end
  end

  let(:manifest) {
    {
      nodes: [
        {
          groups: ["activemq::master"],
          hosts: ["amq1.riotgames.com", "amq2.riotgames.com"]
        },
        {
          groups: ["activemq::slave"],
          hosts: ["amqs1.riotgames.com", "amqs2.riotgames.com"]
        },
        {
          groups: ["nginx::master"],
          hosts: ["nginx1.riotgames.com"]
        }
      ]
    }
  }

  subject { described_class.new(plugin) }

  describe "#task_queue" do
    it "returns an array" do
      subject.task_queue.should be_a(Array)
    end

    context "given a routine with async tasks" do
      subject do
        described_class.new(plugin) do
          async do
            bootstrap("activemq::master")
            bootstrap("activemq::slave")
          end
        end
      end

      it "returns an array of arrays of boot tasks" do
        subject.task_queue.should have(1).item
        subject.task_queue[0].should have(2).items
        subject.task_queue[0].should each be_a(MB::Bootstrap::BootTask)
      end
    end

    context "given a routine with syncronous tasks" do
      subject do
        described_class.new(plugin) do
          bootstrap("activemq::master")
          bootstrap("activemq::slave")
        end
      end

      it "returns an array of boot tasks" do
        subject.task_queue.should have(2).items
        subject.task_queue.should each be_a(MB::Bootstrap::BootTask)
      end
    end
  end

  describe "#has_task?" do
    subject do
      described_class.new(plugin) do
        bootstrap("activemq::master")
      end
    end

    it "returns a BootTask if a task with a matching ID is present" do
      subject.has_task?("activemq::master").should be_true
    end

    it "returns nil if a task with a matching ID is not present" do
      subject.has_task?("not::defined").should be_false
    end

    context "given a routine with async tasks" do
      subject do
        described_class.new(plugin) do
          async do
            bootstrap("activemq::master")
            bootstrap("activemq::slave")
          end
          bootstrap("nginx::master")
        end
      end

      it "has the nested async tasks and the top level tasks" do
        subject.should have_task("activemq::master")
        subject.should have_task("activemq::slave")
        subject.should have_task("nginx::master")
      end
    end
  end
end
