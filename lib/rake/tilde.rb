require "rake"
require "rake/tilde/version"

require "listen"
require "open4"
require 'shellwords'

module Rake
  module Tilde
    module_function

    def paths
      @paths ||= {}
    end

    def listen(**args, &blk)
      name = args.delete(:to)
      args[:blk] = blk
      paths[name] = args
    end

    def listening?
      !listeners.empty?
    end

    def listeners
      @listeners ||= []
    end

    def run(task_name, *task_args)
      task        = Rake.application[task_name]
      listen_path = paths.fetch(task_name.intern) {{}}
      paths       = listen_path.fetch(:paths, listen_path.fetch(:path) { Dir.pwd })
      opts        = listen_path.fetch(:opts) {{}}
      blk         = listen_path[:blk]

      # run a first time
      run_external task.name, blk

      listener = Listen.to(paths, opts) do |modified, added, removed|
        $stdout.puts "** File system changed"
        run_external task.name, blk, modified: modified, added: added, removed: removed
      end

      listeners.push listener
      listener.start
    end

    def run_external(name, blk, modified: [], added: [], removed: [])
      cmd = if File.exists?("bin/rake")
              "bin/rake"
            else
              "rake"
            end

      stdout = Streamer.new($stdout)
      stderr = Streamer.new($stderr)

      status = Open4.spawn "#{cmd} #{name}", 'stdout' => stdout, 'stderr' => stderr, 'raise' => false, 'quiet' => true

      if blk
        arg = TaskResult.new(modified, added, removed, stdout.read.strip, stderr.read.strip, status)
        blk.call(arg)
      end
    rescue StandardError => exception
      $stderr.puts "** Task failed to run successfully with tilde"
      Rake.application.display_error_message(exception)
    end

    def sleep_forever
      begin
        sleep
      rescue Interrupt
        puts
      end
    end
  end

  TaskResult = Struct.new(:modified, :added, :removed, :stdout, :stderr, :status)

  class Streamer
    def initialize(putser)
      @putser = putser
      @content = ""
    end

    def <<(line)
      @putser.puts line
      @content << line
    end

    def read
      @content.dup
    end
  end
end

module OverrideInvoke
  def top_level
    super
    Rake::Tilde.sleep_forever if tilde?
  end

  def invoke_task(task_string)
    task_string = task_string.gsub(/^\~/, '')
    task_name, args = parse_task_string(task_string)

    if tilde_tasks.include?(task_name)
      Rake::Tilde.run(task_name, *args)
    else
      super
    end
  end

  def tilde_tasks
    @__tilde_tasks ||= []
  end

  def tilde?
    tilde_tasks.any?
  end
end

Rake.application.extend OverrideInvoke

# Remove tildes from all the top level tasks
# and record which ones they were
Rake.application.top_level_tasks.map! do |task_name|
  if task_name =~ /^(~)(.*)$/
    Rake.application.tilde_tasks << $2
    $2
  else
    task_name
  end
end

def listen(**args, &blk)
  Rake::Tilde.listen(**args, &blk)
end

def notify(message:, title: nil, subtitle: nil, group: Dir.pwd)
  cmd = "terminal-notifier"
  cmd += " -message #{Shellwords.escape(message)}"
  cmd += " -title #{Shellwords.escape(title)}" if title
  cmd += " -subtitle #{Shellwords.escape(subtitle)}" if subtitle
  cmd += " -group #{Shellwords.escape(group)}"

  system cmd
end

namespace :tilde do
  task :sleep do
    Rake::Tilde.sleep_forever unless Rake.application.tilde?
  end
end
