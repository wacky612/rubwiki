require 'haml'
require 'sanitize'
require_relative 'kramdown_custom'

module RubWiki
  class View
    def initialize(wiki, baseurl, settings)
      @wiki = wiki
      @baseurl = baseurl
      @settings = settings
    end

    def search(keyword, result)
      article = haml(:search, { result: result, keyword: keyword })
      return page(nav(), article)
    end

    def diff(diff, path, oid1, oid2)
      article = haml(:diff, { diff: diff, path: path, oid1: oid1, oid2: oid2 })
      return page(nav(), article)
    end

    def list(list, dir = "")
      article = haml(:list, { list: list, dir: dir })
      return page(nav(), article)
    end

    def history(commits, path)
      article = haml(:history, { commits: commits, path: path })
      return page(nav(), article)
    end

    def conflict(raw_data, path, oid)
      form = haml(:form, { raw_data: raw_data, oid: oid })
      article = haml(:conflict, { form: form, path: path })
      return page(nav(), article)
    end

    def preview(raw_data, oid, path)
      form = haml(:form, { raw_data: raw_data, oid: oid })
      preview = markdown(raw_data)
      article = haml(:preview, { form: form, preview: preview, path: path })
      return page(nav(), article)
    end

    def edit(raw_data, oid, path)
      form = haml(:form, { raw_data: raw_data, oid: oid })
      article = haml(:edit, { form: form, path: path })
      return page(nav(), article)
    end

    def view(raw_data, path)
      contents = markdown(raw_data)
      article = haml(:view, { contents: contents, path: path })
      return page(nav(path), article)
    end

    def revision(raw_data, path, oid)
      contents = markdown(raw_data)
      article = haml(:revision, { contents: contents, path: path, oid: oid })
      return page(nav(), article)
    end

    def invalid_path(path)
      article = haml(:invalid_path, { path: path })
      return page(nav(), article)
    end

    def cannot_create(path)
      article = haml(:cannot_create, { path: path })
      return page(nav(), article)
    end

    def invalid_revision(oid)
      article = haml(:invalid_revision, { oid: oid })
      return page(nav(), article)
    end

    def invalid_diff(oid1, oid2)
      article = haml(:invalid_diff, { oid1: oid1, oid2: oid2 })
      return page(nav(), article)
    end

    def cannot_edit(path)
      article = haml(:cannot_edit, { path: path })
      return page(nav(), article)
    end

    def exist_dir(path)
      article = haml(:exist_dir, { path: path })
      return page(nav(), article)
    end

    def not_exist(path)
      article = haml(:not_exist, { path: path })
      return page(nav(), article)
    end

    def empty_search
      article = haml(:empty_search)
      return page(nav(), article)
    end

    def not_exist_dir(path)
      article = haml(:not_exist_dir, { path: path })
      return page(nav(), article)
    end

    private

    def nav(path = nil)
      return haml(:nav, { path: path })
    end

    def page(nav, article)
      return haml(:page, { nav: nav, article: article })
    end

    def markdown(data)
      options = { wiki: @wiki, baseurl: @baseurl }
      html = Kramdown::Document.new(data, options).to_html_custom
      custom = Sanitize::Config::RELAXED
      custom[:attributes]["td"] << "class"
      custom[:attributes]["th"] << "class"
      return Sanitize.clean(html, custom)
    end

    def haml(template, locals = {})
      data = File.read(File.expand_path("#{File.dirname(__FILE__)}/../views/#{template.to_s}.haml"))
      locals[:settings] = @settings
      locals[:baseurl] = @baseurl
      return Haml::Engine.new(data, escape_html: true).render(Object.new, locals)
    end
  end
end
