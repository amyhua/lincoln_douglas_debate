class Resolution < ActiveRecord::Base
  attr_accessible :current, :description, :name
  validates :name, :presence => true
  validates_uniqueness_of :current, :if => :current
  has_many :cases, :dependent => :delete_all
end
