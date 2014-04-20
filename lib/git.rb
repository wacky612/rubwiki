# -*- coding: utf-8 -*-
require 'rugged'

module RubWiki
  class Git
    def initialize(path)
      @repo = Rugged::Repository.new(path)
      @tree_oid = @repo.last_commit.tree.oid
    end

    def exist?(path)
      return get_oid(path) ? true : false
    end

    def dir?(path)
      oid = get_oid(path)
      return false unless oid
      obj = @repo.lookup(get_oid(path))
      return obj.instance_of?(Rugged::Tree)
    end

    def file?(path)
      oid = get_oid(path)
      return false unless oid
      obj = @repo.lookup(oid)
      return obj.instance_of?(Rugged::Blob)
    end

    def read(path)
      obj = @repo.lookup(get_oid(path))

      if obj.instance_of?(Rugged::Blob)
        return obj.text
      else
        return nil
      end
    end

    def ls(dir = "")
      obj = @repo.lookup(get_oid(dir))

      if obj.instance_of?(Rugged::Tree)
        list = []
        obj.each do |entry|
          list << entry
        end
        return list
      else
        return nil
      end
    end

    def sha(path)
      oid = get_oid(path)
      obj = @repo.lookup(oid)

      if obj.instance_of?(Rugged::Blob)
        return oid
      else
        return nil
      end
    end

    def history(path)
      walker = Rugged::Walker.new(@repo)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(@repo.head.target)
      commits = []
      walker.each do |commit|
        if commit.parents.size >= 1 && commit.diff(paths: [path]).size > 0
          _commit = {}
          _commit[:author] = commit.author[:name]
          _commit[:message] = commit.message
          _commit[:time] = commit.time
          _commit[:oid] = get_oid(path, commit.tree.oid)
          commits << _commit
        end
      end
      return commits
    end

    def write(path, data)
      blob_oid = @repo.write(data, :blob)
      @tree_oid = update_tree(@tree_oid, path, blob_oid)
    end

    def commit(author, email, message)
      message = "no commit message!!" if message == ""
      options = {}
      options[:tree] = @tree_oid
      options[:author] = { :email => email, :name => author, :time => Time.now }
      options[:committer] = { :email => email, :name => author, :time => Time.now }
      options[:message] = message
      options[:parents] = @repo.empty? ? [] : [ @repo.head.target ].compact
      options[:update_ref] = 'HEAD'
      Rugged::Commit.create(@repo, options)
    end

    private

    def update_tree(tree_oid, path, blob_oid)
      builder = Rugged::Tree::Builder.new(@repo.lookup(tree_oid))
      if path.include?("/")
        dirname = path.partition("/").first
        new_oid = update_tree(builder[dirname][:oid], path.partition("/").last, blob_oid)
        builder.insert({ :name => dirname, :oid => new_oid, :filemode => 16384, :type => :tree })
      else
        builder.insert({ :name => path, :oid => blob_oid, :filemode => 33188, :type => :blob })
      end
      return builder.write(@repo)
    end

    def get_oid(path, tree_oid = nil)
      path = path.split("/")
      oid = tree_oid || @tree_oid

      path.each do |name|
        obj = @repo.lookup(oid)
        return nil unless obj[name]
        oid = obj[name][:oid]
      end

      return oid
    end
  end
end
