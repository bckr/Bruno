class User
  include DataMapper::Resource
  property :id,             Serial
  property :uid,            String
  property :name,           Text
  property :picked,         Integer, :default => 0
  property :correct_picks,  Integer, :default => 0
  property :ranking,        Integer, :default => 1
  property :image_url,      Text,    :default => 'img/default_avatar.jpg'
  property :twitter_handle, String

  has n, :picks
  has n, :favourites
end

class Pick
  include DataMapper::Resource
  property :id,       Serial

  belongs_to :category
  belongs_to :nominee
  belongs_to :user

  def is_correct
    self.category.winner == self.nominee
  end

  def is_open
    self.category.winner == nil
  end
end

class Favourite
  include DataMapper::Resource
  property :id,       Serial

  belongs_to :category
  belongs_to :nominee
  belongs_to :user

  def is_correct
    self.category.winner == self.nominee
  end

  def is_open
    self.category.winner == nil
  end
end

class Category
  include DataMapper::Resource

  property :id,         Serial
  property :name,       Text

  has n, :nominees, :through => Resource
  has n, :picks
  has n, :favourites

  has 1, :winner_category
  has 1, :winner, 'Nominee', :through => :winner_category, via: :nominee
end

class Nominee
  include DataMapper::Resource

  property :id,       Serial
  property :name,     Text

  has n, :categories, :through => Resource
  has n, :picks
  has n, :favourites

  has n, :winner_categories
  has n, :won_categories, 'Category', :through => :winner_categories, via: :category
end

class WinnerCategory
  include DataMapper::Resource

  belongs_to :nominee, :key => true
  belongs_to :category, :key => true
end

class Preference
  include DataMapper::Resource

  property :id,     Serial
  property :name,   String
  property :status, Integer, :default => 0
end
