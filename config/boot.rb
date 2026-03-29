ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load .env file for local development (dotenv is bundled via kamal).
# Overmind does this automatically for `bin/dev`, but rails runner / rspec need it too.
require "dotenv"
Dotenv.load(File.expand_path("../../.env", __FILE__))
