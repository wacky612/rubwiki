module RubWiki
  module View
    def diff(diff, path, oid1, oid2)
      nav = haml :nav, locals: { path: nil }
      article = haml :diff, locals: { diff: diff, path: path, oid1: oid1, oid2: oid2 }
      return page(nav, article)
    end

    def list(list, dir = "")
      nav = haml :nav, locals: { path: nil }
      article = haml :list, locals: { list: list, dir: dir }
      return page(nav, article)
    end

    def history(commits, path)
      nav = haml :nav, locals: { path: nil }
      article = haml :history, locals: { commits: commits, path: path }
      return page(nav, article)
    end

    def conflict(raw_data, path, oid)
      nav = haml :nav, locals: { path: nil }
      form = haml :form, locals: { raw_data: raw_data, oid: oid }
      article = haml :conflict, locals: { form: form, path: path }
      return page(nav, article)
    end

    def preview(raw_data, oid, path)
      nav = haml :nav, locals: { path: nil }
      form = haml :form, locals: { raw_data: raw_data, oid: oid }
      preview = markdown(raw_data)
      article = haml :preview, locals: { form: form, preview: preview, path: path }
      return page(nav, article)
    end

    def edit(raw_data, oid, path)
      nav = haml :nav, locals: { path: nil }
      form = haml :form, locals: { raw_data: raw_data, oid: oid }
      article = haml :edit, locals: { form: form, path: path }
      return page(nav, article)
    end

    def view(raw_data, path)
      nav = haml :nav, locals: { path: path }
      contents = markdown(raw_data)
      article = haml :view, locals: { contents: contents, path: path }
      return page(nav, article)
    end

    def revision(raw_data, path, oid)
      nav = haml :nav, locals: { path: nil }
      contents = markdown(raw_data)
      article = haml :revision, locals: { contents: contents, path: path, oid: oid }
      return page(nav, article)
    end

    def page(nav, article)
      return haml :page, locals: { nav: nav, article: article }
    end
  end
end
