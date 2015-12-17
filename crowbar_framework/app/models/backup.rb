#
# Copyright 2015, SUSE LINUX GmbH
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

require "find"

class Backup
  include ActiveModel::Model

  attr_accessor :name, :created_at, :filename, :path

  validates_presence_of :name, :created_at
  validates :created_at, exclusion: { in: [nil, ""] }
  validate :filename, :filename_has_format
  validate :filename, :filename_has_characters

  def initialize(options)
    @name = options.fetch :name, nil
    @created_at = options.fetch :created_at, Time.zone.now.strftime("%Y%m%d-%H%M%S")
    @filename = "#{@name}-#{@created_at}.tar.gz"
    @path = Backup.image_dir.join(@filename)
  end

  def as_json(options: {})
    result = super
    result["path"] = path.to_s
    result
  end

  def save
    valid? && persist!
  end

  def exist?
    !Backup.where(name: name, created_at: created_at).nil?
  end

  def delete
    @path.delete
  end

  def size
    path.size if path.file?
  end

  class << self
    def where(options = {})
      name = options.fetch :name, nil
      created_at = options.fetch :created_at, nil
      ret = nil

      all.each do |image|
        ret = image if image.name == name && image.created_at == created_at
      end
      ret
    end

    def all
      list = []

      backup_files = image_dir.children.select do |c|
        c.file? && c.to_s =~ /gz$/
      end

      backup_files.each do |backup_file|
        name, created_at = filename_time(backup_file.basename.to_s)
        image = new(
          name: name,
          created_at: created_at
        )
        list.push(image) if image.valid?
      end
      list.sort_by(&:created_at)
    end

    def image_dir
      if Rails.env.production?
        Pathname.new("/var/lib/crowbar/backup")
      else
        Rails.root.join("storage")
      end
    end

    def filename_time(filename)
      filename.split(/([\w-]+)-([0-9]{8}-[0-9]{6})/).reject(&:empty?)
    end
  end

  protected

  def persist!
    self.exist? ? false : create
  end

  def create
    saved = false
    dir = Dir.mktmpdir

    Crowbar::Backup::Export.new(dir).export
    Dir.chdir(dir) do
      ar = Archive::Compress.new(
        "#{Backup.image_dir}/#{name}-#{created_at}.tar.gz",
        type: :tar,
        compression: :gzip2
      )
      ar.compress(Find.find(".").select { |f| f.gsub!(/^.\//, "") if File.file?(f) })
      saved = true
    end
    FileUtils.rm_rf(dir)
    saved
  end

  def filename_has_format
    return if Backup.filename_time(@filename).count == 3
    errors.add(
      :filename,
      I18n.t(".invalid_filename_format", scope: "backup.index")
    )
  end

  def filename_has_characters
    return if @filename =~ /[^0-9A-Za-z]/
    errors.add(
      :filename,
      I18n.t(".invalid_filename", scope: "backup.index")
    )
  end
end
