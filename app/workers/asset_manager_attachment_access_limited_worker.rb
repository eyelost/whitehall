class AssetManagerAttachmentAccessLimitedWorker < WorkerBase
  def perform(attachment_data_id)
    attachment_data = AttachmentData.find_by(id: attachment_data_id)
    return unless attachment_data.present?

    uuids = attachment_data.authorized_uuids || []

    enqueue_job(attachment_data.file, uuids)
    if attachment_data.pdf?
      enqueue_job(attachment_data.file.thumbnail, uuids)
    end
  end

private

  def enqueue_job(uploader, uuids)
    legacy_url_path = uploader.asset_manager_path
    AssetManagerUpdateAssetWorker.new.perform(legacy_url_path, 'access_limited' => uuids)
  end
end
