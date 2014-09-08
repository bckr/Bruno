require 'rubygems'
require 'sinatra'
require 'sinatra/config_file'
require 'sinatra/cache'
require 'omniauth-twitter'
require 'data_mapper'
require 'haml'
require_relative 'model'

class Voty < Sinatra::Base
  register Sinatra::ConfigFile
  register(Sinatra::Cache)

  configure do
    config_file 'config/config.yml'
    TWITTER_API_KEY = settings.twitter_api_key
    SECRET = settings.twitter_api_secret
    EXPIRE_AFTER = settings.expire_after
    DOMAIN = settings.domain
    PAGE_TITLE = settings.page_titel

    set :title, PAGE_TITLE

    enable :sessions
    set :sessions, :domain => DOMAIN
    set :sessions, :expire_after => EXPIRE_AFTER
    set :session_secret, SECRET
    set :root, File.dirname(__FILE__)
    set :cache_enabled, true
    set :cache_output_dir, Proc.new { File.join(root, 'public', 'cache') }

    DataMapper.setup :default, {
      :adapter  => settings.database_adapter,
      :host     => settings.database_host,
      :database => settings.database_name,
      :user     => settings.database_user,
      :password => settings.database_password,
    }

    DataMapper.finalize
  end

  use OmniAuth::Builder do
    provider :twitter, TWITTER_API_KEY, SECRET, {
      :image_size => 'bigger'
    }
  end

  helpers do
    USER_PER_PAGE = 10
    DEFAULT_PAGE = 1

    UPDATE_CORRECT_PICKS_QUERY = 'UPDATE users
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

    UPDATE_USER_RANKING_QUERY = 'UPDATE users SET ranking = (SELECT ((SELECT COUNT(DISTINCT correct_picks) FROM users WHERE correct_picks > u.correct_picks) + 1) FROM USERS u WHERE u.id = users.id)'

    def user_is_authenticated
      !session[:uid].nil?
    end

    def user_is_admin
      uid = session[:uid]
      user = User.first(:twitter_handle => settings.admin_twitter_handle)
      return user != nil && user.uid == uid
    end

    def get_authenticated_user
      uid = session[:uid]
      return User.first(:uid => uid)
    end

    def requires_role role
      case role
      when :admin
        redirect to('/nope') unless user_is_admin
      end
    end

    def votes_are_closed?
      pref = Preference.first(:name => "votes_are_open")
      return pref.status != 1
    end

    def lock_votes
      pref = Preference.first(:name => "votes_are_open")
      pref.status = 0
      pref.save
    end

    def open_votes
      pref = Preference.first(:name => "votes_are_open")
      pref.status = 1
      pref.save
    end

    def update_user_ranking

      adapter = DataMapper.repository(:default).adapter
      adapter.execute(UPDATE_USER_RANKING_QUERY)

      update_correct_picks()

      cache_expire('/stats')
    end

    def update_correct_picks
      adapter = DataMapper.repository(:default).adapter

      adapter.execute(UPDATE_CORRECT_PICKS_QUERY)
      cache_expire('/stats')
    end
  end

  before do
    pass if request.path_info =~ /^\/auth\//
    pass if request.path_info =~ /^\/stats/
    pass if request.path_info =~ /^\/.*$/
    pass if request.path_info == "/"
    pass if request.path_info =~ /^\/page\/[0-9]*/
    pass if request.path_info =~ /.*\/picks$/

    redirect to('/auth/twitter') unless user_is_authenticated
  end

  get '/auth/twitter/callback' do
    @uid = env['omniauth.auth']['uid']
    session[:uid] = @uid
    userinfo = env['omniauth.auth']['info']

    @name = userinfo[:'name']
    @twitter = userinfo[:'nickname']
    @image = userinfo[:'image']

    existing_user = User.first(:twitter_handle => @twitter)

    if existing_user.nil?
      User.create(:name => @name, :twitter_handle => @twitter, :image_url => @image, :uid => @uid)
    elsif existing_user.picked == 1
      redirect to('/')
    end

    redirect to("#{@twitter}/pick")
  end

  get '/auth/failure' do
   "login failed!"
  end

  get '/login' do
    if !User.first(:uid => session[:uid])
      session.clear
      redirect to('/auth/twitter')
    end
  end

  get '/logout' do
    session.clear
    redirect to('/')
  end

  get '/' do
    user_count = User.count(:picked => 1)
    @max_pages = (user_count.to_f / USER_PER_PAGE).ceil
    @page = DEFAULT_PAGE
    @page = @page > @max_pages ? @max_pages : DEFAULT_PAGE
    @offset = (@page * USER_PER_PAGE) - USER_PER_PAGE

    if @offset < 0
      @offset = 0
    end

    @users = User.all(:picked => 1, :order => [ :ranking.asc, :name.asc ], :offset => @offset, :limit => USER_PER_PAGE)

    @has_next_page = user_count > @offset + USER_PER_PAGE
    @has_previous_page = @page > 1

    uid = session[:uid]
    @auth_user = get_authenticated_user()
    @number_of_categories = Category.count
    haml :index, :cache => false
  end

  get '/page/:page' do | p |
    @page = p.to_i

    if @page <= 0
      redirect to('/')
    end

    user_count = User.count(:picked => 1)
    @max_pages = (user_count.to_f / USER_PER_PAGE).ceil
    @page = @max_pages if @page > @max_pages
    @offset = (@page * USER_PER_PAGE) - USER_PER_PAGE

    @users = User.all(:picked => 1, :order => [ :ranking.asc, :name.asc ], :offset => @offset, :limit => USER_PER_PAGE)

    @has_next_page = user_count > @offset + USER_PER_PAGE
    @has_previous_page = @page > 1

    uid = session[:uid]
    @auth_user = get_authenticated_user()
    @number_of_categories = Category.count
    haml :index, :cache => false
  end

  get '/:twitter/pick' do | twitter |
    @user = User.first(:twitter_handle => twitter)
    @auth_user = get_authenticated_user()

    if @user.nil? || @user != @auth_user
      redirect to('/')
    end

    if votes_are_closed?
      redirect to("/#{twitter}/picks")
    end

    @categories = Category.all
    @username = twitter

    haml :pick, :cache => false
  end

  get '/stats' do
    @auth_user = get_authenticated_user()
    @categories = Category.all
    @disable_nav = true
    haml :stats
  end

  get '/:twitter' do | twitter |
    @user = User.first(:twitter_handle => twitter)
    @auth_user = get_authenticated_user()

    if @user.nil? || @user.picked == 0
      redirect to('/')
    end

    @correct_favourites = 0
    favourites = Favourite.all(:user => @user)

    favourites.each do | fav |
      @correct_favourites += 1 unless !fav.is_correct
    end

    haml :profile, :cache => false
  end

  get '/:twitter/picks' do | twitter |
    @user = User.first(:twitter_handle => twitter)
    @auth_user = get_authenticated_user()

    if @user.nil? || @user.picked == 0
      redirect to('/')
    end

    haml :picks, :cache => false
  end

  post '/:twitter/picks' do | twitter |
    @categories = Category.all
    @user = User.first(:twitter_handle => twitter)
    @auth_user = get_authenticated_user()

    if @user.nil? || @user != @auth_user
      redirect to('/')
    end

    if votes_are_closed?
      redirect to("/#{twitter}/picks")
    end

    if @categories.count > (params.length - 4)
      redirect to("/#{twitter}/pick")
    end

    @user.picks.destroy
    @user.favourites.destroy

    @categories.each do | cat |
      picked = params[cat.name.to_sym]
      picked_nominee = cat.nominees.first(:name => picked)
      pick = Pick.new
      pick.category = cat
      pick.nominee = picked_nominee

      faved = params[("#{cat.name}_fav").to_sym]
      faved_nominee = Nominee.first(:name => faved)

      @user.picks << pick

      if !faved_nominee.nil?
        fav = Favourite.new
        fav.category = cat
        fav.nominee = faved_nominee
        @user.favourites << fav
      end
    end

    @user.picked = 1
    @user.save

    update_user_ranking()

    haml :picks, :cache => false
  end

  get '/nope' do
    return 'nope'
  end

  get '/admin' do
    requires_role :admin

    return 'admin'
  end

  get '/admin/lock/votes' do
    requires_role :admin
    @auth_user = get_authenticated_user()
    haml :lock_votes, :cache => false
  end

  post '/admin/lock/votes' do
    requires_role :admin
    @auth_user = get_authenticated_user()


    if params[:lock_votes] == 'lock_votes'
      lock_votes()
    else
      open_votes()
    end

    haml :lock_votes, :cache => false
  end

  get '/admin/update/winners' do
    requires_role :admin
    @auth_user = get_authenticated_user()
    @categories = Category.all
    haml :update_winners, :cache => false
  end

  post '/admin/update/winners' do
    requires_role :admin

    @auth_user = get_authenticated_user()
    @categories = Category.all
    @all_picked_users = User.all(:picked => 1)

    @categories.each do | cat |
      name_of_winner = params[cat.name.to_sym]
      if name_of_winner
        winner = cat.nominees.first(:name => name_of_winner)
        cat.winner = winner
      end
      cat.save
    end
    @categories.save

    update_user_ranking()

    haml :update_winners, :cache => false
  end
end
