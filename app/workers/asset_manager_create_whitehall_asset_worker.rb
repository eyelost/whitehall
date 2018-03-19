class AssetManagerCreateWhitehallAssetWorker < WorkerBase
  include AssetManagerWorkerHelper

  def perform(file_path, legacy_url_path, draft = false, model_class = nil, model_id = nil)
    file = File.open(file_path)
    asset_options = { file: file, legacy_url_path: legacy_url_path }
    asset_options[:draft] = true if draft

    if model_class && model_id
      model = model_class.constantize.find(model_id)
      if model.respond_to?(:authorized_uuids)
        asset_options[:access_limited] = model.authorized_uuids || []
      end
    end

    asset_manager.create_whitehall_asset(asset_options)
    FileUtils.rm(file)
    FileUtils.rmdir(File.dirname(file))
  end
end
