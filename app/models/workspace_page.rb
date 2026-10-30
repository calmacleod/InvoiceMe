class WorkspacePage
  PER_PAGE = 25
  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze
  attr_reader :records

  def initialize(scope, page, per_page = nil)
    @per_page = PER_PAGE_OPTIONS.find { |size| size.to_s == per_page.to_s } || PER_PAGE
    @total = scope.count
    @pages = [ (@total.to_f / @per_page).ceil, 1 ].max
    @page = page.to_i.clamp(1, @pages)
    @records = scope.limit(@per_page).offset((@page - 1) * @per_page)
  end

  def props
    { page: @page, pages: @pages, total: @total, from: @total.zero? ? 0 : (@page - 1) * @per_page + 1, to: [ @page * @per_page, @total ].min, per_page: @per_page, per_page_options: PER_PAGE_OPTIONS }
  end
end
