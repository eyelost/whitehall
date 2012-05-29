class PublicationsController < DocumentsController
  before_filter :load_policy_topics, only: [:index, :by_policy_topic]

  def index
    @all_publications = all_publications
    @featured_publication = @all_publications.select(&:featured).first
  end

  def show
    @related_policies = @document.published_related_policies
    @policy_topics = @related_policies.map { |d| d.policy_topics }.flatten.uniq
  end

  def by_policy_topic
    @all_publications = all_publications.in_policy_topic(@selected_policy_topics)
    @featured_publications = []
    render :index
  end

  private

  def load_policy_topics
    @all_policy_topics = PolicyTopic.order(:name)
    @top_policy_topics = @all_policy_topics.exemplars
    @selected_policy_topics = PolicyTopic.where(slug: (params[:policy_topics] || "").split("+")).all
  end

  def all_publications
    Publication.published_in_reverse_chronological_order.includes(:doc_identity, :organisations, :attachments)
  end

  def document_class
    Publication
  end
end
