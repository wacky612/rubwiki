# -*- coding: utf-8 -*-
require 'uri'
require 'nkf'
require 'sass'
require 'socket'
require 'mime-types'

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/config_file'

require_relative 'git'
require_relative 'view'

module RubWiki
  class App < Sinatra::Base

    configure :development do
      register Sinatra::Reloader
      also_reload "#{File.dirname(__FILE__)}/git.rb"
      also_reload "#{File.dirname(__FILE__)}/view.rb"
      also_reload "#{File.dirname(__FILE__)}/kramdown_custom.rb"
    end

    register Sinatra::ConfigFile
    config_file "#{File.dirname(__FILE__)}/../config/config.yml"

    set :public_folder, "#{File.dirname(__FILE__)}/../public"
    set :views, "#{File.dirname(__FILE__)}/../views"
    set :lock, true

    before do
      @wiki = Git.new(settings.git_repo_path)
      @view = View.new(@wiki, url("/")[0..-2], settings)
    end

    get '/css/style.css' do
      scss :style, :style => :compressed
    end

    get '/' do
      list = @wiki.ls()
      return @view.list(list)
    end

    get '/*/!history' do |path|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      commits = @wiki.history(File.extname(path).empty? ? append_ext(path) : path)
      return @view.history(commits, path)
    end

    get '/*/!revision/*' do |path, revision|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      raw_data = @wiki.read_from_oid(revision)
      halt(404, @view.invalid_revision(revision)) unless raw_data
      if File.extname(path).empty?
        return @view.revision(raw_data, path, revision)
      else
        guess_mime(path)
        return raw_data
      end
    end

    get '/*/!diff/*/*' do |path, oid1, oid2|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      diff = @wiki.diff(oid1, oid2)
      halt(404, @view.invalid_diff(oid1, oid2)) unless diff
      return @view.diff(diff, path, oid1, oid2)
    end

    get '/*/!edit' do |path|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      halt(403, @view.cannot_edit(path)) unless File.extname(path).empty?
      if @wiki.exist?(append_ext(path))
        halt(403, @view.exist_dir(append_ext(path))) unless @wiki.file?(append_ext(path))
        oid = @wiki.oid(append_ext(path))
        raw_data = @wiki.read(append_ext(path))
      elsif @wiki.can_create?(append_ext(path))
        oid = ""
        raw_data = ""
      else
        halt(403, @view.cannot_create(path))
      end
      return @view.edit(raw_data, oid, path)
    end

    get '/*/' do |dir|
      halt(403, @view.invalid_path(dir)) if invalid_path?(dir)
      halt(404, @view.not_exist_dir(dir)) unless @wiki.dir?(dir)
      list = @wiki.ls(dir)
      return @view.list(list, dir)
    end

    get '/*' do |path|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      if File.extname(path).empty?
        if @wiki.exist?(append_ext(path))
          halt(403, @view.exist_dir(append_ext(path))) if @wiki.dir?(append_ext(path))
          etag @wiki.oid(append_ext(path))
          raw_data = @wiki.read(append_ext(path))
          return @view.view(raw_data, path)
        elsif @wiki.can_create?(append_ext(path))
          redirect to(URI.encode("/#{path}/!edit"))
        else
          halt(403, @view.cannot_create(path))
        end
      else
        redirect to(URI.encode("/#{path}/")) if @wiki.dir?(path)
        halt(404, @view.not_exist(path)) unless @wiki.exist?(path)
        guess_mime(path)
        return @wiki.read(path)
      end
    end

    post '/*/!commit' do |path|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      raw_data_from_web = NKF.nkf("-Luw", params[:data])
      commit_message = params[:commit_message]
      oid_from_web = params[:oid]
      oid_from_git = @wiki.oid(append_ext(path))
      is_notify = params[:irc_notification] != "dont_notify"

      if oid_from_web == oid_from_git
        @wiki.write(append_ext(path), raw_data_from_web)
        @wiki.commit(remote_user(), remote_user_mail(), commit_message)
        irc_notify(path, remote_user(), commit_message) if is_notify && settings.irc[:enable]
        redirect to(URI.encode("/#{path}"))
      else
        raw_data_old = @wiki.read_from_oid(oid_from_web)
        raw_data_from_git = @wiki.read(append_ext(path))
        raw_data_merged, is_success = merge(raw_data_from_web, raw_data_old, raw_data_from_git)
        if is_success
          @wiki.write(append_ext(path), raw_data_merged)
          @wiki.commit(remote_user(), remote_user_mail(), commit_message)
          irc_notify(path, remote_user(), commit_message) if is_notify && settings.irc[:enable]
          redirect to(URI.encode("/#{path}"))
        else
          return @view.conflict(raw_data_merged, path, oid_from_git)
        end
      end
    end

    post '/*/!preview' do |path|
      halt(403, @view.invalid_path(path)) if invalid_path?(path)
      raw_data = params[:data]
      oid = params[:oid]
      return @view.preview(raw_data, oid, path)
    end

    post '/!search' do
      keyword = params[:keyword]
      halt(403, @view.empty_search()) if keyword.empty?
      result = @wiki.search(keyword)
      return @view.search(keyword, result)
    end

    private

    def invalid_path?(path)
      return path.include?("/!")
    end

    def remote_user
      if request.env['REMOTE_USER']
        return request.env['REMOTE_USER']
      else
        return "anonymous"
      end
    end

    def remote_user_mail
      domain = settings.domain
      return "#{remote_user()}@#{domain}"
    end

    def guess_mime(path)
      begin
        content_type MIME::Types.type_for(path)[0].to_s
      rescue
        content_type "text/plain"
      end
    end

    def merge(raw_data_from_web, raw_data_old, raw_data_from_git)
      raw_data_merged = nil
      Dir.chdir("/tmp") do
        File.write("web", raw_data_from_web)
        File.write("old", raw_data_old)
        File.write("git", raw_data_from_git)
        IO.popen("diff3 -mE web old git", "r", :encoding => Encoding::UTF_8) do |io|
          raw_data_merged = io.read
        end
        File.delete("web")
        File.delete("old")
        File.delete("git")
      end
      return raw_data_merged, ($? == 0)
    end

    def append_ext(path)
      return "#{path}.md"
    end

    def irc_notify(path, author, commit_message)
      TCPSocket.open(settings.irc[:server], settings.irc[:port]) do |socket|
        socket.puts("PASS #{settings.irc[:pass]}")
        socket.puts("NICK #{settings.irc[:nick]}")
        socket.puts("USER #{settings.irc[:user]}")
        wikiname = settings.wikiname
        channel = settings.irc[:channel]
        url = url("/#{URI.encode(path)}")
        socket.puts("PRIVMSG #{channel} :[#{wikiname}] #{path} is updated by #{author}")
        socket.puts("PRIVMSG #{channel} :[#{wikiname}] #{url}")
        socket.puts("PRIVMSG #{channel} :[#{wikiname}] Commit Message: #{commit_message}")
      end
    end
  end
end
