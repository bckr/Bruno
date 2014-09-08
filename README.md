Bruno
=======

Bruno lets you set up your own polling system for award shows like the Oscars. Authentication is handled via Twitter. Bruno uses the [Sinatra Framework](http://www.sinatrarb.com/) and [Postgres](http://www.postgresql.org/) as its database. For a live example take a look at [Oscar Picks](http://oscar-picks.com).

## Example

![](http://nilsbecker.s3.amazonaws.com/bruno_preview.png)

## Initial Setup

1. You need to register a new [Twitter Application](https://apps.twitter.com/) to get your own API key and secret. The Callback URL should have the following format: `http://yourdomain.com/auth/twitter/callback`

2. Run `bundle install` to install all necessary dependencies 

3. Fill out the configuration file. The config folder holds an example configuration file which should be self-explanatory. The `admin_twitter_handle` determines which user gets admin privileges to update the winners for each category and lock the voting process.

4. The categories and their respective nominees for the voting are provided by a simple json file called `nominees.json`

5. Run `rake db:populate` to populate the database with its initial dataset

There allready is an example for the 2013 Oscars in the db folder which serves as a template for your own setup. The file has the following format:

```json
[
   {
      "name":"Best Motion Picture of the Year",
      "nominees":[
         "American Hustle",
         "Captain Phillips",
         "Dallas Buyers Club",
         "Gravity",
         "Her",
         "Nebraska",
         "Philomena",
         "12 Years a Slave",
         "The Wolf of Wall Street"
      ]
   },
   {
      "name":"Best Performance by an Actor in a Leading Role",
      "nominees":[
         "Christian Bale for American Hustle",
         "Bruce Dern for Nebraska",
         "Leonardo DiCaprio for The Wolf of Wall Street",
         "Chiwetel Ejiofor for 12 Years a Slave",
         "Matthew McConaughey for Dallas Buyers Club"
      ]
   }
]
```

## Administration

Use the provided Rakefile and its task `db:populate_dummy` to populate the database with its initial dataset and some dummy users for testing your setup. The Rakefile also provides several administrative tasks and some more or less usefull statistics:

```ruby
rake admin:delete_user[twitter_handle]  # deletes user with specific twitter handle
rake admin:reset_all_winners            # reset all selected winners
rake admin:reset_winner[category_id]    # reset winner for category id
rake db:delete                          # delets all records
rake db:migrate                         # creates the database schema
rake db:populate                        # populates the database with its initial dataset
rake db:populate_dummy                  # populates database with some dummy users
rake db:upgrade                         # tries to upgrade any changes to the database schema
rake stats:users_without_favs           # show users without favourites
rake stats:users_without_picks          # show users without picks
```
