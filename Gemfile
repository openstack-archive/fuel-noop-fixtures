source 'https://rubygems.org'

group :development, :test do
  gem 'puppetlabs_spec_helper'
  gem 'puppet-lint', '~> 0.3.2'
  gem 'rspec-puppet', '~> 2.2.0'
  gem 'rspec-puppet-utils', '~> 2.0.0'
  gem 'openstack'
  gem 'netaddr'
  gem 'deep_merge'
  gem 'pry'
  gem 'simplecov'
  gem 'puppet-spec'
  gem 'colorize'
  gem 'parallel'
end

if ENV['PUPPET_GEM_VERSION']
  gem 'puppet', ENV['PUPPET_GEM_VERSION']
else
  gem 'puppet', '~> 3.8.0'
end

# vim:ft=ruby
