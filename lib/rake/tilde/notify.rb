require "shellwords"

def notify(message:, title: nil, subtitle: nil, group: Dir.pwd)
  cmd  = "terminal-notifier"
  cmd += " -message #{Shellwords.escape(message)}"
  cmd += " -title #{Shellwords.escape(title)}" if title
  cmd += " -subtitle #{Shellwords.escape(subtitle)}" if subtitle
  cmd += " -group #{Shellwords.escape(group)}"

  system cmd
end
