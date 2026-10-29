module WorkspaceProps
  private

  def invoice_props(invoice, detail: false)
    props = invoice.as_json(only: %i[id number recipient description issued_on due_on finalized_at])
    props.merge!(status: invoice.status, total_cents: invoice.total_cents, received_cents: invoice.received_cents, owed_cents: invoice.owed_cents)
    return props unless detail

    props.merge!(invoice.as_json(only: %i[contact recipient_address public_notes private_notes publish_error google_doc_id google_pdf_id ledger_row]))
    props.merge!(
      issuer: invoice.issuer, year: invoice.season.year,
      line_items: invoice.line_items.map { |item| item.as_json(only: %i[id description position quantity rate_cents]).merge(rate: item.rate, total_cents: item.total_cents) },
      game_ids: invoice.game_ids, games: invoice.games.map { |game| game_props(game) },
      payments: invoice.payments.as_json(only: %i[id amount_cents received_on method notes])
    )
  end

  def game_props(game, detail: false)
    props = game.as_json(only: %i[id external_id code date time home_team away_team location fees_cents])
    props.merge!(matchup: game.matchup, official_count: game.officials.size, invoices: game.invoices.as_json(only: %i[id number]))
    props.merge!(officials: game.officials, source: game.source) if detail
    props
  end
end
