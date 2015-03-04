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

    def run(task_name, *task_args)
      task        = Rake.application[task_name]
      listen_path = paths.fetch(task_name.intern) {{}}
      paths       = listen_path.fetch(:paths, listen_path.fetch(:path) { Dir.pwd })
      opts        = listen_path.fetch(:opts) {{}}
      blk         = listen_path[:blk]

      begin
        task.invoke(*task_args)
      rescue StandardError => exception
        $stderr.puts "** Task failed to run successfully with tilde"
        Rake.application.display_error_message(exception)
        Rake.application.exit_because_of_exception(exception)
      end

      listener = Listen.to(paths, opts) do |modified, added, removed|
        $stdout.puts "** File system changed"
        begin
          Rake::Task.tasks.each { |t| t.reenable }
          task.invoke(*task_args)
          blk.call(modified, added, removed) if blk
        rescue StandardError => exception
          $stderr.puts "** Task failed to run successfully with tilde"
          Rake.application.display_error_message(exception)
        end
      end

      listeners.push listener
      listener.start
    end
  end
end

module OverrideInvoke
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

at_exit do
  if Rake::Tilde.listening?
    begin
      sleep
    rescue Interrupt
      puts
    end
  end
end
