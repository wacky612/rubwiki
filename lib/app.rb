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
      path = "#{path}.md" if File.extname(path).empty?
      @commits = wiki.history(path)
      @contents = haml(erb(:history))
      return haml(:page)
    end

    get '/*/revision/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      revision = params[:splat].last
      raw_data = wiki.read_from_oid(revision)
      if File.extname(path).empty?
        @contents = markdown(raw_data)
        return haml(:page)
      else
        begin
          content_type MIME::Types.type_for(path)[0].to_s
        rescue
          content_type "text/plain"
        end
        return raw_data
      end
    end

    get '/*/diff/*/*' do
      wiki = Git.new(settings.git_repo_path)
      path = params[:splat].first
      oid1 = params[:splat][1]
      oid2 = params[:splat][2]
      @diff = wiki.diff(oid1, oid2)
      @contents = haml(erb(:diff))
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
        old_raw_data = wiki.read_from_oid(sha1)
        raw_data_from_git = wiki.read("#{path}.md")
        raw_data_from_web = NKF.nkf("-Luw", new_raw_data)
        Dir.chdir("/tmp") do
          File.write("web", raw_data_from_web)
          File.write("old", old_raw_data)
          File.write(sha2, raw_data_from_git)
          IO.popen("merge -p web old #{sha2}", "r", :encoding => Encoding::UTF_8) do |io|
            @raw_data = io.read
          end
          File.delete("web")
          File.delete("old")
          File.delete(sha2)
        end
        if $? == 0
          wiki.write("#{path}.md", @raw_data)
          wiki.commit(remote_user(), "#{remote_user()}@kmc.gr.jp", commit_message)
          redirect to(URI.encode("/#{path}"))
        else
          @contents = haml(:edit)
          return haml(:page)
        end
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
