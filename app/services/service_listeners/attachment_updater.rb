module ServiceListeners
  class AttachmentUpdater
    def self.call(attachable: nil, attachment_data: nil)
      binding.pry
      update_attachable! attachable if attachable
      update_attachment_data! attachment_data if attachment_data
    end

    private_class_method def self.update_attachable!(attachable)
      Attachment.where(attachable: attachable.attachables).find_each do |attachment|
        next unless attachment.attachment_data
        update_attachment_data! attachment.attachment_data
      end
    end

    private_class_method def self.update_attachment_data!(attachment_data)
      AssetManagerAttachmentDataWorker.perform_async(attachment_data.id)
    end
  end
end
