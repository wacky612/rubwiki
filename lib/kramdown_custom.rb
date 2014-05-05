# -*- coding: utf-8 -*-
require 'kramdown'

class Kramdown::Converter::HtmlCustom < Kramdown::Converter::Html
  def convert_a(el, indent)
    res = inner(el, indent)
    attr = el.attr.dup
    if attr['href'].empty?
      attr['href'] = @options[:wiki].search_file(res)
    end
    if attr['href'].start_with?('/')
      attr['href'] = @options[:baseurl] + attr['href']
    end
    format_as_span_html(el.type, attr, res)
  end

  def convert_td(el, indent)
    res = inner(el, indent)
    type = (@stack[-2].type == :thead ? :th : :td)
    attr = el.attr
    alignment = @stack[-3].options[:alignment][@stack.last.children.index(el)]
    if alignment != :default
      attr = el.attr.dup
      attr['class'] = (attr.has_key?('style') ? "#{attr['style']}; ": '') << "#{alignment}"
    end
    format_as_block_html(type, attr, res.empty? ? entity_to_str(ENTITY_NBSP) : res, indent)
  end
end
