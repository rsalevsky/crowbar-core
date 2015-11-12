#
# Copyright 2013-2015, SUSE LINUX Products GmbH
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

# ["crowbar/crowbar/config", "/var/lib/crowbar"],
# ["crowbar/crowbar/cache", "/var/lib/crowbar"],

module Crowbar
  module Backup

    class << self
      def filelist
        [
          ["etc/crowbar.install.key", "/etc/crowbar.install.key"],
          ["etc/crowbar.json", "/etc/crowbar/crowbar.json"],
          ["etc/hosts", "/etc/hosts"],
          ["etc/network.json", "/etc/crowbar/network.json"],
          ["etc/resolv.conf.forwarders", "/etc/resolv.conf"],
          ["crowbar/client.pem", "/opt/dell/crowbar_framework/config/client.pem"],
          ["root/.gnupg", "/root/.gnupg"],
          ["root/.ssh", "/root/.ssh"],
          ["tftp/validation.pem", "/srv/tftpboot/validation.pem"]
        ]
      end
    end

    class Restore
      attr_accessor :backup_path, :version, :mode

      def initialize(tgz, mode = "complete")
        prepare(tgz)
        self.version = backup_version
        self.mode = mode

        return false unless self.valid?
      end

      def upgrade
        upgrade = Crowbar::Upgrade::Base.new(self.version, ENV["CROWBAR_VERSION"])
        upgrade.files(self.backup_path)
      end

      def upgrade?
        current_version = ENV["CROWBAR_VERSION"]
        return true if current_version > self.version
        false
      end

      def restore
        #restore_crowbar
        # run install-chef-suse
        restore_knife
        restore_database
      end

      def valid?
        raise Crowbar::Error::BackupValidation unless self.version
        raise Crowbar::Error::BackupValidation unless json_file_extension

        true
      end

      def prepare(tgz)
        self.backup_path = Rails.root.join("storage", "backups", File.basename(tgz, ".tar.gz"))
        Dir.mkdir(self.backup_path)
        Archive.extract(tgz.to_s, self.backup_path.to_s)
      end

      def cleanup
        FileUtils.rm_rf(self.backup_path)
        self.backup_path = nil
      end

      private

      def backup_version
        version_file = File.join(@backup_path, "crowbar", "version")

        return false unless File.exist?(version_file)
        version = File.open(version_file, &:readline).match("[0-9]*\.[0-9]*").to_s

        return false if version.empty?

        version
      end

      def restore_knife
        core = core_barclamps

        self.backup_path.join("knife", "data_bags", "crowbar").children.each do |file|
          if file.basename.to_s.match(/\A\w+-\w+\.json\z/) && !file.basename.to_s.match(/\Atemplate-.*/)
            json = JSON.load(file.read)
            bc_name = file.basename.to_s.split("-").first
            if self.mode == "crowbar" && core.include?(bc_name)
              Proposal.create(barclamp: bc_name, name: "default", properties: json)
            elsif self.mode == "openstack" && !core.include?(bc_name)
              Proposal.create(barclamp: bc_name, name: "default", properties: json)
            elsif self.mode == "complete"
              Proposal.create(barclamp: bc_name, name: "default", properties: json)
            end
          end
        end

        [:nodes, :roles, :clients].each do |type|
          self.backup_path.join("knife", type.to_s).children.each do |file|
            record = JSON.load(file.read)
            record.save
          end
        end
      end

      def restore_crowbar
        Crowbar::Backup.filelist.each do |source, destionation|
          FileUtils.cp_r(self.backup_path.join("crowbar", source), destionation)
        end
      end

      def restore_database
        FileUtils.cp(
          self.backup_path.join("crowbar", "crowbar", "production.sqlite3"),
          Rails.root.join("db", "#{ENV["RAILS_ENV"]}.sqlite3")
        )
        ActiveRecord::Base.connection.reconnect!
        Crowbar::Migrate.migrate!
      end

      def json_file_extension
        Dir.glob(@backup_path.join("knife", "*", "**")).each do |file|
          unless Pathname.new(file).directory?
            return false unless File.extname(file) == ".json"
          end
        end
      end

      def core_barclamps
        barclamps = []
        Dir.glob("/opt/crowbar/barclamps/core/*.yml").each do |file|
          barclamps.push(File.basename(file, ".yml"))
        end
        barclamps
      end
    end
  end
end
