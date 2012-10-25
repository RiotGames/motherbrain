notification :off
interactor :coolline

guard 'yard', stdout: '/dev/null', stderr: '/dev/null' do
  watch(%r{app/.+\.rb})
  watch(%r{lib/.+\.rb})
  watch(%r{ext/.+\.c})
end

guard 'rspec', cli: "--color --drb --format Fuubar", all_on_start: false, all_after_pass: false do
  watch(%r{^spec/unit/.+_spec\.rb$})
  watch(%r{^spec/acceptance/.+_spec\.rb$})
  
  watch(%r{^lib/(.+)\.rb$})           { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch('lib/mb/config_validator.rb') { "spec/unit/mb/config_spec.rb" }
  watch('spec/spec_helper.rb')        { "spec" }
end

guard 'cucumber', cli: "--drb --require features --format pretty", all_on_start: false, all_after_pass: false do
  watch(%r{^features/.+\.feature$})
  watch(%r{^features/support/.+$})                      { 'features' }
  watch(%r{^features/step_definitions/(.+)_steps\.rb$}) { |m| Dir[File.join("**/#{m[1]}.feature")][0] || 'features' }

  watch(%r{^lib/mb/cli.rb})                             { 'features/core' }
end

# guard 'environment-factory',
#   name: 'mbtest',
#   pattern: 'ef_secondary',
#   api_keyfile: File.join(File.expand_path('..', __FILE__), 'features', 'support', 'ef.token'),
#   api_url: 'https://ef.riotgames.com',
#   override_attributes: {
#     environment_factory: {
#       artifact_version: "0.8.5"
#     }
#   },
#   cookbook_versions: Hash.new,
#   destroy_on_exit: true
