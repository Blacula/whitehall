class AssetManagerAttachmentRedirectUrlUpdateWorker < WorkerBase
  sidekiq_options queue: 'asset_manager'

  def perform(attachment_data_id)
    # binding.pry
    attachment_data = AttachmentData.find_by(id: attachment_data_id)
    return unless attachment_data.present?
    redirect_url = nil
    binding.pry
    # def unpublishing?
    #   !publicly_visible? && unpublishing.present?
    # end
    #
    # attachment_data.attachments[0].id
    # Attachment.find(1)

    if attachment_data.unpublished? #&& !attachment_data.draft? && !attachment_data.published?
      redirect_url = attachment_data.unpublished_edition.unpublishing.document_url
    end
    enqueue_job(attachment_data, attachment_data.file, redirect_url)
    if attachment_data.pdf?
      enqueue_job(attachment_data, attachment_data.file.thumbnail, redirect_url)
    end
  end

private

  def enqueue_job(attachment_data, uploader, redirect_url)
    legacy_url_path = uploader.asset_manager_path
    AssetManagerUpdateAssetWorker.new.perform(attachment_data, legacy_url_path, 'redirect_url' => redirect_url)
  end

  # if it's a draft and its previous edition was unpublished
end
