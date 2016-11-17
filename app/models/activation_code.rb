class ActivationCode < ActiveRecord::Base
  validates :code, :permission_name, :role, :duration, presence: true
  validates_uniqueness_of :code, :message => "啟動碼必須是唯一值"

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      # csv << column_names
      columns = %w(code role user_id activation_time duration)
      csv << columns
      all.each do |row|
        # csv << row.attributes.values_at(*column_names)
        csv << row.attributes.values_at(*columns)
      end
    end
  end
end
