# Rake::Tilde

Run rake tasks when files change. No changes necessary to your Rakefile,
just prepend your task name with ~ like: `$ rake ~build`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rake-tilde'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rake-tilde

## Usage

This gem monkeypatch's Rake to intercept any task that begins with ~. In
that case that task is run whenever any files in the project change.
This is a basic wrapper around the [listen gem](https://github.com/guard/listen).

Any existing task will work with a ~ in front:

```sh
$ rake ~test
```

The task is run once and then a listener is setup to watch for file
changes on the current directory. Each successive run is done in it's
own process, so global modifications during the rake task should not
bleed over (look at your rails).

If you invoke more than one ~ task, they are each run once, then listers
are setup for each, then rake-tilde will wait for changes. It's even
possible to mix and match:

```sh
$ rake clean ~compile ~publish notify
```

In this example, the four tasks will be run in order: clean, compile,
publish, then notify. Then, rake-tilde will run both compile and publish
after any changes. These two tasks will be run in parallel, not in
sequence so keep that in mind. If that is a feature you would like then
let me know.

More interesting things can be done by specifying folders, ignores, etc
for tasks:

```ruby
task :woo do
  puts "woo"
end

listen to: :woo, path: "/somewhere-else", opts: { ignore: /\.rb$/ } do |modified, added, removed|
  puts "I know what changed specifically!"
end
```

Then run it like this:

```sh
$ rake ~woo
```

This can be used to setup a livereload system:

```ruby
require 'rack/contrib/try_static'
require 'rack/livereload'
require 'net/http'
require 'json'

# **************************************************************
# let's find all the files in ./src and copy them over to ./site
# **************************************************************

$src_files  = FileList['./src/**/*.*']
$site_files = $src_files.pathmap('%{^src/,site/}p')

# make a lambda that can convert a filepath from render to src
render_to_src = ->(name) { name.pathmap('%{^render/,src/}p') }

# any file expected to be in ./site depends on the file with the same name in ./src
# we create any missing file in ./site by reading and rendering the related file in ./src
rule %r{^render/} => [render_to_src] do |t|
  File.dirname(t.name).tap do |dir|
    mkdir_p dir
    cp t.source, dir
    # do other transformations to these files here
  end
end

# compile depends on the expected ./site files, which will in turn depend
# on the same named file in ./src

task :compile => $site_files

# Let's make a way to know the url of a file from it's absolute path
def url(path)
  root_dir = File.expand_path '../..', __FILE__
  root_regex = Regexp.new("^#{root_dir}/src/")
  path.gsub(root_regex, '/')
end

# Now we customize what happens when a file is changed to post that file
# to the livereload server
listen :compile, path: './src' do |modified, added, removed|
  livereload_files = [modified, added, removed].flatten.map { |f| url(f) }.compact
  puts "Live reloading: #{livereload_files.join(", ")}"

  req = Net::HTTP::Post.new $livereload_uri
  req.body = JSON.generate(files: livereload_files)
  req.content_type = 'application/json'

  begin
    Net::HTTP.start($livereload_uri.host, $livereload_uri.port) { |http| http.request req }
  rescue
    puts "Updating livereload failed... Not sure why."
  end
end

# serve will boot two servers and then sleep
task :serve => ['serve:http', 'serve:websockets', 'tilde:sleep']

# Making a static server in ruby is too many lines of code, we gotta
# make this easier
$app = Rack::Builder.new {
  use Rack::LiveReload, no_swf: true

  use Rack::TryStatic,
    root: './site',
    urls: %w[/],
    try: ['.html', 'index.html', '/index.html']

  run ->(env) {
    four_oh_four_page = File.new("./site/404.html") # Make sure you have a 404.html file, kthnxbye
    [404, { 'Content-Type'  => 'text/html'}, four_oh_four_page.each_line]
  }
}

# ok, now we build the two rake tasks to boot these servers up
namespace :serve do
  task :websockets do
    puts "booting the livereload server"

    pid = spawn('tiny-lr')

    at_exit do
      puts "killing the livereload server"
      Process.kill 9, pid
      Process.wait pid
      sleep 0.1
    end
  end

  task :http do
    puts "booting the files server"

    pid = fork do
      Rack::Server.start({
        app:         $app,
        environment: :development,
        server:      :webrick,
        Port:        ENV.fetch("PORT", 8000)
      })
    end

    at_exit do
      puts "killing the files server"
      Process.kill 9, pid
      Process.wait pid
      sleep 0.1
    end
  end
end
```

This assumes you have installed `tiny-lr`. If you haven't, then:

```sh
$ npm install tiny-lr -g
```

Now you can simply run:

```sh
$ rake serve ~compile
```

and you will get the serves, all your html files will have the
livereload javascript installed, and any changes you make will appear in
the browser almost instantly.



## Rails (or other fancy libraries)

Some libraries really care about the names of the tasks from the
original ARGV string during load. In that case, just prepend `require
'rake/tilde'` to your Rakefile before anything else and it will rewrite
all the task names before any other library can see them.

## Contributing

1. Fork it ( https://github.com/myobie/rake-tilde/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
