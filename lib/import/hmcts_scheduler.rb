module Import
  class HmctsScheduler
    def schedule(csv_path, publication_time, skip, take)
      CSV.read(csv_path, headers: true).drop(skip).take(take).each do |row|
        next unless row["publication whitehall ID"]

        publication_id = row["publication whitehall ID"]
        publication = Publication.find_by(id: publication_id)

        begin
          publication.scheduled_publication = publication_time

          Whitehall.edition_services.force_scheduler(publication).perform!

          puts "Scheduled #{publication_id} at #{publication_time}"
        rescue StandardError => error
          puts "Error scheduling #{publication_id}: #{error.message}"
        end
      end
    end
  end
end
