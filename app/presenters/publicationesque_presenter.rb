class PublicationesquePresenter < Whitehall::Decorators::Decorator
  include EditionPresenterHelper

  delegate_instance_methods_of(*Publicationesque.concrete_descendants)

  def as_hash
    super.merge(publication_collections: publication_collections)
  end

  def publication_collections
    if model.part_of_published_collection?
      links = model.published_document_collections.map do |dc|
        context.link_to(dc.title, context.public_document_path(dc))
      end
      "Part of a collection: #{links.to_sentence}"
    end
  end

  def time_until_closure
    days_left = (model.closing_at.to_date - Time.zone.now.to_date).to_i
    case days_left
    when :negative?.to_proc
      "Closed"
    when :zero?.to_proc
      "Closing today"
    when 1
      "Closes tomorrow"
    else
      "#{days_left} days left"
    end
  end
end
