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

module CrowbarMigration
  require "rubygems/package"
  require "zlib"
  require "tmpdir"
  require "json"

  class << self
    def run(tar_gz, from, to)
      tmpdir = Dir.mktmpdir

      tar = Gem::Package::TarReader.new(Zlib::GzipReader.open tar_gz)

      tar.each do |entry|
        dest ||= File.join tmpdir, entry.full_name
        if entry.directory?
          FileUtils.rm_rf dest unless File.directory? dest
          FileUtils.mkdir_p dest, :mode => entry.header.mode
        elsif entry.file?
          FileUtils.rm_rf dest unless File.file? dest
          File.open dest, "wb" do |f|
            f.print entry.read
          end
          FileUtils.chmod entry.header.mode, dest
        elsif entry.header.typeflag == '2'
          File.symlink entry.header.linkname, dest
        end
      end

      five_to_six tmpdir
    end

    def five_to_six(tmpdir)
      Dir.entries(File.join(tmpdir, "data_bags", "crowbar")).each do |file|
        if file.match("bc-.*.json")
          file_content = File.read(File.join(tmpdir, "data_bags", "crowbar", file))
          bc_name = file.split("-")[1]
          if bc_name == "nova_dashboard"
            file = file.gsub("nova_dashboard", "horizon")
          end
          json = JSON.load(file_content)
          Proposal.create(barclamp: bc_name, name: "default", properties: json)
        end
      end
    end
  end
end
