# Lets request specs look into the rendered page with plain RSpec matchers.
module HtmlHelpers
  def page_html
    Nokogiri::HTML5(response.body)
  end

  def texts(selector)
    page_html.css(selector).map { |node| node.text.squish }
  end

  def page_lang
    page_html.at_css("html")["lang"]
  end
end
