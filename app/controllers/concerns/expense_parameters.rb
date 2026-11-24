module ExpenseParameters
  private

  def expense_params
    input = params.require(:expense)
    raise ArgumentError, "expense must be an object" unless input.is_a?(ActionController::Parameters)
    if input.key?(:paid) && ![ true, false ].include?(input[:paid])
      raise ArgumentError, "paid must be a JSON boolean"
    end
    if input.key?(:line_items) && (!input[:line_items].is_a?(Array) || input[:line_items].any? { |item| !item.is_a?(ActionController::Parameters) })
      raise ArgumentError, "line_items must be an array of objects"
    end
    input.permit(:payee, :description, :category, :incurred_on, :total_cents, :paid, :paid_on, :payment_method, :cheque_number, :reference, :notes, :lock_version,
      line_items: %i[id description category amount_cents])
  end

  def expense_filters
    params.permit(:query, :category, :status).to_h.symbolize_keys
  end
end
