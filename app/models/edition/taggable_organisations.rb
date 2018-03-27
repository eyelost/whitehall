module Edition::TaggableOrganisations
  extend ActiveSupport::Concern

  def taggable_options
    TaggableOptions.get_for(self)
  end

  def organisations_content_ids
    @_org_ids ||= Organisation.where(id: organisation_ids).map(&:content_id)
  end

  def document_type
    self.class.name
  end

  def publication_type
    PublicationTypes.find_by_id(publication_type_id)
  end

  TaggableOptions = Struct.new(:can_edit_new_taxonomy, :can_edit_old_taxonomy,
                               :autofill_new_taxonomy, :autofill_old_taxonomy,
                               :must_have_a_new_taxon) do
    def self.defaults
      TaggableOptions.new(can_edit_new_taxonomy: false, can_edit_old_taxonomy: true,
                          autofill_new_taxonomy: false, autofill_old_taxonomy: false,
                          must_have_a_new_taxon: false)
    end

    def self.get_for(model)
      groups = groups.reject { |group| filter_organisations(group, model) }
                     .reject { |group| filter_document_types(group, model) }
                     .reject { |group| filter_publication_types(group, model) }
                     .map { |group| TaggableOptions.new(group) }

      groups << TaggableOptions.defaults if groups.count < model.organisation_content_ids.count
      groups.inject(&:merge)
    end

    def merge(result, options)
      result.can_edit_new_taxonomy |= options.can_edit_new_taxonomy
      result.can_edit_old_taxonomy |= options.can_edit_old_taxonomy
      result.autofill_new_taxonomy &= options.autofill_new_taxonomy
      result.autofill_old_taxonomy &= options.autofill_old_taxonomy
      result.must_have_a_new_taxon &= options.must_have_a_new_taxon
      result
    end

  private

    def filter_organisations(group, model)
      (group[:organisation_ids] & model.organisation_content_ids).any?
    end

    def filter_document_types(group, model)
      return false if group[:document_types].nil?
      group[:document_types].include?(model.document_type)
    end

    def filter_publication_types(group, model)
      return false if group[:publication_types].nil?
      group[:publication_types].include?(model.publication_type)
    end

    def groups
      Whitehall.organisation_tagging_groups
    end
  end
end
