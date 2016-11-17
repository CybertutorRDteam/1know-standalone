class DraftQuestion < ActiveRecord::Base
    self.table_name = 'draft_question'


    belongs_to :unit, :class_name => 'DraftUnit', :foreign_key => :ref_unit_id

	# answer string (0)
	# content string (0)
	# content_ext string (0)
	# explain string (0)
	# explain_url string (0)
	# options string (0)
	# q_no integer
	# q_type string (0)
	# ref_unit_id integer (8)
	# release_time datetime
	# solution string (0)
	# uqid string (32)
	# video_time decimal
end
