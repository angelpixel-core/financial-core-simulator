puts 'Legacy db:seed invoked. Prefer the canonical admin seed entry point.'
puts 'Canonical: BUNDLE_GEMFILE=apps/admin/Gemfile bundle exec rails runner apps/admin/script/seed_admin.rb --type dashboard'

ARGV.replace(['--type', 'dashboard'])
load Rails.root.join('script', 'seed_admin.rb')
