# frozen_string_literal: true

# Credentials for minting DOIs via DataCite
# To disable this feature, simply set 'active' to false
Rails.configuration.x.datacite.landing_page_url = "https://doi.org/"
Rails.configuration.x.datacite.api_base_url = "https://api.test.datacite.org/"
Rails.configuration.x.datacite.mint_path = "dois"
Rails.configuration.x.datacite.delete_path = "dois/"
# TODO: Move the :repository_id, :password and :shoulder to the credentials.yml.enc in Rails5
Rails.configuration.x.datacite.repository_id = "[your repository_id/client_id]"
Rails.configuration.x.datacite.password = "[your password/client_secret]"
Rails.configuration.x.datacite.shoulder = "[your prefix/shoulder]" # e.g. 10.9999
Rails.configuration.x.datacite.active = true
