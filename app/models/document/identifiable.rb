module Document::Identifiable
  extend ActiveSupport::Concern
  extend Forwardable

  included do
    belongs_to :document_identity
    validates :document_identity, presence: true
    before_validation :set_document_identity, on: :create
    before_validation :update_document_identity_slug, on: :update
    before_validation :set_document_type_on_document_identity
  end

  def_delegators :document_identity, :slug, :editions_ever_published
  def_delegator :document_identity, :published?, :linkable?

  def set_document_identity
    self.document_identity ||= DocumentIdentity.new(sluggable_string: self.sluggable_title)
  end

  def update_document_identity_slug
    self.document_identity.update_slug_if_possible(self.sluggable_title)
  end

  def set_document_type_on_document_identity
    self.document_identity.set_document_type(type) if document_identity.present?
  end

  module ClassMethods
    def published_as(id)
      begin
        identity = DocumentIdentity.where(document_type: sti_name).find(id)
        identity && identity.published_document
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
