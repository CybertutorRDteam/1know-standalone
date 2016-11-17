class AdminAccount < ActiveRecord::Base
  validates :password, confirmation: true
  validates :account, :password_confirmation, presence: true
  validates_uniqueness_of :account, :message => "帳號已存在"
end