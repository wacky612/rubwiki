module RubWiki
  module View
    def search(keyword, result)
      nav = haml :nav, locals: { path: nil }
      article = haml :search, locals: { result: result, keyword: keyword }
      return page(nav, article)
    end

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

    def preview(raw_data, oid, path, wiki)
      nav = haml :nav, locals: { path: nil }
      form = haml :form, locals: { raw_data: raw_data, oid: oid }
      preview = markdown(append_baseurl(autolink(raw_data, wiki)))
      article = haml :preview, locals: { form: form, preview: preview, path: path }
      return page(nav, article)
    end

    def edit(raw_data, oid, path)
      nav = haml :nav, locals: { path: nil }
      form = haml :form, locals: { raw_data: raw_data, oid: oid }
      article = haml :edit, locals: { form: form, path: path }
      return page(nav, article)
    end

    def view(raw_data, path, wiki)
      nav = haml :nav, locals: { path: path }
      contents = markdown(append_baseurl(autolink(raw_data, wiki)))
      article = haml :view, locals: { contents: contents, path: path }
      return page(nav, article)
    end

    def revision(raw_data, path, oid, wiki)
      nav = haml :nav, locals: { path: nil }
      contents = markdown(append_baseurl(autolink(raw_data, wiki)))
      article = haml :revision, locals: { contents: contents, path: path, oid: oid }
      return page(nav, article)
    end

    def invalid_path(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :invalid_path, locals: { path: path }
      return page(nav, article)
    end

    def cannot_create(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :cannot_create, locals: { path: path }
      return page(nav, article)
    end

    def invalid_revision(oid)
      nav = haml :nav, locals: { path: nil }
      article = haml :invalid_revision, locals: { oid: oid }
      return page(nav, article)
    end

    def invalid_diff(oid1, oid2)
      nav = haml :nav, locals: { path: nil }
      article = haml :invalid_diff, locals: { oid1: oid1, oid2: oid2 }
      return page(nav, article)
    end

    def cannot_edit(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :cannot_edit, locals: { path: path }
      return page(nav, article)
    end

    def exist_dir(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :exist_dir, locals: { path: path }
      return page(nav, article)
    end

    def not_exist(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :not_exist, locals: { path: path }
      return page(nav, article)
    end

    def empty_search
      nav = haml :nav, locals: { path: nil }
      article = haml :empty_search
      return page(nav, article)
    end

    def not_exist_dir(path)
      nav = haml :nav, locals: { path: nil }
      article = haml :not_exist_dir, locals: { path: path }
      return page(nav, article)
    end

    def page(nav, article)
      return haml :page, locals: { nav: nav, article: article }
    end

    def autolink(raw_data, wiki)
      return raw_data.gsub(/\[(.+)\]\(\)/) do
        "[#{$1}](#{wiki.search_file($1)})"
      end
    end

    def append_baseurl(raw_data)
      return raw_data.gsub(/\[(.+)\]\(\/(.*)\)/) do
        "[#{$1}](#{url("/")}#{$2})"
      end
    end
  end
end
