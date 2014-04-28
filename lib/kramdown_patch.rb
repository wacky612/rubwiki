class Kramdown::Converter::Html
  def convert_a_with_baseurl(el, indent)
    res = inner(el, indent)
    attr = el.attr.dup
    if attr['href'].empty?
      attr['href'] = RubWiki::App.wiki.search_file(res)
    end
    if attr['href'].start_with?('/')
      attr['href'] = RubWiki::App.baseurl[0...-1] + attr['href']
    end
    format_as_span_html(el.type, attr, res)
  end

  alias_method :convert_a_original, :convert_a
  alias_method :convert_a, :convert_a_with_baseurl
end
