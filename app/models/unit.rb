class Unit < ActiveRecord::Base
    self.table_name = 'unit'


    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id
    belongs_to :chapter, :class_name => 'Chapter', :foreign_key => :ref_chapter_id

    has_many :questions, -> { order "q_no ASC" }, :class_name => 'Question', :foreign_key => :ref_unit_id
    has_many :view_histories, :class_name => 'ViewHistory', :foreign_key => :ref_unit_id
    has_many :unit_statuses, :class_name => 'UnitStatus', :foreign_key => :ref_unit_id
    has_many :notes, :class_name => 'Note', :foreign_key => :ref_unit_id

	# content string (0)
	# content_time decimal
	# content_url string (0)
	# is_destroyed boolean
	# is_preview boolean
	# last_update datetime
	# name string (0)
	# priority integer
	# ref_chapter_id integer (8)
	# ref_know_id integer (8)
	# supplementary_description string (0)
	# unit_type string (0)
	# uqid string (32)
end
