# frozen_string_literal: true

# Simple proxy service that determines which DOI minter to use
class DoiService

  class << self

    def mint_doi(plan:)
      return nil unless plan.present? && plan.is_a?(Plan)

      svc = minter
      doi = svc.mint_doi(plan: plan)
      return nil unless doi.present?

      doi = "#{svc.landing_page_url}#{doi}" unless doi.downcase.start_with?("http")

      Identifier.new(identifier_scheme: scheme(svc: svc),
                     identifiable: plan, value: doi)
    end

    def scheme_name
      svc = minter
      return nil unless svc.present?

      scheme(svc: svc)&.name&.downcase
    end

    private

    def minter
      # Use the DMPHub if it has been activated
      ExternalApis::DmphubService if ExternalApis::DmphubService.active?
      # Place additional DOI services here
    end

    def scheme(svc:)
      # Add the DOI service as an IdentifierScheme if it doesn't already exist
      scheme = IdentifierScheme.find_or_create_by(name: svc.name)
      if scheme.new_record?
        scheme.update(description: svc.description, active: true,
                      for_identification: true, for_plans: true)
      end
      scheme
    end

  end

end
