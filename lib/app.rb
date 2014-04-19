# -*- coding: utf-8 -*-
require 'uri'
require 'erb'
require 'haml'
require 'kramdown'

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
    set :wiki, Git.new(settings.git_repo_path)

    get '/' do
      @list = settings.wiki.ls()
      @contents = haml(erb(:list))
      return haml(:page)
    end

    get '/*/edit' do
      path = params[:splat].first
      if settings.wiki.exist?("#{path}.md")
        halt unless settings.wiki.file?("#{path}.md")
        @sha = settings.wiki.sha("#{path}.md")
        @raw_data = settings.wiki.read("#{path}.md")
      else
        @sha = ""
        @raw_data = ""
      end
      @contents = haml(:edit)
      return haml(:page)
    end

    get '/*/' do
      dir = params[:splat].first
      halt unless settings.wiki.dir?(dir)
      @list = settings.wiki.ls(dir)
      @contents = haml(erb(:list))
      return haml(:page)
    end

    get '/*' do
      path = params[:splat].first
      if File.extname(path).empty?
        halt unless settings.wiki.exist?("#{path}.md")
        raw_data = settings.wiki.read("#{path}.md")
        @contents = markdown(raw_data)
        return haml(:page)
      else
        halt unless settings.wiki.exist?(path)
        return settings.wiki.read(path)
      end
    end

    post '/*/commit' do
      path = params[:splat].first
      new_raw_data = params[:data]
      commit_message = params[:commit_message]
      sha1 = params[:sha]
      sha2 = settings.wiki.sha("#{path}.md")

      if sha1 == sha2
        settings.wiki.write("#{path}.md", new_raw_data)
        settings.wiki.commit(remote_user(), "#{remote_user()}@kmc.gr.jp", commit_message)
        redirect URI.encode("/#{path}") # passenger にのせた時に変更する必要あり
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
