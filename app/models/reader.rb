class Reader < ActiveRecord::Base
    self.table_name = 'reader'


    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id
    belongs_to :category, :class_name => 'UserReaderCategory', :foreign_key => :category_uqid

    # approve_code string (0)
    # category_uqid string (0)
    # hashtag string (0)
    # is_archived boolean
    # last_update datetime
    # rating integer
    # ref_know_id integer (8)
    # ref_user_id integer (8)
end
