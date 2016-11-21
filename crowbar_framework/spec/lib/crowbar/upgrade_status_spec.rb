#
# Copyright 2016, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"

describe Crowbar::UpgradeStatus do
  before do
    @state_file = Tempfile.open("upgrade_status_spec.state.yml", &:path)
    File.unlink @state_file
  end

  subject { Crowbar::UpgradeStatus.new(Rails.logger, @state_file) }

  def new_status
    subject.class.new(Rails.logger, @state_file)
  end

  after do
    File.unlink @state_file if File.exist? @state_file
  end

  context "with a status file that does not exist" do
    it "ensures the default initial values are correct" do
      expect(subject.current_substep).to be_nil
      expect(subject.finished?).to be false
    end

    it "ensures that the defaults are saved" do
      expect(subject.progress_file_path.exist?).to be true
    end

    it "returns first step as current step" do
      expect(subject.current_step).to eql :upgrade_prechecks
    end

    it "determines whether current step is pending" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.pending?).to be true
      expect(subject.start_step).to be true
      expect(subject.pending?).to be false
    end

    it "determines whether given step is pending" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.pending?).to be true
      expect(subject.pending?(:upgrade_prechecks)).to be true
      expect(subject.pending?(:admin_backup)).to be true
      expect(subject.start_step).to be true
      expect(subject.pending?).to be false
      expect(subject.pending?(:upgrade_prechecks)).to be false
      expect(subject.pending?(:admin_backup)).to be true
    end

    it "determines whether current step is running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.running?).to be false
      expect(subject.running?(:upgrade_prechecks)).to be false
      expect(subject.start_step).to be true
      expect(subject.running?).to be true
      expect(subject.running?(:upgrade_prechecks)).to be true
    end

    it "determines whether current step is running from another object" do
      expect(subject.current_step).to eql :upgrade_prechecks
      other_status = new_status
      expect(other_status.running?).to be false
      expect(subject.start_step).to be true
      other_status.load
      expect(other_status.running?).to be true
    end

    it "determines whether a given step is running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.running?(:upgrade_prepare)).to be false
      expect(subject.start_step).to be true
      expect(subject.running?(:upgrade_prepare)).to be false
    end

    it "determines whether current step is running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.current_step_state[:status]).to eql :pending
      expect(subject.running?).to be false
      expect(subject.start_step).to be true
      expect(subject.running?).to be true
      expect(subject.running?(:upgrade_prepare)).to be false
    end

    it "moves to next step when requested" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.current_step_state[:status]).to eql :pending
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :upgrade_prepare
    end

    it "does not move to next step when current one failed" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.start_step).to be true
      expect(subject.end_step(false, failure: "error message")).to be false
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.current_step_state[:status]).to eql :failed
      expect(subject.current_step_state[:errors]).to_not be_empty
    end

    it "does not allow to end step when it is not running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :upgrade_prepare
      expect(subject.end_step).to be false
    end

    it "does not allow to end step when it was started by another object" do
      pending("need some way to track step ownership")
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.start_step).to be true
      other_status = new_status
      expect(other_status.end_step).to be false
      expect(subject.running?).to be true
    end

    it "does not to stop the first step without starting it" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.end_step).to be false
    end

    it "prevents starting a step while it is already running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      expect(subject.start_step).to be true
      expect(subject.current_step_state[:status]).to eql :running
      expect(subject.start_step).to be false
      expect(subject.current_step_state[:status]).to eql :running
      expect(subject.current_step).to eql :upgrade_prechecks
    end

    it "prevents starting a step from a separate object while it is already running" do
      expect(subject.current_step).to eql :upgrade_prechecks
      other_status = new_status
      expect(subject.start_step).to be true
      expect(subject.current_step_state[:status]).to eql :running
      other_status.load
      expect(other_status.start_step).to be false
    end

    it "goes through the steps and returns finish when finished" do
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :upgrade_prepare
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :admin_backup
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :admin_repo_checks
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :admin_upgrade
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :database
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :nodes_repo_checks
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :nodes_services
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :nodes_db_dump
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :nodes_upgrade
      expect(subject.start_step).to be true
      expect(subject.end_step).to be true
      expect(subject.current_step).to eql :finished
      expect(subject.finished?).to be true
      expect(subject.end_step).to be false
    end
  end
end