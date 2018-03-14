namespace :import do
  task :hmcts, [:csv_path] => :environment do |_, args|
    Import::HmctsImporter.new(ENV["DRY_RUN"]).import(args[:csv_path])
  end

  task :schedule_hmcts, %i(csv_path publication_time skip take) => :environment do |_, args|
    Import::HmctsScheduler.new.schedule(
      args[:csv_path],
      Time.parse(args[:publication_time]),
      args[:skip].to_i,
      args[:take].to_i,
    )
  end
end
