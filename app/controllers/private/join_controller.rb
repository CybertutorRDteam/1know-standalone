require "net/http"
require "uuid"
require "mail"
require "oj"

class Private::JoinController < ApplicationController
	before_filter :check_session

	def list_all_group
		keyword = params[:keyword] != nil ? "and lower(g.name) like lower('%#{params[:keyword]}%')" : ""

		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20

		offset = "offset #{start_index} limit #{max_results}"
		offset = '' if keyword != ''

		items = Group.find_by_sql(
			"select g.*
			from \"group\" g
			where g.is_public = true and g.is_destroyed = false #{keyword}
			order by g.last_update desc
			#{offset}")

		content = []
		items.each {|item|
			knowledges = GroupKnowledge.where(ref_group_id: item.id, is_show: true)
			members = GroupMember.where(ref_group_id: item.id, status: 'approved')

			content.push({
				uqid: item.uqid,
				name: item.name,
				knowledge_size: knowledges.size,
				member_size: members.size,
				last_update: item.last_update,
				privacy: item.is_public,
				code: item.code,
				logo: get_image('group', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/group/#{item.uqid}"
			})
		}

		render :json => content
	end

	def list_group
		condition = "where gm.status = 'approved' and gm.ref_user_id = #{session[:userinfo][:id]}"
		condition ="#{condition} and g.uqid = '#{params[:groupUqid]}'" if params[:groupUqid] != nil

		items = Group.find_by_sql(
			"select g.*, gm.uqid gm_uqid, gm.role gm_role, gm.notification gm_notification
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			#{condition} and g.is_destroyed = false
			order by gm.last_view_time desc")

		if params[:groupUqid] == nil
			content = []
			items.each {|item|
				messages = GroupMessage.find_by_sql(
					"select gms.id
					from group_message gms
						join group_member gm on gm.ref_group_id = gms.ref_group_id and gm.ref_user_id = #{session[:userinfo][:id]}
					where gms.ref_group_id = #{item.id} and gms.publish_time > gm.last_view_time").size

				owner = User.find_by_sql(
					"select u.uqid, u.userid, u.first_name, u.last_name, u.account_type, u.nouser
					from \"user\" u
						join group_member gm on gm.ref_user_id = u.id
					where gm.role = 'owner' and gm.ref_group_id = #{item.id}").first

				knowledges = GroupKnowledge.where(ref_group_id: item.id, is_show: true)
				members = GroupMember.where(ref_group_id: item.id, status: 'approved')

				content.push({
					uqid: item.uqid,
					name: item.name,
					knowledge_size: knowledges.size,
					member_size: members.size,
					message: messages,
					privacy: item.is_public,
					code: item.code,
					owner: {
						uqid: owner.uqid,
						email: owner.userid,
						first_name: owner.first_name,
						last_name: owner.last_name,
						account_type: owner.account_type,
						nouser: owner.nouser
					},
					me: {
						uqid: item.gm_uqid,
						role: item.gm_role,
						notification: item.gm_notification
					},
					logo: get_image('group', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/group/#{item.uqid}"
				})
			}

			render :json => content
		elsif params[:groupUqid] != nil and items.size == 1
			item = items[0]

			behavior = GroupMemberBehavior.find_by_sql(
				"select sum(case when gmb.points > 0 then 1 else 0 end) positive,
					sum(case when gmb.points < 0 then 1 else 0 end) negative, count(gmb.id) count
				from group_member_behavior gmb
				where gmb.ref_user_id = #{session[:userinfo][:id]} and gmb.ref_group_id = #{item.id}").first

			owner = User.find_by_sql(
				"select u.uqid, u.userid, u.first_name, u.last_name, u.account_type, u.nouser
				from \"user\" u
					join group_member gm on gm.ref_user_id = u.id
				where gm.role = 'owner' and gm.ref_group_id = #{item.id}").first

			members = User.find_by_sql(
				"select u.userid, u.uqid, u.first_name, u.last_name, u.nouser, gm.role, gm.status
				from \"user\" u
					join group_member gm on gm.ref_user_id = u.id
				where gm.ref_group_id = #{item.id} and gm.status = 'approved'
				order by gm.last_view_time desc nulls last, gm.sign_time desc
				limit 24")

			member = []
			members.each {|item|
				member.push({
					uqid: item.uqid,
					email: item.userid,
					photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
				})
			}

			ActiveRecord::Base.connection.execute(
				"update group_member set last_view_time = now()
				where ref_user_id = #{session[:userinfo][:id]} and ref_group_id = #{item.id}")

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				knowledge_size: item.knowledges.size,
				member_size: item.members.size,
				member: member,
				privacy: item.is_public,
				code: item.code,
				owner: {
					uqid: owner.uqid,
					email: owner.userid,
					first_name: owner.first_name,
					last_name: owner.last_name,
					account_type: owner.account_type,
					nouser: owner.nouser
				},
				me: {
					uqid: item.gm_uqid,
					role: item.gm_role,
					notification: item.gm_notification,
					behavior: {
						positive: behavior.positive,
						negative: behavior.negative,
						total: ((behavior.positive != nil and behavior.negative != nil) ? (behavior.positive - behavior.negative) : 0),
						count: behavior.count
					}
				},
				file: item.file == nil ? [] : JSON.parse(item.file),
				link: item.link == nil ? [] : JSON.parse(item.link),
				logo: get_image('group', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/group/#{item.uqid}"
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def create_group
		item = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'	and gm.ref_user_id = #{session[:userinfo][:id]} and g.is_destroyed = false")

		user = User.where(id: session[:userinfo][:id]).first

		if user.account_type == 'free' and item.size >= 1
			render :json => { error: 'Free 帐号只能建立1个群组，如需建立更多群组，建议升级至 Plus or Pro 帐号!' }
		elsif user.account_type == 'plus' and item.size >= 10
			render :json => { error: 'Plus 帐号只能建立10个群组，如需建立更多群组，建议升级至 Pro 帐号!' }
		elsif user.account_type == 'pro' and item.size >= 30
			render :json => { error: 'Pro 帐号只能建立30个群组，如需建立更多群组，烦请联络客服人员，我们将提供更多的折扣!' }
		else
			params[:name] = "New Group" if params[:name] == nil or params[:name] == ''

			item = Group.new
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description] != nil
			item.logo = params[:logo] != nil ? params[:logo] : DEFAULT_LOGO
			item.is_public = params[:privacy] != nil ? params[:privacy] : false
			item.content = params[:content] if params[:content] != nil
			item.is_destroyed = false
			item.last_update = Time.now()
			item.save()

			set_image('group', { uqid: item.uqid, logo: item.logo })

			gm = GroupMember.new
			gm.uqid = UUID.new.generate.split('-')[0..1].join('')
			gm.ref_user_id = session[:userinfo][:id]
			gm.ref_group_id = item.id
			gm.status = 'approved'
			gm.role = 'owner'
			gm.order = 1
			gm.notification = true
			gm.sign_time = Time.now()
			gm.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				last_update: item.last_update,
				privacy: item.is_public,
				code: item.code,
				logo: item.logo
			}

			render :json => content
		end
	end

	def update_group
		item = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if item != nil
			item.name = params[:name] if params[:name] and params[:name] != ''
			item.description = params[:description].gsub('/<(.|script)*?>/', '') if params[:description]
			item.logo = params[:logo] if params[:logo]
			item.is_public = params[:privacy] if params[:privacy] != nil
			item.content = params[:content] if params[:content] != nil
			item.last_update = Time.now
			item.save()

			set_image('group', { uqid: item.uqid, logo: item.logo })

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				privacy: item.is_public,
				code: item.code,
				content: item.content == nil ? [] : JSON.parse(item.content),
				last_update: item.last_update,
				logo: item.logo
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_group
		item = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if item != nil
			item.uqid = [item.uqid, '-destroyed'].join('')
			item.code = nil
			item.is_public = false
			item.is_destroyed = true
			item.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def reset_group_code
		item = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if item != nil
			item.code = UUID.new.generate[0..5].upcase
			item.last_update = Time.now
			item.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				privacy: item.is_public,
				code: item.code,
				content: item.content == nil ? [] : JSON.parse(item.content),
				last_update: item.last_update,
				logo: item.logo
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def join_group
		group = Group.where(code: params[:groupCode].upcase).first

		if group != nil
			gm = GroupMember.where(['ref_user_id = ? and ref_group_id = ?', session[:userinfo][:id], group.id]).first

			if gm == nil
				order = GroupMember.where(ref_group_id: group.id).maximum('order')

				gm = GroupMember.new
				gm.uqid = UUID.new.generate.split('-')[0..1].join('')
				gm.ref_user_id = session[:userinfo][:id]
				gm.ref_group_id = group.id
				gm.status = 'approved'
				gm.role = 'member'
				gm.order = (order == nil ? 1 : order + 1)
				gm.notification = true
				gm.sign_time = Time.now
				gm.save
			else
				gm.status = 'approved'
				gm.save
			end

			render :json => { uqid: group.uqid, name: group.name }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def request_to_join
		group = Group.where(['uqid = ?', params[:groupUqid]]).first

		if group != nil
			gm = GroupMember.where(['ref_user_id = ? and ref_group_id = ?', session[:userinfo][:id], group.id]).first

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

				render :json => group.is_public ? { success: "Well done!" } : { error: '等待审核中!' }
			elsif gm.status == 'pending'
				render :json => { error: '等待审核中!' }
			else
				render :json => { error: '已加入群组!' }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def leave_group
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			gm = GroupMember.where(['ref_user_id = ? and ref_group_id = ?', session[:userinfo][:id], group.id]).first
			gm.destroy if gm != nil and gm.role != 'owner'

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_message
		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20

		offset = "offset #{start_index} limit #{max_results}"
		condition = params[:top] == "true" ? "and gm.is_top = true" : "and (gm.is_top is null or gm.is_top = false)"

		items = GroupMessage.find_by_sql(
			"select gm.*, u.uqid user_uqid, u.userid, u.first_name, u.last_name, u.nouser, un.uqid u_uqid, un.name u_name, un.content_url u_content_url, k.uqid k_uqid, k.name k_name
			from group_message gm
				join \"group\" g on g.id = gm.ref_group_id
				join \"user\" u on u.id = gm.ref_user_id
				left join unit un on un.id = gm.ref_unit_id
				left join knowledge k on k.id = un.ref_know_id
			where g.uqid = '#{params[:groupUqid]}'
				and gm.ref_message_id is null
				#{condition}
			order by gm.publish_time desc
			#{offset}")

		content = []
		items.each {|item|
			messages = GroupMessage.find_by_sql(
				"select gm.*, u.uqid u_uqid, u.userid, u.first_name, u.last_name, u.nouser
				from group_message gm
					join \"group\" g on g.id = gm.ref_group_id
					join \"user\" u on u.id = gm.ref_user_id
				where g.uqid = '#{params[:groupUqid]}' and gm.ref_message_id = #{item.id}
				order by gm.publish_time asc")

			message = []
			messages.each {|msg|
				message.push({
					uqid: msg.uqid,
					content: msg.content,
					publisher: {
						uqid: msg.u_uqid,
						email: msg.userid,
						first_name: msg.first_name,
						last_name: msg.last_name,
						full_name: parse_full_name(msg.first_name, msg.last_name, msg.userid, msg.nouser),
						nouser: msg.nouser,
						photo: get_image('user', { uqid: msg.u_uqid, nouser: msg.nouser, type: 'photo' }),
						page: "#{request.protocol}#{request.host_with_port}/user/#{msg.u_uqid}"
					},
					publish_time: msg.publish_time,
					like: GroupMessageLike.where(ref_message_id: msg.id).size
				})
			}

			message = {
				uqid: item.uqid,
				content: item.content.gsub(/<a/, "<a target='_blank'"),
				publisher: {
					uqid: item.user_uqid,
					email: item.userid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					nouser: item.nouser,
					photo: get_image('user', { uqid: item.user_uqid, nouser: item.nouser, type: 'photo' }),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.user_uqid}"
				},
				publish_time: item.publish_time,
				like: GroupMessageLike.where(ref_message_id: item.id).size,
				message: message
			}

			if item.u_uqid != nil
				message[:note] = {
					time: item.note_time.to_f,
					content_url: item.u_content_url,
					u_uqid: item.u_uqid,
					u_name: item.u_name,
					k_uqid: item.k_uqid,
					k_name: item.k_name
				}
			end

			content.push(message)
		}

		render :json => content
	end

	def add_message
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			message = GroupMessage.where(uqid: params[:message_uqid]).first if params[:message_uqid] != nil
			sender = User.find_by_sql(
				"select u.uqid, u.userid, u.first_name, u.last_name, u.nouser
				from \"user\" u
					join group_member gm on gm.ref_user_id = u.id
				where gm.ref_group_id = #{group.id} and gm.ref_user_id = #{session[:userinfo][:id]}").first

			if sender != nil and params[:content] != nil
				item = GroupMessage.new
				item.ref_group_id = group.id
				item.ref_user_id = session[:userinfo][:id]
				item.ref_message_id = message.id if message != nil
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.content = params[:content]
				item.publish_time = Time.now

				if params[:unitUqid]
					unit = Unit.select('id').where(uqid: params[:unitUqid]).first

					item.ref_unit_id = unit.id
					item.note_time = params[:noteTime]
				end

				item.save()

				sender_full_name = parse_full_name(sender.first_name, sender.last_name, sender.userid, sender.nouser)

				Thread.new do
					content =
						"<div style='width:640px'>
							<div style='padding:20px;border:1px solid #ddd;font-size:18px;background-color:#e5e5e5'>
								#{sender_full_name} 在「<a href='#{request.protocol}#{request.host_with_port}/#!/join/group/#{group.uqid}' target='_blank'>#{group.name}</a>」中分享了一则讯息
								<a href='http://1know.net' target='_blank'><img src='http://1know.net/icon.png' style='width:32px;height:32px;float:right'/></a>
							</div>
							<div style='min-height:72px;padding:20px;border-left:1px solid #ddd;border-right:1px solid #ddd'>
								<img style='float:left;width:72px;height:72px' src='#{get_image('user', { uqid: sender.uqid, nouser: sender.nouser, type: 'photo'})}'/>
								<div style='margin-left:88px'>
									<div>#{sender_full_name} 张贴了讯息：</div>
									<p>#{item.content}</p>
								</div>
							</div>
							<div style='padding:20px;border:1px solid #ddd;font-size:14px;color:#3a87ad'>
								你收到这封电子邮件是因为你在 1Know 订阅了「<a href='#{request.protocol}#{request.host_with_port}/#!/join/group/#{group.uqid}' target='_blank'>#{group.name}</a>」群组。
							</div>
						</div>"

					members = User.find_by_sql(
						"select u.userid, u.first_name, u.last_name, u.nouser
						from \"user\" u
							join group_member gm on gm.ref_user_id = u.id
						where gm.ref_group_id = #{group.id} and gm.notification = true and gm.status = 'approved'")

					members.each {|member|
						if member.userid.split('@')[1] != '1know.net'
							receiver_full_name = parse_full_name(member.first_name, member.last_name, member.userid, member.nouser)

							mail = Mail.deliver do
								charset = "UTF-8"

								subject "1Know「#{group.name}」群组中有新讯息!"
								from    "#{sender_full_name} (1Know)<notify@1know.net>"
								to      "#{receiver_full_name}<#{member.userid}>"

								text_part do
									body content
								end

								html_part do
									content_type 'text/html; charset=UTF-8'
									body content
								end
							end
						end
					}
				end

				render :json => { uqid: item.uqid, content: item.content }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_message
		message = GroupMessage.find_by_sql(
			"select gms.*
			from group_message gms
				left join \"group\" g on g.id = gms.ref_group_id
				left join group_member gm on g.id = gm.ref_group_id
			where g.uqid = '#{params[:groupUqid]}' and gms.uqid = '#{params[:messageUqid]}'
				and gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and (gm.role in ('owner', 'admin') or gms.ref_user_id = #{session[:userinfo][:id]})").first

		if message != nil
			message.destroy
			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def like_message
		message = GroupMessage.find_by_sql(
			"select gms.*
			from group_message gms
				left join \"group\" g on g.id = gms.ref_group_id
				left join group_member gm on g.id = gm.ref_group_id
			where g.uqid = '#{params[:groupUqid]}'
				and gms.uqid = '#{params[:messageUqid]}'
				and gm.ref_user_id = #{session[:userinfo][:id]}").first

		if message != nil
			item = GroupMessageLike.where(ref_user_id: session[:userinfo][:id], ref_message_id: message.id).first

			if item == nil
				item = GroupMessageLike.new
				item.ref_user_id = session[:userinfo][:id]
				item.ref_message_id = message.id
				item.save()

				render :json => { like: GroupMessageLike.where(ref_message_id: message.id).size }
			else
				item.destroy

				render :json => { like: GroupMessageLike.where(ref_message_id: message.id).size }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def top_message
		message = GroupMessage.find_by_sql(
			"select gms.*
			from group_message gms
				left join \"group\" g on g.id = gms.ref_group_id
				left join group_member gm on g.id = gm.ref_group_id
			where g.uqid = '#{params[:groupUqid]}'
				and gms.uqid = '#{params[:messageUqid]}'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}").first

		if message != nil
			message.is_top = message.is_top == true ? false : true
			message.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_activity
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			if group.role != 'member'
				items = GroupActivity.find_by_sql(
					"select ga.id gaid, ga.uqid, ga.name, ga.description, ga.goal, ga.is_show, ga.priority, ga.tag
					from group_activity ga
						join \"group\" g on g.id = ga.ref_group_id
					where g.uqid = '#{params[:groupUqid]}'
					order by ga.tag nulls first, ga.priority")

				content = []
				items.each{|item|
					goal = JSON.parse(item.goal)
					uqid = []
					goal.each{|u| uqid.push(u['unit']['uqid']) }

					units = Unit.find_by_sql("select uqid, name, unit_type, content_url, content_time from unit where uqid in ('#{uqid.join("', '")}')")
					units.each{|u|
						goal.each{|g|
							if u.uqid === g['unit']['uqid']
								g['unit']['unit_type'] = u.unit_type
								g['unit']['content_url'] = u.content_url
								g['unit']['content_time'] = u.content_time
							end
						}
					}
					content.push({
						uqid: item.uqid,
						name: item.name,
						description: item.description,
						is_show: item.is_show,
						priority: item.priority,
						goal: goal,
						tag: item.tag || ''
					})
				}
			else
				items = GroupActivity.find_by_sql(
					"select ga.id gaid, ga.uqid, ga.name, ga.description, ga.goal, ga.is_show, ga.priority, ga.tag
					from group_activity ga
						join \"group\" g on g.id = ga.ref_group_id
					where g.uqid = '#{params[:groupUqid]}' and ga.is_show = true
					order by ga.tag nulls first, ga.priority")

				content = []
				items.each{|item|
					goal = JSON.parse(item.goal)
					uqid = []
					goal.each{|u| uqid.push(u['unit']['uqid']) }

					finished_count = 0
					units = Unit.find_by_sql(
						"select un.uqid, un.name, un.unit_type, us.status, us.gained, us.total, us.last_view_time, un.content, un.content_url
						from ( select * from group_member where ref_user_id = #{session[:userinfo][:id]} and ref_group_id = #{group.id}) as gm
							left join unit_status as us on us.ref_user_id = gm.ref_user_id
							inner join unit as un on un.id = us.ref_unit_id
						where un.uqid in ('#{uqid.join("', '")}')")
					units.each{|u| finished_count += 1 if u.status == 4}

					content.push({
						uqid: item.uqid,
						name: item.name,
						description: item.description,
						is_show: item.is_show,
						priority: item.priority,
						progress: (finished_count / goal.size.to_f * 100).round(2),
						tag: item.tag || ''
					})
				}
			end

			render :json => content
		else
			render :json => []
		end
	end

	def add_activity
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			priority = GroupActivity.where(ref_group_id: group.id).maximum('priority')

			item = GroupActivity.new
			item.ref_group_id = group.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name] if params[:name]
			item.description = params[:description] if params[:description]
			item.priority = (priority == nil ? 1 : priority + 1)
			item.goal = params[:goal] if params[:goal] != nil
			item.tag = params[:tag] if params[:tag] != nil
			item.tag = nil if params[:tag] == ''
			item.is_show = false
			item.save()

			if params[:priority] != nil
				priority = params[:priority].to_i

				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update group_activity set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_group_id = #{item.ref_group_id}")
				else
					ActiveRecord::Base.connection.execute(
						"update group_activity set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_group_id = #{item.ref_group_id}")
				end

				item.priority = priority
				item.save()
			end

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				goal: JSON.parse(item.goal),
				tag: item.tag || ''
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_activity
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			if params[:priority] != nil
				priority = params[:priority].to_i

				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update group_activity set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_group_id = #{item.ref_group_id}")
				else
					ActiveRecord::Base.connection.execute(
						"update group_activity set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_group_id = #{item.ref_group_id}")
				end

				item.priority = priority
				item.save()
			end

			item.name = params[:name] if params[:name]
			item.description = params[:description] if params[:description]
			item.goal = params[:goal] if params[:goal] != nil
			item.tag = params[:tag] if params[:tag] != nil
			item.tag = nil if params[:tag] == ''
			item.is_show = (params[:is_show] == true ? true : false) if params[:is_show] != nil
			item.save()

			content = {
				uqid: item.uqid,
				name: item.name,
				description: item.description,
				goal: JSON.parse(item.goal),
				tag: item.tag || ''
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_activity
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:itemUqid]}'").first

		if item != nil
			ActiveRecord::Base.connection.execute(
				"update group_activity set priority = priority - 1
				where priority > #{item.priority} and ref_group_id = #{item.ref_group_id}")

			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def import_activity
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			params[:activities].each{|target|
				priority = GroupActivity.where(ref_group_id: group.id).maximum('priority')

				item = GroupActivity.new
				item.ref_group_id = group.id
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.name = target[:name] if target[:name]
				item.description = target[:description] if target[:description]
				item.priority = (priority == nil ? 1 : priority + 1)
				item.goal = target[:goal] if target[:goal] != nil
				item.is_show = false
				item.save()

				if params[:priority] != nil
					priority = params[:priority].to_i

					if priority > item.priority
						ActiveRecord::Base.connection.execute(
							"update group_activity set priority = priority - 1
							where priority > #{item.priority} and priority <= #{priority} and ref_group_id = #{item.ref_group_id}")
					else
						ActiveRecord::Base.connection.execute(
							"update group_activity set priority = priority + 1
							where priority < #{item.priority} and priority >= #{priority} and ref_group_id = #{item.ref_group_id}")
					end

					item.priority = priority
					item.save()
				end
			}

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_activity_statistics
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:itemUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil and item != nil
			goal = JSON.parse(item.goal)
			uqid = []
			goal.each{|u| uqid.push(u['unit']['uqid']) }

			members = User.find_by_sql(
				"select u.uqid user_uqid, u.userid, u.first_name, u.last_name, u.nouser, u.gm_uqid, u.role, gmb.behavior_points,
					array_agg(un.uqid) status_unit_uqid, array_agg(un.name) as name, array_agg(un.status) status, array_agg(un.gained) gained_time, array_agg(un.last_view_time) last_view_time,
					array_agg(uf.uqid) feedback_unit_uqid, array_agg(uf.uf_uqid) feedback_uqid, array_agg(uf.score) score, array_agg(uf.comment||' ') as comment,
					array_agg(b.uqid) note_unit_uqid, array_agg(b.note_size) note_size
				from (select u.id, u.uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.uqid gm_uqid, gm.role, gm.order
					from \"user\" u join group_member gm on u.id = gm.ref_user_id
					where gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved' and gm.role = 'member' order by gm.order) as u
				left join (select sum(points) behavior_points, ref_user_id
					from group_member_behavior
					where ref_group_id = #{item.ref_group_id}
					group by ref_user_id) as gmb on gmb.ref_user_id = u.id
				left join (select un.id, us.ref_user_id, un.uqid, un.name, us.status, us.gained, us.last_view_time
					from unit un
					left join unit_status us on us.ref_unit_id = un.id
					where un.uqid in ('#{uqid.join("', '")}')) as un on un.ref_user_id = u.id
				left join (select un.uqid, uf.uqid uf_uqid, uf.score, uf.comment, uf.ref_user_id, uf.ref_unit_id
					from unit un
					left join unit_feedback uf on uf.ref_unit_id = un.id and uf.ref_group_id = #{group.id}
					where un.uqid in ('#{uqid.join("', '")}')) as uf on uf.ref_unit_id = un.id and uf.ref_user_id = u.id
				left join (select count(b.id) note_size, b.ref_unit_id, b.ref_user_id, un.uqid
					from bookmark b
					left join unit un on un.id = b.ref_unit_id
					where un.uqid in ('#{uqid.join("', '")}')
					group by b.ref_unit_id, b.ref_user_id, un.uqid) as b on b.ref_unit_id = un.id and b.ref_user_id = u.id
				group by u.uqid, u.userid, u.first_name, u.last_name, u.nouser, u.gm_uqid, u.role, u.order, gmb.behavior_points
				order by u.order")

			content = []
			members.each{|member|
				data = {
					item_uqid: member.gm_uqid,
					user_uqid: member.user_uqid,
					email: member.userid,
					first_name: member.first_name,
					last_name: member.last_name,
					full_name: parse_full_name(member.first_name, member.last_name, member.userid, member.nouser),
					nouser: member.nouser,
					role: member.role,
					photo: get_image('user', { uqid: member.user_uqid, nouser: member.nouser, type: 'photo' }),
					total_unit: goal.size,
					behavior_points: member.behavior_points,
					status: {
						unit_uqid: member.status_unit_uqid,
						status: member.status,
						gained_time: member.gained_time,
						last_view_time: member.last_view_time
					},
					note: {
						unit_uqid: member.note_unit_uqid,
						note_size: member.note_size
					},
					feedback: {
						unit_uqid: member.feedback_unit_uqid,
						feedback_uqid: member.feedback_uqid,
						score: member.score,
						comment: member.comment
					}
				}

				content.push(data)
			}

			render :json => Oj.dump(content)
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_activity_unit_result
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:activityUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		unit = Unit.where(uqid: params[:itemUqid]).first

		if item != nil and unit != nil
			quizzes = []
			if unit.unit_type == 'quiz'
				unit.questions.each {|item|
					begin
						options = JSON.parse(item.options)
					rescue => e
						options = []
					end

					quizzes.push({
						uqid: item.uqid,
						quiz_no: item.q_no.to_i,
						quiz_type: item.q_type,
						content: item.content,
						options: options,
						answer: item.answer
					})
				}
			end

			users = User.find_by_sql(
				"select u.uqid, u.first_name, u.last_name, u.userid, u.nouser
				from \"user\" u
					left join group_member gm on gm.ref_user_id = u.id
				where gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved' and gm.role = 'member'
				order by gm.order")

			items = StudyResult.find_by_sql(
				"select u.uqid, sr.content
				from study_result sr
					left join \"user\" u on u.id = sr.ref_user_id
				where sr.ref_unit_id = #{unit.id}")

			content = []
			users.each{|item|
				content.push({
					uqid: item.uqid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					result: nil
				})
			}
			content.each{|u|
				items.each{|i|
					if u[:uqid] == i.uqid
						if i.content != nil
							u[:result] = JSON.parse(i.content) if ['quiz', 'draw'].include?(unit.unit_type)
							u[:result] = JSON.parse(i.content)['result'] if ['poll', 'qa'].include?(unit.unit_type)
						end
					end
				}
			}

			render :json => {
				unit: {
					uqid: unit.uqid,
					name: unit.name,
					unit_type: unit.unit_type,
					content: unit.content != nil ? (['poll', 'draw'].include?(unit.unit_type) ? JSON.parse(unit.content) : unit.content) : nil,
					content_url: unit.content_url,
					content_time: unit.content_time.to_f,
					quizzes: quizzes,
					knowledge: { uqid: unit.knowledge.uqid, name: unit.knowledge.name }
				},
				user: content
			}
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_activity_unit_result_export
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:activityUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		unit = Unit.where(uqid: params[:itemUqid]).first

		if item != nil and unit != nil and unit.unit_type == 'quiz'
			users = User.find_by_sql(
				"select u.uqid, u.first_name, u.last_name, u.userid, u.nouser
				from \"user\" u
					left join group_member gm on gm.ref_user_id = u.id
				where gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved' and gm.role = 'member'
				order by gm.order")

			items = StudyResult.find_by_sql(
				"select u.uqid, sr.content
				from study_result sr
					left join \"user\" u on u.id = sr.ref_user_id
				where sr.ref_unit_id = #{unit.id}")

			content = []
			users.each{|item|
				content.push({
					uqid: item.uqid,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					result: nil
				})
			}
			content.each{|u|
				items.each{|i|
					if u[:uqid] == i.uqid
						if i.content != nil
							u[:result] = JSON.parse(i.content) if ['quiz', 'draw'].include?(unit.unit_type)
							u[:result] = JSON.parse(i.content)['result'] if ['poll', 'qa'].include?(unit.unit_type)
						end
					end
				}
			}

			export = []
			row = ['']
			unit.questions.each_with_index{|q, i|
				row.push(", #{i+1}")
			}
			export.push(row.join(''))

			content.each{|item|
				row = ["#{item[:full_name]}"]
				unit.questions.each{|q|
					if item[:result] and item[:result]['result']
						item[:result]['result'].each{|r|
							if q.uqid == r['uqid']
								row.push(", #{r['correct'][0]==r['answer'][0] ? 'V' : ' '}")
							end
						}
					else
						row.push(", ")
					end
				}
				export.push(row.join(''))
			}

			send_data export.join("\r\n"), :filename => "#{unit.name}.csv"
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_activity_unit_member_note
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:activityUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		unit = Unit.where(uqid: params[:itemUqid]).first

		if item != nil and unit != nil
			quizzes = []
			if unit.unit_type == 'quiz'
				unit.questions.each {|item|
					begin
						options = JSON.parse(item.options)
					rescue => e
						options = []
					end

					quizzes.push({
						uqid: item.uqid,
						quiz_no: item.q_no.to_i,
						quiz_type: item.q_type,
						content: item.content,
						options: options,
						answer: item.answer
					})
				}
			end

			users = User.find_by_sql(
				"select u.uqid, u.first_name, u.last_name, u.userid, u.nouser
				from \"user\" u
					left join group_member gm on gm.ref_user_id = u.id
				where gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved' and gm.role = 'member'
				order by gm.order")

			items = Note.find_by_sql(
				"select u.uqid, b.content_type, b.content_color, b.video_time, b.content
				from bookmark b
					join unit un on un.id = b.ref_unit_id
					join \"user\" u on u.id = b.ref_user_id
					join group_member gm on gm.ref_user_id = u.id
				where un.uqid = '#{unit.uqid}' and gm.role = 'member' and gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved'
				order by gm.order, b.video_time")

			content = []
			users.each{|item|
				content.push({
					uqid: item.uqid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					notes: []
				})
			}
			content.each{|u|
				items.each{|i|
					if u[:uqid] == i.uqid
						u[:notes].push({
							type: i.content_type,
							time: i.video_time.to_i,
							content: i.content,
							color: i.content_color
						})
					end
				}
			}

			render :json => {
				unit: {
					uqid: unit.uqid,
					name: unit.name,
					unit_type: unit.unit_type,
					content: unit.content != nil ? (['poll', 'draw'].include?(unit.unit_type) ? JSON.parse(unit.content) : unit.content) : nil,
					content_url: unit.content_url,
					content_time: unit.content_time.to_f,
					quizzes: quizzes,
					knowledge: { uqid: unit.knowledge.uqid, name: unit.knowledge.name }
				},
				user: content
			}
		else
			render :json => []
		end
	end

	def get_activity_unit_member_history
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:activityUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		unit = Unit.where(uqid: params[:itemUqid]).first

		if item != nil and unit != nil
			items = ViewHistory.find_by_sql(
				"select u.uqid, u.first_name, u.last_name, u.userid, u.nouser, us.status, u.seconds
				from (select u.id, u.uqid, u.first_name, u.last_name, u.userid, u.nouser, sum(vh.seconds_watched) seconds
					from view_history vh
						join \"user\" u on u.id = vh.ref_user_id
						join group_member gm on gm.ref_user_id = u.id
					where vh.ref_unit_id = '#{unit.id}' and gm.role = 'member' and gm.ref_group_id = #{item.ref_group_id} and gm.status = 'approved'
					group by u.id, u.uqid, u.first_name, u.last_name, u.userid, u.nouser
				) as u join (select ref_user_id, status from unit_status where ref_unit_id = #{unit.id}) us on us.ref_user_id = u.id")

			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					seconds: item.seconds.to_i,
					status: item.status
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def get_activity_unit_member_result
		item = GroupActivity.find_by_sql(
			"select ga.*
			from group_activity ga
				join group_member gm on gm.ref_group_id = ga.ref_group_id
				join \"group\" g on g.id = ga.ref_group_id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and ga.uqid = '#{params[:activityUqid]}'
				and g.uqid = '#{params[:groupUqid]}'").first

		unit = Unit.where(uqid: params[:itemUqid]).first
		user = User.where(uqid: params[:memberUqid]).first

		if item != nil and unit != nil and user != nil
			quizzes = []
			if unit.unit_type == 'quiz'
				unit.questions.each {|item|
					begin
						options = JSON.parse(item.options)
					rescue => e
						options = []
					end

					quizzes.push({
						uqid: item.uqid,
						quiz_no: item.q_no.to_i,
						quiz_type: item.q_type,
						content: item.content,
						options: options,
						answer: item.answer
					})
				}
			end

			notes = []
			items = Note.where(ref_user_id: user.id, ref_unit_id: unit.id).order('video_time, update_time')
			items.each {|item|
				notes.push({
					uqid: item.uqid,
					content: item.content_type == 'text' || item.content_type == nil ? item.content : JSON.parse(item.content),
					time: item.video_time == nil ? 0 : item.video_time.to_i,
					type: item.content_type == nil ? 'text' : item.content_type
				})
			}

			items = ViewHistory.find_by_sql(
				"select vh.seconds_watched, to_char(vh.time_watched::timestamp + interval '#{params[:timezone] == nil ? 0 : params[:timezone]} hours', 'YYYY-MM-DD') date
				from view_history vh
				where vh.ref_user_id = #{user.id} and vh.ref_unit_id = '#{unit.id}'")

			vh = []
			items.each{|item|
				flag = false
				vh.each{|v|
					if v[:date] == item.date
						v[:seconds] += item.seconds_watched.to_i
						flag = true
					end
				}

				if !flag
					vh.push({
						date: item.date,
						seconds: item.seconds_watched.to_i
					})
				end
			}

			item = Unit.find_by_sql(
				"select u.id, u.uqid, u.name, u.content, u.unit_type, sr.content study_content, sr.learning_time
				from unit u
					left join study_result sr on sr.ref_unit_id = u.id
				where sr.ref_user_id = #{user.id} and u.id = #{unit.id}").first

			study_result = JSON.parse(item.study_content) if item

			render :json => {
				vh: vh,
				notes: notes,
				study_result: study_result,
				unit: {
					uqid: unit.uqid,
					name: unit.name,
					unit_type: unit.unit_type,
					content: unit.content != nil ? (['poll', 'draw'].include?(unit.unit_type) ? JSON.parse(unit.content) : unit.content) : nil,
					content_url: unit.content_url,
					quizzes: quizzes
				}
			}
		else
			render :json => { vh: [], notes: [], result: [] }
		end
	end

	def list_member
		keyword = params[:keyword] != nil ? "and (lower(u.first_name) like lower('%#{params[:keyword]}%') or lower(u.last_name) like lower('%#{params[:keyword]}%') or lower(u.userid) like lower('%#{params[:keyword]}%'))" : ""

		role = "and gm.role = '#{params[:role]}'" if params[:role] != nil

		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20

		status = params[:status] != nil ? params[:status] : ""
		status = '' if status == 'all'
		status = "and gm.status = 'approved'" if status == 'approved'
		status = "and gm.status = 'rejection'" if status == 'rejection'

		offset = "offset #{start_index} limit #{max_results}"
		offset = '' if keyword != ''

		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			if group.role == 'member'
				items = User.find_by_sql(
					"select gm.id gmid, gm.uqid gm_uqid, u.uqid uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.status, gm.role, gm.order, gm.last_view_time
					from group_member gm
						left join \"user\" u on gm.ref_user_id = u.id
						left join \"group\" g on g.id = gm.ref_group_id
					where g.uqid = '#{params[:groupUqid]}' #{role} #{status} #{keyword}
					group by gm.id, gm.uqid, u.uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.status, gm.role, gm.order, gm.last_view_time
					order by gm.order
					#{offset}")

				content = []
				items.each_with_index {|item, index|
					if item.order == nil
						gm = GroupMember.find(item.gmid)
						gm.order = index+1
						gm.save()

						item.order = index+1
					end

					if item.uqid != nil
						content.push({
							item_uqid: item.gm_uqid,
							user_uqid: item.uqid,
							email: item.userid,
							first_name: item.first_name,
							last_name: item.last_name,
							full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
							nouser: item.nouser,
							status: item.status,
							role: item.role,
							order: item.order.to_i,
							last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
							photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
							page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
						})
					end
				}

				render :json => content
			else
				items = User.find_by_sql(
					"select gm.id gmid, gm.uqid gm_uqid, u.uqid uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.ref_email gm_email, gm.first_name gm_first_name, gm.last_name gm_last_name, gm.status, gm.role, gm.order, gm.last_view_time,
						sum(gmb.points) behavior_points
					from group_member gm
						left join \"user\" u on gm.ref_user_id = u.id
						left join \"group\" g on g.id = gm.ref_group_id
						left join group_member_behavior gmb on gmb.ref_user_id = gm.ref_user_id and gmb.ref_group_id = gm.ref_group_id
					where g.uqid = '#{params[:groupUqid]}' #{role} #{status} #{keyword}
					group by gm.id, gm.uqid, u.uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.ref_email, gm.first_name, gm.last_name, gm.status, gm.role, gm.order, gm.last_view_time
					order by gm.order
					#{offset}")

				content = []
				items.each_with_index {|item, index|
					if item.order == nil
						gm = GroupMember.find(item.gmid)
						gm.order = index+1
						gm.save()

						item.order = index+1
					end

					if item.uqid != nil
						content.push({
							item_uqid: item.gm_uqid,
							user_uqid: item.uqid,
							email: item.userid,
							first_name: item.first_name,
							last_name: item.last_name,
							full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
							nouser: item.nouser,
							status: item.status,
							role: item.role,
							order: item.order.to_i,
							last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
							behavior_points: item.behavior_points,
							photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
							page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
						})
					else
						content.push({
							item_uqid: item.gm_uqid,
							user_uqid: item.uqid,
							email: item.gm_email,
							first_name: item.gm_first_name,
							last_name: item.gm_last_name,
							full_name: parse_full_name(item.gm_first_name, item.gm_last_name, item.gm_email, item.nouser),
							nouser: item.nouser,
							status: item.status,
							role: item.role,
							order: item.order.to_i,
							last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
							behavior_points: item.behavior_points,
							photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
							page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
							unregistered: true
						})
					end
				}

				render :json => content
			end
		else
			render :json => []
		end
	end

	def import_member
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			members = params[:members]
			if members != nil
				members.each{|member|
					user = User.select('id').where(userid: member['email']).first

					if user != nil
						gm = GroupMember.where(ref_user_id: user.id, ref_group_id: group.id).first

						if gm == nil
							order = GroupMember.where(ref_group_id: group.id).maximum('order')

							gm = GroupMember.new
							gm.uqid = UUID.new.generate.split('-')[0..1].join('')
							gm.ref_user_id = user.id
							gm.ref_group_id = group.id
							gm.status = 'approved'
							gm.role = 'member'
							gm.order = (order == nil ? 1 : order + 1)
							gm.notification = true
							gm.sign_time = Time.now
							gm.save
						end
					else
						gm = GroupMember.where(ref_email: member['email'], ref_group_id: group.id).first

						if gm == nil
							order = GroupMember.where(ref_group_id: group.id).maximum('order')

							gm = GroupMember.new
							gm.uqid = UUID.new.generate.split('-')[0..1].join('')
							gm.ref_group_id = group.id
							gm.status = 'approved'
							gm.role = 'member'
							gm.order = (order == nil ? 1 : order + 1)
							gm.notification = true
							gm.ref_email = member['email']
							gm.first_name = member['first_name'] if member['first_name'] != nil
							gm.last_name = member['last_name'] if member['last_name'] != nil
							gm.save
						end
					end
				}
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def export_member
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			items = User.find_by_sql(
				"select u.uqid, u.userid, u.first_name, u.last_name, gm.ref_email gm_email, gm.first_name gm_first_name, gm.last_name gm_last_name, gm.status, gm.role
				from group_member gm
					left join \"user\" u on gm.ref_user_id = u.id
					left join \"group\" g on g.id = gm.ref_group_id
				where g.uqid = '#{params[:groupUqid]}'
				order by gm.order")

			content = [];
			items.each{|item|
				if item.uqid != nil
					content.push("#{item.userid}, #{item.first_name}, #{item.last_name}, #{item.status}, #{item.role}")
				else
					content.push("#{item.gm_email}, #{item.gm_first_name}, #{item.gm_last_name}, #{item.status}, #{item.role}")
				end
			}

			send_data content.join("\r\n"), :filename => "#{group.name}_members.csv"
		end
	end

	def add_member
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			user = User.select('id').where(userid: params[:email].downcase).first

			if user != nil
				gm = GroupMember.where(ref_user_id: user.id, ref_group_id: group.id).first

				if gm == nil
					order = GroupMember.where(ref_group_id: group.id).maximum('order')

					gm = GroupMember.new
					gm.uqid = UUID.new.generate.split('-')[0..1].join('')
					gm.ref_user_id = user.id
					gm.ref_group_id = group.id
					gm.status = 'approved'
					gm.role = 'member'
					gm.order = (order == nil ? 1 : order + 1)
					gm.notification = true
					gm.sign_time = Time.now
					gm.save
				end
			else
				gm = GroupMember.where(ref_email: params[:email].downcase, ref_group_id: group.id).first

				if gm == nil
					order = GroupMember.where(ref_group_id: group.id).maximum('order')

					gm = GroupMember.new
					gm.uqid = UUID.new.generate.split('-')[0..1].join('')
					gm.ref_group_id = group.id
					gm.status = 'approved'
					gm.role = 'member'
					gm.order = (order == nil ? 1 : order + 1)
					gm.notification = true
					gm.ref_email = params[:email].downcase
					gm.first_name = params[:first_name] if params[:first_name] != nil
					gm.last_name = params[:last_name] if params[:last_name] != nil
					gm.save
				end
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_member
		gm = GroupMember.where(uqid: params[:itemUqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.role = 'owner'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.id = '#{gm.ref_group_id}'").first

		if gm != nil
			if params[:notification] != nil
				if gm.ref_user_id == session[:userinfo][:id]
					gm.notification = params[:notification] == true ? true : false
					gm.save()
				end
			end

			if group != nil
				if params[:order]
					order = params[:order].to_i

					if order > gm.order
						ActiveRecord::Base.connection.execute(
							"update group_member set \"order\" = \"order\" - 1
							where \"order\" > #{gm.order} and \"order\" <= #{order} and ref_group_id = #{group.id}")
					else
						ActiveRecord::Base.connection.execute(
							"update group_member set \"order\" = \"order\" + 1
							where \"order\" < #{gm.order} and \"order\" >= #{order} and ref_group_id = #{group.id}")
					end

					gm.order = order
					gm.save()
				end

				if gm.role != 'owner'
					if params[:role] == 'admin' or params[:role] == 'member'
						gm.role = params[:role]
						gm.save()
					end

					if params[:status] == 'approved'
						gm.status = params[:status]
						gm.save()
					end

					if params[:status] == 'rejection'
						ActiveRecord::Base.connection.execute(
							"update group_member set \"order\" = \"order\" - 1
							where \"order\" > #{gm.order} and ref_group_id = #{group.id}")

						gm.destroy
					end
				end
			end
		end

		item = User.find_by_sql(
			"select gm.uqid gm_uqid, u.uqid uqid, u.userid, u.first_name, u.last_name, u.nouser, gm.status, gm.role, gm.notification, gm.order, gm.last_view_time
			from group_member gm
				left join \"user\" u on gm.ref_user_id = u.id
			where gm.id = #{gm.id}").first

		if item != nil
			content = {
				item_uqid: item.gm_uqid,
				user_uqid: item.uqid,
				email: item.userid,
				first_name: item.first_name,
				last_name: item.last_name,
				full_name: (parse_full_name(item.first_name, item.last_name, item.userid, item.nouser) if item.uqid?),
				nouser: item.nouser,
				status: item.status,
				role: item.role,
				notification: item.notification,
				order: item.order.to_i,
				last_view_time: item.last_view_time != nil ? item.last_view_time.to_datetime : nil,
				photo: (get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }) if item.uqid?),
				page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
			}
		else
			content = { error: "We're sorry, but something went wrong." }
		end

		render :json => content
	end

	def remove_member
		gm = GroupMember.where("uqid in ('#{params[:itemUqid].split(',').join("','")}')")

		if gm != nil
			group = Group.find_by_sql(
				"select g.*, gm.role
				from \"group\" g
					join group_member gm on gm.ref_group_id = g.id
				where gm.role = 'owner'
					and gm.ref_user_id = #{session[:userinfo][:id]}
					and g.id = '#{gm.first.ref_group_id}'").first

			if group != nil
				gm.each {|item|
					if item.role != 'owner'
						ActiveRecord::Base.connection.execute(
							"update group_member set \"order\" = \"order\" - 1
							where \"order\" > #{item.order} and ref_group_id = #{item.ref_group_id}")

						item.destroy
					end
				}
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def self_knowledge
		items = Knowledge.find_by_sql(
			"select k.id, k.uqid, k.name, k.code
			from knowledge k
				join reader r on r.ref_know_id = k.id and r.is_archived = false
			where r.ref_user_id = #{session[:userinfo][:id]}
			union
			select k.id, k.uqid, k.name, k.code
			from knowledge k
				join draft_knowledge dk on dk.uqid = k.uqid
				join draft_knowledge_editor dke on dke.ref_know_id = dk.id
			where dke.ref_user_id = #{session[:userinfo][:id]}
			order by name")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				code: item.code
			})
		}

		render :json => content
	end

	def list_knowledge_unit
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			items = Unit.find_by_sql(
				"select c.uqid c_uqid, c.name c_name, u.uqid, u.name
				from unit u
					left join chapter c on c.id = u.ref_chapter_id
					left join knowledge k on k.id = c.ref_know_id
				where k.uqid = '#{params[:itemUqid]}' and u.is_destroyed is null
				order by c.priority, u.priority")

			ch_uqid = 'xxxxxxxx'
			content = []
			units = []
			items.each{|item|
				if ch_uqid != item.c_uqid
					units = []
					chapter = {
						uqid: item.c_uqid,
						name: item.c_name,
						units: units
					}

					content.push(chapter)
					ch_uqid = item.c_uqid
				end

				units.push({
					uqid: item.uqid,
					name: item.name
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def list_knowledge
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			if group.role == 'member'
				items = Knowledge.find_by_sql(
					"select k.id, k.uqid, k.name, k.code, gk.uqid gk_uqid, gk.priority, r.id reader
					from knowledge k
						join group_knowledge gk on gk.ref_know_id = k.id
						left join reader r on r.ref_know_id = k.id and r.ref_user_id = #{session[:userinfo][:id]}
					where gk.ref_group_id = #{group.id} and gk.is_show = true
					order by gk.priority")

				content = []
				items.each{|item|
					content.push({
						know_uqid: item.uqid,
						know_code: item.code,
						uqid: item.gk_uqid,
						name: item.name,
						priority: item.priority,
						subscribed: item.reader != nil ? true : false,
						logo: get_image('knowledge', { uqid: item.uqid }),
						page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
					})
				}
			else
				items = Knowledge.find_by_sql(
					"select k.id, k.uqid, k.name, k.code, gk.id gkid, gk.uqid gk_uqid, gk.priority, gk.is_show
					from knowledge k
						join group_knowledge gk on gk.ref_know_id = k.id
					where gk.ref_group_id = #{group.id}
					order by gk.priority")

				content = []
				items.each{|item|
					content.push({
						know_uqid: item.uqid,
						know_code: item.code,
						uqid: item.gk_uqid,
						name: item.name,
						priority: item.priority,
						is_show: item.is_show,
						logo: get_image('knowledge', { uqid: item.uqid }),
						page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
					})
				}
			end

			render :json => content
		else
			render :json => []
		end
	end

	def add_knowledge
		uqid = params[:knowUqid].split('/knowledge/')[1] if params[:knowUqid]
		uqid = params[:knowCode].split('/knowledge/')[1] if params[:knowCode]
		uqid = uqid ? uqid.split('?')[0]: 'not found'
		know = Knowledge.where(['uqid = ? or code = ? or uqid = ?', params[:knowUqid], params[:knowCode], uqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if know != nil and group != nil
			item = GroupKnowledge.where(['ref_group_id = ? and ref_know_id = ?', group.id, know.id]).first

			if item == nil
				priority = GroupKnowledge.where(ref_group_id: group.id).maximum('priority')

				item = GroupKnowledge.new
				item.ref_group_id = group.id
				item.ref_know_id = know.id
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.last_update = Time.now()
				item.approve_code = know.code
				item.is_show = false
				item.priority = (priority == nil ? 1 : priority + 1)
				item.save()

				item.group.last_update = Time.now()
				item.group.save()
			end

			knowledges = Knowledge.find_by_sql(
				"select k.id, k.uqid, k.name, k.code, gk.uqid gk_uqid, gk.priority, gk.is_show
				from knowledge k
					join group_knowledge gk on gk.ref_know_id = k.id
				where gk.ref_group_id = #{group.id}
				order by gk.priority")

			content = []
			knowledges.each {|item|
				content.push({
					know_uqid: item.uqid,
					know_code: item.code,
					uqid: item.gk_uqid,
					name: item.name,
					priority: item.priority,
					is_show: item.is_show,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
				})
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_knowledge
		item = GroupKnowledge.where(uqid: params[:itemUqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.id = '#{item.ref_group_id}'").first

		if item != nil and group != nil
			if params[:priority] != nil
				priority = params[:priority].to_i

				if priority > item.priority
					ActiveRecord::Base.connection.execute(
						"update group_knowledge set priority = priority - 1
						where priority > #{item.priority} and priority <= #{priority} and ref_group_id = #{group.id}")
				else
					ActiveRecord::Base.connection.execute(
						"update group_knowledge set priority = priority + 1
						where priority < #{item.priority} and priority >= #{priority} and ref_group_id = #{group.id}")
				end

				item.priority = priority
				item.save()
			end

			if params[:is_show] != nil
				item.is_show = params[:is_show] == true ? true : false
				item.save()
			end

			knowledges = Knowledge.find_by_sql(
				"select k.id, k.uqid, k.name, k.code, gk.uqid gk_uqid, gk.priority, gk.is_show
				from knowledge k
					join group_knowledge gk on gk.ref_know_id = k.id
				where gk.ref_group_id = #{group.id}
				order by gk.priority")

			content = []
			knowledges.each {|item|
				content.push({
					know_uqid: item.uqid,
					know_code: item.code,
					uqid: item.gk_uqid,
					name: item.name,
					priority: item.priority,
					is_show: item.is_show,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
				})
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def remove_knowledge
		item = GroupKnowledge.where(uqid: params[:itemUqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.id = '#{item.ref_group_id}'").first

		if item != nil and group != nil
			ActiveRecord::Base.connection.execute(
				"update group_knowledge set priority = priority - 1
				where priority > #{item.priority} and ref_group_id = #{group.id}")

			item.destroy

			knowledges = Knowledge.find_by_sql(
				"select k.id, k.uqid, k.name, k.code, gk.uqid gk_uqid, gk.priority, gk.is_show
				from knowledge k
					join group_knowledge gk on gk.ref_know_id = k.id
				where gk.ref_group_id = #{group.id}
				order by gk.priority")

			content = []
			knowledges.each {|item|
				content.push({
					know_uqid: item.uqid,
					know_code: item.code,
					uqid: item.gk_uqid,
					name: item.name,
					priority: item.priority,
					is_show: item.is_show,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
				})
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def import_knowledge
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			params[:knowledges].each{|target|
				know = Knowledge.where(uqid: target).first
				item = GroupKnowledge.where(['ref_group_id = ? and ref_know_id = ?', group.id, know.id]).first

				if item == nil
					priority = GroupKnowledge.where(ref_group_id: group.id).maximum('priority')

					item = GroupKnowledge.new
					item.ref_group_id = group.id
					item.ref_know_id = know.id
					item.uqid = UUID.new.generate.split('-')[0..1].join('')
					item.last_update = Time.now()
					item.approve_code = know.code
					item.is_show = false
					item.priority = (priority == nil ? 1 : priority + 1)
					item.save()

					item.group.last_update = Time.now()
					item.group.save()
				end
			}

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_file
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			file = group.file == nil ? [] : JSON.parse(group.file);

			render :json => file
		else
			render :json => []
		end
	end

	def update_file
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			group.file = params[:file] if params[:file] != nil
			group.content = params[:file] if params[:file] != nil
			group.save()

			file = group.file == nil ? [] : JSON.parse(group.file);

			render :json => file
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_link
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			link = group.link == nil ? [] : JSON.parse(group.link);

			render :json => link
		else
			render :json => []
		end
	end

	def update_link
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			group.link = params[:link] if params[:link] != nil
			group.save()

			link = group.link == nil ? [] : JSON.parse(group.link);

			render :json => link
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			items = GroupBehavior.where(ref_group_id: group.id).order('points desc, name')

			content = []
			items.each{|item|
				content.push({
					uqid: item.uqid,
					icon: item.icon,
					name: item.name,
					points: item.points
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def add_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil and params[:name] != nil
			item = GroupBehavior.new
			item.ref_group_id = group.id
			item.uqid = UUID.new.generate.split('-')[0..1].join('')
			item.name = params[:name]
			item.icon = params[:icon].to_i
			item.points = params[:points] == -1 ? -1 : 1
			item.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_behavior
		item = GroupBehavior.where(uqid: params[:itemUqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.id = '#{item.ref_group_id}'").first

		if group != nil and item != nil
			item.name = params[:name] if params[:name] != nil
			item.icon = params[:icon].to_i if params[:icon] != nil
			item.points = (params[:points] == -1 ? -1 : 1) if params[:points] != nil
			item.save()

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_behavior
		item = GroupBehavior.where(uqid: params[:itemUqid]).first
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.id = '#{item.ref_group_id}'").first

		if group != nil and item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def list_self_behavior
		items = GroupMemberBehavior.find_by_sql(
			"select gmb.*, gb.name, gb.icon
			from group_member_behavior gmb
				join group_member gm on gm.ref_user_id = gmb.ref_user_id and gm.ref_group_id = gmb.ref_group_id
				join group_behavior gb on gb.id = gmb.ref_behavior_id
				join \"group\" g on g.id = gmb.ref_group_id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'
			order by gmb.gained_time desc")

		content = []
		items.each {|item|
			content.push({
				name: item.name,
				icon: item.icon,
				points: item.points,
				gained_time: item.gained_time
			})
		}

		render :json => content
	end

	def list_member_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			items = GroupMemberBehavior.find_by_sql(
				"select gmb.*, gb.name, gb.icon
				from group_member_behavior gmb
					join group_member gm on gm.ref_user_id = gmb.ref_user_id and gm.ref_group_id = gmb.ref_group_id
					join group_behavior gb on gb.id = gmb.ref_behavior_id
					join \"group\" g on g.id = gmb.ref_group_id
				where gm.status = 'approved'
					and gm.uqid = '#{params[:itemUqid]}'
					and g.uqid = '#{params[:groupUqid]}'
				order by gmb.gained_time desc")

			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					name: item.name,
					icon: item.icon,
					points: item.points,
					gained_time: item.gained_time
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def add_member_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			members = GroupMember.find_by_sql(
				"select *
				from group_member
				where status = 'approved' and uqid in ('#{params[:memberUqid].join("','")}')")
			behavior = GroupBehavior.where(uqid: params[:behaviorUqid]).first

			if members.size > 0 and behavior != nil
				members.each{|member|
					item = GroupMemberBehavior.new
					item.uqid = UUID.new.generate.split('-')[0..1].join('')
					item.ref_behavior_id = behavior.id
					item.ref_group_id = group.id
					item.ref_user_id = member.ref_user_id
					item.points = behavior.points
					item.gained_time = Time.new
					item.save()
				}

				users = User.find_by_sql(
					"select gm.uqid gm_uqid, u.uqid uqid, sum(gmb.points) behavior_points
					from \"user\" u
						join group_member gm on gm.ref_user_id = u.id
						join group_member_behavior gmb on gmb.ref_user_id = gm.ref_user_id and gmb.ref_group_id = gm.ref_group_id
					where gm.status = 'approved' and gm.uqid in ('#{params[:memberUqid].join("','")}')
					group by gm.uqid, u.uqid")

				content = []
				users.each{|u|
					content.push({
						user_uqid: u.uqid,
						behavior_points: u.behavior_points
					})
				}

				render :json => content
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_member_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		item = GroupMemberBehavior.where(uqid: params[:itemUqid]).first

		if group != nil and item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def add_member_unit_feedback
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		unit = Unit.where(uqid: params[:unitUqid]).first
		member = GroupMember.find_by_sql(
			"select u.uqid user_uqid, u.id user_id
			from \"user\" u
				join group_member gm on gm.ref_user_id = u.id
				join \"group\" g on g.id = gm.ref_group_id
			where g.uqid = '#{params[:groupUqid]}'
				and gm.uqid = '#{params[:memberUqid]}'").first

		if group != nil and unit != nil and member != nil
			item = UnitFeedback.where(ref_user_id: member.user_id, ref_unit_id: unit.id, ref_group_id: group.id).first

			if item == nil
				item = UnitFeedback.new
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.ref_user_id = member.user_id
				item.ref_unit_id = unit.id
				item.ref_group_id = group.id
				item.score = params[:score].to_f
				item.comment = params[:comment]
				item.save()

				render :json => {
					uqid: item.uqid,
					score: item.score.to_f,
					comment: item.comment
				}
			else
				item.score = params[:score].to_f || item.score
				item.comment = params[:comment] || item.comment
				item.save()

				render :json => {
					uqid: item.uqid,
					score: item.score.to_f,
					comment: item.comment
				}
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def update_member_unit_feedback
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		item = UnitFeedback.where(uqid: params[:itemUqid]).first

		if group != nil and item != nil
			item.score = params[:score].to_f || item.score
			item.comment = params[:comment] || item.comment
			item.save()

			render :json => {
				uqid: item.uqid,
				score: item.score.to_f,
				comment: item.comment
			}
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def delete_member_unit_feedback
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		item = UnitFeedback.where(uqid: params[:itemUqid]).first

		if group != nil and item != nil
			item.destroy

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end
end