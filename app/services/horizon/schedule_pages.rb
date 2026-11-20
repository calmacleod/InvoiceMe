module Horizon
  class SchedulePages
    MAX_PAGES = 10

    def self.fetch(schedule, **filters)
      results = []
      total_pages = nil
      page = 1
      loop do
        response = schedule.list(**filters, page: page)
        current = Integer(response.fetch("current_page"))
        total = Integer(response.fetch("total_pages"))
        valid_page = current == page || (page == 1 && current.zero? && total.zero?)
        if !valid_page || total.negative? || (total_pages && total != total_pages)
          raise Client::ResponseError, "Horizon returned inconsistent schedule pagination."
        end
        raise Client::ResponseError, "Horizon returned more than #{MAX_PAGES} schedule pages." if total > MAX_PAGES
        events = response.fetch("result")
        unless events.is_a?(Array) && events.all?(Hash)
          raise Client::ResponseError, "Horizon returned an invalid schedule page."
        end
        if (total.zero? && events.any?) || (total > 1 && events.empty?) || (response.key?("result_count") && Integer(response["result_count"]) != events.size)
          raise Client::ResponseError, "Horizon returned an incomplete schedule page."
        end
        total_pages = total
        results.concat(events)
        yield page, total if block_given?
        return results if page >= total
        page += 1
      end
    rescue KeyError, TypeError, ArgumentError
      raise Client::ResponseError, "Horizon returned an incomplete schedule response."
    end
  end
end
