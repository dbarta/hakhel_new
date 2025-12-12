class Jumpstart::OverrideGenerator < Rails::Generators::NamedBase
  source_root Jumpstart::Engine.root

  argument :paths, type: :array, banner: "path path"

  def self.usage_path = File.expand_path("USAGE", __dir__)

  def copy_paths
    paths.each do |path|
      directory?(path) ? directory(path) : copy_file(path)
    end
  end

  private

  def directory?(path)
    Dir.exist? find_in_source_paths(path)
  end

end
