class PrivateBreakdownPersistence
  def self.save!(user:, invoice:, data:)
    items = invoice.line_items.reject(&:marked_for_destruction?)
    Array(data["line_items_attributes"]).each_with_index do |attrs, index|
      next unless attrs.key?("private_breakdown") && !ActiveModel::Type::Boolean.new.cast(attrs["_destroy"])
      item = attrs["id"].present? ? items.find { |line| line.id.to_s == attrs["id"].to_s } : items.find { |line| line.position.to_s == attrs.fetch("position", index).to_s }
      raise ActiveRecord::RecordNotFound unless item
      user.line_item_private_breakdowns.find_or_initialize_by(line_item: item).update!(data: attrs["private_breakdown"])
    end
  end
end
