require "rake"
require "rake/tilde/version"

require "listen"

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

    def run(name)
      task_name = name.gsub(/^\~/, '')
      task = Rake::Task[task_name]
      listen_path = paths.fetch(task_name) {{}}
      paths = listen_path.fetch(:paths, listen_path.fetch(:path) { Dir.pwd })
      opts  = listen_path.fetch(:opts) {{}}
      blk   = listen_path[:blk]

      begin
        task.invoke
      rescue
        $stderr.puts "Task failed to run successfully"
      end

      listener = Listen.to(paths, opts) do |modified, added, removed|
        $stdout.puts "** File system changed"
        begin
          Rake::Task.tasks.each { |t| t.reenable }
          task.invoke
          blk.call(modified, added, removed) if blk
        rescue
          $stderr.puts "Task failed to run successfully"
        end
      end

      listeners.push listener
      listener.start
    end
  end
end

module OverrideInvoke
  def invoke_task(task_string)
    task_name, args = parse_task_string(task_string)

    if task_name =~ /^\~/
      Rake::Tilde.run(task_name)
    else
      super
    end
  end
end

Rake.application.extend OverrideInvoke

def listen(**args, &blk)
  Rake::Tilde.listen(**args, &blk)
end

at_exit do
  if Rake::Tilde.listening?
    begin
      sleep
    rescue Interrupt
      puts
    end
  end
end
