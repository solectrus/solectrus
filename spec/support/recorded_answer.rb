# The recorded answer in `spec/support/cassettes/version.yml` is addressed to
# the installation it was recorded on, so an example that plays it back has to
# run as that installation. Tag it with `:recorded_answer`.
#
# Re-record with `VCR=all`, then read the new setup id out of the cassette and
# write it here. The cassette header says what else a recording needs.
RECORDED_SETUP_ID = 1_789_377_420

RSpec.configure do |config|
  config.before(:each, :recorded_answer) { Setting.setup_id = RECORDED_SETUP_ID }
end
