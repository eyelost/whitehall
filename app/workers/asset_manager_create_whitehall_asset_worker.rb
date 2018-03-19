class AssetManagerCreateWhitehallAssetWorker < WorkerBase
  include AssetManagerWorkerHelper

  def perform(file_path, legacy_url_path, draft = false, attachable_class = nil, attachable_id = nil)
    file = File.open(file_path)
    asset_options = { file: file, legacy_url_path: legacy_url_path }
    asset_options[:draft] = true if draft

    if attachable_class && attachable_id
      attachable = attachable_class.constantize.find(attachable_id)
      if attachable.respond_to?(:authorized_uuids)
        asset_options[:access_limited] = attachable.authorized_uuids || []
      end
    end

    asset_manager.create_whitehall_asset(asset_options)
    FileUtils.rm(file)
    FileUtils.rmdir(File.dirname(file))
  end
end
