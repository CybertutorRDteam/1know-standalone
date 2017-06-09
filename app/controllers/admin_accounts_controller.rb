class AdminAccountsController < ApplicationController
	layout "admin"

	def index
		# check admin login
		@err = params[:err]
		if (!!session[:admin_id])
			if (session[:role] == "superadmin")
				redirect_to :controller => "admin_accounts", :action => "super_index"
			elsif (session[:role] == "sysadmin")
				redirect_to :controller => "admin_accounts", :action => "sys_index"
			else
				reset_session
			end
		end
	end

	def login
		require 'digest/sha1'
		#1. get account, passowrd
		#2. password SHA1 endcode
		#3. check data
		account = params[:account] || ''
		password = Digest::SHA1.hexdigest params[:password] || ''
		if (account != "" && password != "")
			#ischool super admin
				default_superAdmin = "cybertutor"
				default_superPwd = Digest::SHA1.hexdigest "Cyber3579"
				super_acc = Digest::SHA1.hexdigest account #"4354d98a10388a40c4e1de44bdcdba68a28b0bba"
				super_pwd = Digest::SHA1.hexdigest password #"ceb56bb9310f77171d3a69901cb2be1feae78a54"
				if (super_acc == Digest::SHA1.hexdigest(default_superAdmin) && super_pwd == Digest::SHA1.hexdigest(default_superPwd))
					session[:admin_id] = "super_Cybertutor"
					session[:admin_name] = "super Cybertutor"
					session[:role] = "superadmin"
					redirect_to :controller => "admin_accounts", :action => "super_index"
				else
					adminAccount = AdminAccount.where( :account => account, :password => password ).select("id, acc_name").take
					if (adminAccount.nil?)
						#redirect_to :action => "index"
						#redirect_to '/admin/index?err=Wrong id'
						redirect_to	action: 'index' , err: "错误的帐号或密码"
						#render	json: @msg={"err_msg" =>"wrong id or password"}
					else
						case APP_CONFIG['default_language']
						when 'zh-tw'
							lang = {title: '繁體中文', type: 'zh-tw'}
						when 'zh-cn'
							lang = {title: '简体中文', type: 'zh-cn'}
						when 'en-us'
							lang = {title: 'English', type: 'en-us'}
						else 'zh-cn'
							lang = {title: '简体中文', type: 'zh-cn'}
						end
						session[:admin_id] = adminAccount["id"]
						session[:admin_name] = adminAccount["acc_name"]
						session[:role] = "sysadmin"
						session[:userinfo] = {
							email: "service@dr-cloud.com",
							first_name: "admin",
							last_name: "admin",
							language: lang,
							account_type: "admin",
							userid: "admin@dr-cloud.com"
						}
						redirect_to :controller => "admin_accounts", :action => "sys_index"
					end
				end
		else	
			redirect_to :action => "index"
		end
	end

	def super_index
		if (session[:role] != "superadmin")
			redirect_to :controller => "admin_accounts", :action => "index"
		else
			@APP_CONFIG = APP_CONFIG
			render :layout => "manager", :text => ""
		end
	end

	def sys_index
		if (session[:role] != "sysadmin")
			redirect_to :controller => "admin_accounts", :action => "index"
		else
			@APP_CONFIG = APP_CONFIG
			render :layout => "manager", :text => ""
		end
	end

	def logout
		reset_session
		redirect_to :controller => "admin_accounts", :action => "index"
	end
end