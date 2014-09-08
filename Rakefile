require 'data_mapper'
require 'json'
require 'yaml'
require_relative 'model'

CONFIG_FILE_PATH = 'config/config.yml'
settings = YAML.load(File.read(CONFIG_FILE_PATH))

DataMapper.setup :default, {
  :adapter  => settings["database_adapter"],
  :host     => settings["database_host"],
  :database => settings["database_name"],
  :user     => settings["database_user"],
  :password => settings["database_password"],
}

DataMapper.finalize

namespace :db do

  desc "populates the database with its initial dataset"
  task :populate => [:migrate, :delete] do
    Preference.create(:name => "votes_are_open", :status => 1)

    json = File.read('db/nominees.json')
    categories = JSON.parse(json)

    categories.each do | category |
      category_name = category["name"]
      current_category = Category.create(:name => category_name)

      category["nominees"].each do | nom |
        nominee = Nominee.create(:name => nom)
        current_category.nominees << nominee
      end
      current_category.save
    end

    puts "[✓] populate database"
  end

  desc "delets all records"
  task :delete do
    Pick.destroy
    User.destroy
    Category.destroy
    Nominee.destroy
    WinnerCategory.destroy
    puts "[✓] delete all existing records"
  end

  desc "creates the database schema"
  task :migrate do
    DataMapper.auto_migrate!
    puts "[✓] setup db schema"
  end

  desc "tries to upgrade any changes to the database schema"
  task :upgrade do
    DataMapper.auto_upgrade!
    puts "[✓] upgraded db schema"
  end

  desc "populates database with some dummy users"
  task :populate_dummy => [:populate] do

    @all_categories = Category.all
    @user = { "TheRealBaker" => "Nils Becker", "die_krabbe" => "die_krabbe", "The_Smoking_GNU" => "Michael", "timbckr" => "Tim Becker", "peternoster" => "Peter Schneider", "freedika" => "annika stelter", "JerikoOne" => "Christoph Boecken", "iheartpluto" => "Nils", "marthadear" => "anne wizorek" }

    User.transaction do | t |
      1.times do
        @user.each_with_index do | (twitter, name), index |
          user = User.create(:uid => index, :name => name, :twitter_handle => twitter, :picked => 1, )

          @all_categories.each do | category |
            nominee = category.nominees.first
            pick = Pick.new
            pick.category = category
            pick.nominee = nominee
            user.picks << pick
          end

          user.save
        end
      end
      t.commit
    end

    puts "[✓] create dummy users"
  end

end

namespace :admin do

  desc "deletes user with specific twitter handle"
  task :delete_user, :twitter_handle do | t, args |
    user = User.first(:twitter_handle => args[:twitter_handle])
    users_picks = Pick.all(:user => user)
    users_picks.destroy
    user.destroy
    puts "[✓] deleted: #{args[:twitter_handle]}"
  end

  desc "reset all selected winners"
  task :reset_all_winners do
    WinnerCategory.destroy

    query = 'UPDATE users
               SET correct_picks = coalesce((
               SELECT count(v.user_id)
               FROM picks v
               WHERE v.nominee_id = (
                 SELECT nominee_id
                 FROM winner_categories wc
                 WHERE wc.category_id = v.category_id AND wc.nominee_id = v.nominee_id
               )
               GROUP BY v.user_id
               HAVING v.user_id = users.id
             ), 0)'

      adapter = DataMapper.repository(:default).adapter
      adapter.execute(query)

      update_ranking = 'update users set ranking = (select ((select count(distinct correct_picks) from users where correct_picks > u.correct_picks) + 1) from users u where  u.id = users.id)'
      adapter.execute(update_ranking)
  end

  desc "reset winner for category id"
  task :reset_winner, :category_id do | t, args |
    category = Category.first(:id => args[:category_id])
    winner_category = WinnerCategory.first(:category => category)
    winner_category.destroy

    query = 'UPDATE users
               SET correct_picks = coalesce((
               SELECT count(v.user_id)
               FROM picks v
               WHERE v.nominee_id = (
                 SELECT nominee_id
                 FROM winner_categories wc
                 WHERE wc.category_id = v.category_id AND wc.nominee_id = v.nominee_id
               )
               GROUP BY v.user_id
               HAVING v.user_id = users.id
             ), 0)'

      adapter = DataMapper.repository(:default).adapter
      adapter.execute(query)

      update_ranking = 'update users set ranking = (select ((select count(distinct correct_picks) from users where correct_picks > u.correct_picks) + 1) from users u where  u.id = users.id)'
      adapter.execute(update_ranking)
  end

end

namespace :stats do

  desc "show users without picks"
  task :users_without_picks do
    users = User.all(:picked => 0)
    users.each_with_index do | user, index |
      puts "#{index + 1}. #{user.name}: #{user.twitter_handle}"
    end
  end

  desc "show users without favourites"
  task :users_without_favs do
    users = User.all
    users.each_with_index do | user, index |
      puts "#{index + 1}. #{user.name}: #{user.twitter_handle}" unless user.favourites.count > 0
    end
  end

end

