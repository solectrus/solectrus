# Who wrote an entry last: the admin in the form, or an AI client over MCP.
# The entry of an AI client stays marked until the admin saves it, so the
# admin can check it.
module Origin
  extend ActiveSupport::Concern

  included do
    enum :origin, { user: 'user', mcp: 'mcp' }, prefix: true
  end
end
