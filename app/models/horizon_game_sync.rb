class HorizonGameSync < ApplicationRecord
  belongs_to :season
  belongs_to :user
  belongs_to :horizon_connection

  def apply!
    with_lock do
      raise ArgumentError, "This review has expired or was already applied. Start a new sync." unless status == "ready" && completed_at && completed_at > 2.hours.ago
      Game.transaction do
        games.each do |item|
          attributes = item.fetch("attributes")
          record = season.games.find_by(external_id: attributes.fetch("external_id"))
          expected = item["existing_updated_at"]
          if expected ? record.nil? || record.updated_at.iso8601(6) != expected : record.present?
            raise ArgumentError, "A game changed after this review was prepared. Start a new sync."
          end
          record ||= season.games.new(external_id: attributes.fetch("external_id"))
          record.assign_attributes(attributes.except("external_id"))
          # Keep imported source rows, including Paid By Team, and all invoice links.
          record.source = [ { "Source" => "Horizon API", "Paid By Team" => nil } ] if record.new_record?
          record.save! if record.new_record? || record.has_changes_to_save?
        end
        update!(status: "applied", games: [], completed_at: Time.current)
      end
    end
  end
end
