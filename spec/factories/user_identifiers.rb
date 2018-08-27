# == Schema Information
#
# Table name: user_identifiers
#
#  id                   :integer          not null, primary key
#  identifier           :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  identifier_scheme_id :integer
#  user_id              :integer
#
# Indexes
#
#  fk_rails_fe95df7db0                (identifier_scheme_id)
#  index_user_identifiers_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (identifier_scheme_id => identifier_schemes.id)
#  fk_rails_...  (user_id => users.id)
#

FactoryBot.define do
  factory :user_identifier do
    identifier { SecureRandom.hex }
    user
    identifier_scheme
  end
end
