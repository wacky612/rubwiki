# -*- coding: utf-8 -*-
require 'uri'
require 'erb'
require 'nkf'
require 'haml'
require 'kramdown'
require 'mime-types'

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/config_file'

require_relative 'git'

module RubWiki
  class App < Sinatra::Base

    register Sinatra::Reloader
    register Sinatra::ConfigFile
    config_file "#{File.dirname(__FILE__)}/../config/config.yml"
    set :views, "#{File.dirname(__FILE__)}/../views"
    set :public_folder, "#{File.dirname(__FILE__)}/../public"

    get '/' do
      wiki = Git.new(settings.git_repo_path)
      @list = wiki.ls()
      @contents = haml(erb(:list))
      return haml(:page)
    end

    get '/*/history' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      @commits = wiki.history("#{path}.md")
      @contents = haml(erb(:history))
      return haml(:page)
    end

    get '/*/revision/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      revision = params[:splat].last
      raw_data = wiki.read_from_oid(revision)
      @contents = markdown(raw_data)
      return haml(:page)
    end

    get '/*/edit' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      if wiki.exist?("#{path}.md")
        halt unless wiki.file?("#{path}.md")
        @sha = wiki.sha("#{path}.md")
        @raw_data = wiki.read("#{path}.md")
      else
        @sha = ""
        @raw_data = ""
      end
      @contents = haml(:edit)
      return haml(:page)
    end

    get '/*/' do
      wiki = Git.new(settings.git_repo_path)
      dir = params[:splat].first
      halt unless wiki.dir?(dir)
      @list = wiki.ls(dir)
      @contents = haml(erb(:list))
      return haml(:page)
    end

    get '/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      if File.extname(path).empty?
        halt unless wiki.exist?("#{path}.md")
        raw_data = wiki.read("#{path}.md")
        @contents = markdown(raw_data)
        return haml(:page)
      else
        halt unless wiki.exist?(path)
        content_type MIME::Types.type_for(path)[0].to_s
        return wiki.read(path)
      end
    end

    post '/*/commit' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      new_raw_data = params[:data]
      commit_message = params[:commit_message]
      sha1 = params[:sha]
      sha2 = wiki.sha("#{path}.md")

      if sha1 == sha2
        wiki.write("#{path}.md", NKF.nkf("-Luw", new_raw_data))
        wiki.commit(remote_user(), "#{remote_user()}@kmc.gr.jp", commit_message)
        redirect to(URI.encode("/#{path}"))
      else
        return "conflict"
      end
    end

    post '/*/preview' do
      @raw_data = params[:data]
      @sha = params[:sha]
      @contents = haml(:edit)
      @contents << markdown(@raw_data)
      return haml(:page)
    end

    private

    def remote_user
      if request.env['REMOTE_USER']
        return request.env['REMOTE_USER']
      else
        return "anonymous"
      end
    end

  end
end
