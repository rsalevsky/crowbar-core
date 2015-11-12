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

module Crowbar
  module Upgrade
    class Base
      attr_accessor :path

      def initialize(from, to)

      end

      def files(path)
        self.path = path
        crowbar_files
        knife_files
      end

      private

      def crowbar_files
        true
      end

      def knife_files
        FileUtils.rm_rf(File.join(self.path, "knife", "data_bags", "barclamps"))

        crowbar_databags_path = File.join(self.path, "knife", "data_bags", "crowbar")
        Dir.entries(crowbar_databags_path).each do |file|

          if file == "bc-template-nova_dashboard.json"
            File.rename(File.join(crowbar_databags_path, file), File.join(crowbar_databags_path, file.sub!("nova_dashboard", "horizon")))

            file_content = File.read(File.join(crowbar_databags_path, file))
            file_content.gsub!("nova_dashboard", "horizon")
            File.open(File.join(crowbar_databags_path, file), "w") {|file| file.puts file_content }
          end

          if file.match("bc-.*.json")
            new_file = file.gsub("bc-", "")
            File.rename(File.join(crowbar_databags_path, file), File.join(crowbar_databags_path, new_file))

            file_content = File.read(File.join(crowbar_databags_path, new_file))
            file_content.gsub!("bc-", "")
            File.open(File.join(crowbar_databags_path, new_file), "w") {|file| file.puts file_content }
          end
        end
      end
    end
  end
end
