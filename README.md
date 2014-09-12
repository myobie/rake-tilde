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
that case thet task is run whenever any files in the project change.
This is a basic wrapper around the [listen gem](https://github.com/guard/listen).

More interesting things can be done by specifying folders, ignores, etc
for tasks:

```ruby
task :woo do
  puts "woo"
end

listen to: :woo, path: "/somewhere-else", ignore: /\.rb$/ do |modified, added, removed|
  puts "woooooo"
end
```

Then run it like this:

```sh
$ rake ~woo
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/rake-tilde/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
