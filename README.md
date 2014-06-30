# RubWiki

- written in ruby
- git backend (only bare repository is supported)
- support for URL which contain UTF-8 character
- IRC notification

## deployment

~~~
git init --bare --shared /path/to/wikidata.git
git clone https://github.com/wacky612/rubwiki
cd rubwiki
cp config/config.yml.example config/config.yml
nano config/config.yml
bundle install --path=vendor/bundle
bundle exec rackup
~~~

- You have to make at least one commit in your
  git repository before you use this application.
- You can deploy this application on passenger.
