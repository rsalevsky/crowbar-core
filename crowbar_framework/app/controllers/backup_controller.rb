#
# Copyright 2015, SUSE LINUX Products GmbH
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

require "crowbar/backup/restore"

class BackupController < ApplicationController
  before_action :backup_params, only: [:commit]

  def index
  end

  def commit
    backup_io = params[:backup][:backup]
    backup_path = Rails.root.join("storage", "backups", "#{Time.now.to_i}-#{backup_io.original_filename}")

    File.open(backup_path, "wb") do |file|
      file.write(backup_io.read)
    end

    backup = Crowbar::Backup::Restore.new(backup_path)
    backup.valid?

    backup.upgrade if backup.upgrade?

    backup.restore
    backup.cleanup
  end

  private

  def backup_params
    params.require(:backup).permit(:backup)
  end
end
