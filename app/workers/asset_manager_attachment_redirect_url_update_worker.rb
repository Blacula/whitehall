class AssetManagerAttachmentRedirectUrlUpdateWorker < WorkerBase
  sidekiq_options queue: 'asset_manager'

  def perform(attachment_data_id)
    attachment_data = AttachmentData.find_by(id: attachment_data_id)
    return if redirect_not_needed?(attachment_data)
    redirect_url = nil
    if attachment_data.unpublished?
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

  def redirect_not_needed?(attachment_data)
    attachment_data.blank? || attachment_data.draft?
  end
end
