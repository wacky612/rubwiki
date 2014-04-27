# -*- coding: utf-8 -*-
require 'uri'
require 'nkf'
require 'sass'
require 'haml'
require 'socket'
require 'kramdown'
require 'mime-types'

require 'string/scrub'

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/config_file'

require_relative 'git'
require_relative 'view'

module RubWiki
  class App < Sinatra::Base

    register Sinatra::Reloader
    also_reload "#{File.dirname(__FILE__)}/git.rb"
    also_reload "#{File.dirname(__FILE__)}/view.rb"

    register Sinatra::ConfigFile
    config_file "#{File.dirname(__FILE__)}/../config/config.yml"

    set :views, "#{File.dirname(__FILE__)}/../views"
    set :public_folder, "#{File.dirname(__FILE__)}/../public"
    set :lock, true

    helpers View

    get '/style.css' do
      scss :style, :style => :expanded
    end

    get '/' do
      wiki = Git.new(settings.git_repo_path)
      list = wiki.ls()
      return list(list)
    end

    get '/*/history' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      halt unless valid_path?(path)
      commits = wiki.history(File.extname(path).empty? ? append_ext(path) : path)
      return history(commits, path)
    end

    get '/*/revision/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      revision = params[:splat].last
      halt unless valid_path?(path)
      raw_data = wiki.read_from_oid(revision)
      halt unless raw_data
      if File.extname(path).empty?
        return revision(raw_data, path, revision)
      else
        guess_mime(path)
        return raw_data
      end
    end

    get '/*/diff/*/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      oid1 = params[:splat][1]
      oid2 = params[:splat][2]
      halt unless valid_path?(path)
      diff = wiki.diff(oid1, oid2)
      halt unless diff
      return diff(diff, path, oid1, oid2)
    end

    get '/*/edit' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      halt unless valid_path?(path)
      if wiki.exist?(append_ext(path))
        halt unless wiki.file?(append_ext(path))
        oid = wiki.oid(append_ext(path))
        raw_data = wiki.read(append_ext(path))
      elsif wiki.can_create?(append_ext(path))
        oid = ""
        raw_data = ""
      else
        halt
      end
      return edit(raw_data, oid, path)
    end

    get '/*/' do
      wiki = Git.new(settings.git_repo_path)
      dir = params[:splat].first
      halt unless valid_path?(path)
      halt unless wiki.dir?(dir)
      list = wiki.ls(dir)
      return list(list, dir)
    end

    get '/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      halt unless valid_path?(path)
      if File.extname(path).empty?
        if wiki.exist?(append_ext(path))
          raw_data = wiki.read(append_ext(path))
          return view(raw_data, path)
        elsif wiki.can_create?(append_ext(path))
          redirect to(URI.encode("/#{path}/edit"))
        else
          halt
        end
      else
        halt unless wiki.exist?(path)
        guess_mime(path)
        return wiki.read(path)
      end
    end

    post '/*/commit' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      halt unless valid_path?(path)
      raw_data_from_web = NKF.nkf("-Luw", params[:data])
      commit_message = params[:commit_message]
      oid_from_web = params[:oid]
      oid_from_git = wiki.oid(append_ext(path))
      is_notify = params[:irc_notification] != "dont_notify"

      if oid_from_web == oid_from_git
        wiki.write(append_ext(path), raw_data_from_web)
        wiki.commit(remote_user(), remote_user_mail(), commit_message)
        irc_notify(path, remote_user(), commit_message) if is_notify
        redirect to(URI.encode("/#{path}"))
      else
        raw_data_old = wiki.read_from_oid(oid_from_web)
        raw_data_from_git = wiki.read(append_ext(path))
        raw_data_merged, is_success = merge(raw_data_from_web, raw_data_old, raw_data_from_git)
        if is_success
          wiki.write(append_ext(path), raw_data_merged)
          wiki.commit(remote_user(), remote_user_mail(), commit_message)
          irc_notify(path, remote_user(), commit_message) if is_notify
          redirect to(URI.encode("/#{path}"))
        else
          return conflict(raw_data_merged, path, oid_from_git)
        end
      end
    end

    post '/*/preview' do
      path = params[:splat].first
      halt unless valid_path?(path)
      raw_data = params[:data]
      oid = params[:oid]
      return preview(raw_data, oid, path)
    end

    post '/search' do
      wiki = Git.new(settings.git_repo_path)
      keyword = params[:keyword]
      result = wiki.search(keyword)
      return search(keyword, result)
    end

    private

    def valid_path?(path)
      names = path.split("/")
      forbidden_words = ["edit", "preview", "commit", "diff", "search", "history", "revision"]
      return (names & forbidden_words).empty?
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
