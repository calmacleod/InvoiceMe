class WorkspacePage
  PER_PAGE = 25
  attr_reader :records

  def initialize(scope, page)
    @total = scope.count
    @pages = [ (@total.to_f / PER_PAGE).ceil, 1 ].max
    @page = page.to_i.clamp(1, @pages)
    @records = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def props
    { page: @page, pages: @pages, total: @total, from: @total.zero? ? 0 : (@page - 1) * PER_PAGE + 1, to: [ @page * PER_PAGE, @total ].min }
  end
end
