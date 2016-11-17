require "net/http"
require "net/https"
require "uuid"

class OauthController < ApplicationController
	def callback
		@params = {
			url: 'https://auth.ischoolcenter.com/oauth/authorize.php',
			client_id: APP_CONFIG['client_id'],
			redirect_uri: APP_CONFIG['redirect_uri'],
			response_type: 'code',
			state: 'ischool_authbug_code',
			scope: 'User.Mail,User.BasicInfo'
		}
	end

	def ischool
		uri = URI('https://auth.ischoolcenter.com/oauth/token.php')
		response = Net::HTTP.post_form(uri,
			'grant_type' => 'authorization_code',
			'code' => params[:code],
			'client_id' => APP_CONFIG['client_id'],
			'client_secret' => APP_CONFIG['client_secret'],
			'redirect_uri' => APP_CONFIG['redirect_uri']
		)
		token = JSON.parse(response.body)

		uri = URI("https://auth.ischoolcenter.com/services/me.php?access_token=#{token['access_token']}&token_type=bearer")
		result = Net::HTTP.get_response(uri)
		target = JSON.parse(result.body)
		
		if target['mail'] != nil and target['mail'] != ''
			domain = target['mail'].split('@')[1]

			if domain == 'ischool.com.tw'
				setLocalUser(target, 'ischool')
			else
				setLocalUser(target, '1know')
			end
		end

		state = params[:state].split(':')

		if state[0] == 'subscribe_knowledge'
			target = subscribe_knowledge(state[1])
			redirect_to target ? "/main/callback?target=knowledge:#{target.uqid}" : '/main/callback'
		elsif state[0] == 'subscribe_channel'
			target = subscribe_channel(state[1])
			redirect_to target ? "/main/callback?target=channel:#{target.uqid}" : '/main/callback'
		elsif state[0] == 'join_group'
			target = join_group(state[1])
			redirect_to target ? "//main/callback?target=group:#{target.uqid}" : '/main/callback'
		else
			redirect_to '/main/callback'
		end
	end

	private

	def setLocalUser(target, type)
		reset_session
		
		localUser = User.where(userid: target['mail'].downcase).first

		if localUser == nil
			user = User.new
			user.uqid = UUID.new.generate[0..7]
			user.userid = target['mail'].downcase
			user.first_name = target['firstName']
			user.last_name = target['lastName']
			user.banner = DEFAULT_USER_BANNER
			user.photo = DEFAULT_USER_PHOTO
			user.last_login_ip = request.remote_ip
			user.last_login_time = Time.now()
			user.create_time = Time.now()
			user.account_type = 'plus'
			user.nouser = false
			user.save()

			set_image('user', { uqid: user.uqid, banner: user.banner, photo: user.photo })

			gms = GroupMember.where(ref_email: user.userid, ref_user_id: nil)
			gms.each{|gm|
				gm.ref_user_id = user.id
				gm.sign_time = Time.now
				gm.save
			}

			localUser = user
		else
			localUser.last_login_time = Time.now()
			localUser.save()

			set_image('user', { uqid: localUser.uqid, banner: localUser.banner, photo: localUser.photo })
		end

		session[:userinfo] = {
			id: localUser.id,
			uqid: localUser.uqid,
			userid: localUser.userid,
			accountType: localUser.account_type,
			nouser: localUser.nouser,
			thirdParty: type
		}
		
		if localUser.language != nil
			begin
				lang = JSON.parse(localUser.language)
				session[:userinfo][:language] = {title: lang['title'], type: lang['type']}
			rescue => e
				session[:userinfo][:language] = {title: 'English', type: 'en-us'}
			end
		else
			session[:userinfo][:language] = {title: 'English', type: 'en-us'}
		end
	end

	def subscribe_knowledge(uqid)
		knowledge = Knowledge.where({uqid: uqid}).first
		
		if knowledge != nil and !knowledge.is_destroyed
			item = Reader.where(['ref_user_id = ? and ref_know_id = ?', session[:userinfo][:id], knowledge.id]).first
			
			if item != nil
				item.is_archived = false
				item.save()
			else
				item = Reader.new
				item.ref_user_id = session[:userinfo][:id]
				item.ref_know_id = knowledge.id
				item.approve_code = knowledge.code
				item.is_archived = false
				item.last_update = Time.now()
				item.save()
			end
		end

		return knowledge
	end

	def subscribe_channel(uqid)
		channel = Channel.where({uqid: uqid}).first
		
		if channel != nil
			cm = ChannelMember.where({ref_user_id: session[:userinfo][:id], ref_channel_id: channel.id}).first
			
			if cm == nil
				order = ChannelMember.where(ref_channel_id: channel.id).maximum('order')

				item = ChannelMember.new
				item.ref_channel_id = channel.id
				item.ref_user_id = session[:userinfo][:id]
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.order = order + 1
				item.role = 'member'
				item.status = 'approved'
				item.save()
			end
		end

		return channel
	end

	def join_group(uqid)
		group = Group.where({uqid: uqid}).first
		
		if group != nil
			gm = GroupMember.where({ref_user_id: session[:userinfo][:id], ref_group_id: group.id}).first

			if gm == nil
				order = GroupMember.where(ref_group_id: group.id).maximum('order')

				gm = GroupMember.new
				gm.ref_user_id = session[:userinfo][:id]
				gm.ref_group_id = group.id
				gm.uqid = UUID.new.generate.split('-')[0..1].join('')
				gm.status = group.is_public ? 'approved' : 'pending'
				gm.role = 'member'
				gm.order = (order == nil ? 1 : order + 1)
				gm.notification = true
				gm.sign_time = Time.now
				gm.save

				sender = User.find_by_sql(
					"select u.uqid, u.userid, u.first_name, u.last_name, u.nouser
					from \"user\" u
						join group_member gm on gm.ref_user_id = u.id
					where gm.ref_group_id = #{group.id} and gm.ref_user_id = #{session[:userinfo][:id]}").first
				sender_full_name = parse_full_name(sender.first_name, sender.last_name, sender.userid, sender.nouser)

				Thread.new do
					content =
						"<div style='width:640px'>
							<div style='padding:20px;border:1px solid #ddd;font-size:18px;background-color:#e5e5e5'>
								#{sender_full_name} 申请加入「<a href='#{request.protocol}#{request.host_with_port}/#!/join/group/#{group.uqid}' target='_blank'>#{group.name}</a>」群组
								<a href='http://1know.net' target='_blank'><img src='http://1know.net/icon.png' style='width:32px;height:32px;float:right'/></a>
							</div>
							<div style='min-height:72px;padding:20px;border-left:1px solid #ddd;border-right:1px solid #ddd'>
								<img style='float:left;width:72px;height:72px' src='#{get_image('user', { uqid: sender.uqid, nouser: sender.nouser, type: 'photo'})}'/>
								<div style='margin-left:88px'>
									<div>#{sender_full_name} 申请加入此群组</div>
									<div style='margin-top:8px'><a href='http://1know.net/user/#{sender.uqid}' target='_blank'>http://1know.net/user/#{sender.uqid}</a></div>
								</div>
							</div>
							<div style='padding:20px;border:1px solid #ddd;font-size:14px;color:#3a87ad'>
								你收到这封电子邮件是因为你在 1Know「<a href='#{request.protocol}#{request.host_with_port}/#!/join/group/#{group.uqid}' target='_blank'>#{group.name}</a>」群组中为管理者。
							</div>
						</div>"

					admin = User.find_by_sql(
						"select u.userid, u.first_name, u.last_name, u.nouser
						from \"user\" u
							join group_member gm on gm.ref_user_id = u.id
						where gm.ref_group_id = #{group.id} and gm.role = 'owner'").first

					if admin.userid.split('@')[1] != '1know.net'
						receiver_full_name = parse_full_name(admin.first_name, admin.last_name, admin.userid, admin.nouser)

						mail = Mail.deliver do
							charset = "UTF-8"

							subject "1Know「#{group.name}」群组中有使用者申请加入!"
							from    "#{sender_full_name} (1Know)<notify@1know.net>"
							to      "#{receiver_full_name}<#{admin.userid}>"

							text_part do
								body content
							end

							html_part do
								content_type 'text/html; charset=UTF-8'
								body content
							end
						end
					end
				end
			end
		end

		return group
	end
end
