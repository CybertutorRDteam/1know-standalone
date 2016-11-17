class Category < ActiveRecord::Base
    self.table_name = 'category'


    belongs_to :channel, :class_name => 'Channel', :foreign_key => :ref_channel_id
    belongs_to :category, :class_name => 'Category', :foreign_key => :ref_category_id
    
    has_many :categories, -> { order "priority ASC" }, :class_name => 'Category', :foreign_key => :ref_category_id
    has_many :knowledges, -> { order "priority ASC" }, :class_name => 'CategoryKnowledge', :foreign_key => :ref_category_id

	# logo string (0)
	# name string (0)
	# priority integer
	# ref_category_id integer (8)
	# ref_channel_id integer (8)
	# uqid string (32)
end