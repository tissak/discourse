require_dependency 'screening_model'

# A ScreenedIpAddress record represents an IP address or subnet that is being watched,
# and possibly blocked from creating accounts.
class ScreenedIpAddress < ActiveRecord::Base

  include ScreeningModel

  default_action :block

  validates :ip_address, ip_address_format: true, presence: true

  def self.watch(ip_address, opts={})
    match_for_ip_address(ip_address) || create(opts.slice(:action_type).merge(ip_address: ip_address))
  end

  # @Neil please review, in rails 4 when setting an ip address attribute a conversion takes place
  #  this may explode meaning you will never even reach the validator
  # We can work around the issue like so, but I wonder if the spec is valid
  def ip_address=(val)
    write_attribute(:ip_address, val)
  rescue IPAddr::InvalidAddressError
    self.errors.add(:ip_address, :invalid)
  end

  def self.match_for_ip_address(ip_address)
    # The <<= operator on inet columns means "is contained within or equal to".
    #
    # Read more about PostgreSQL's inet data type here:
    #
    #   http://www.postgresql.org/docs/9.1/static/datatype-net-types.html
    #   http://www.postgresql.org/docs/9.1/static/functions-net.html
    where("'#{ip_address.to_s}' <<= ip_address").first
  end

  def self.should_block?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:block])
  end

  def self.is_whitelisted?(ip_address)
    exists_for_ip_address_and_action?(ip_address, actions[:do_nothing])
  end

  def self.exists_for_ip_address_and_action?(ip_address, action_type)
    b = match_for_ip_address(ip_address)
    b.record_match! if b
    !!b and b.action_type == action_type
  end
end
