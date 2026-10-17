# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# An address is personal data (see Place::Nominatim).
Rails.application.config.filter_parameters += %i[
  address
  passw
  email
  secret
  token
  code
  verifier
  _key
  crypt
  salt
  certificate
  otp
  ssn
  cvv
  cvc
]
