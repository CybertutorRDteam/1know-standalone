require "base64"
require "uuid"

class Private::BackgroundController < ApplicationController
	before_filter :check_session

	def user
		domain = session[:userinfo][:userid].split('@')[1]

		if false #domain != 'ischool.com.tw'
			render :json => []
		else
			condition = params[:keyword] != nil ? "where lower(first_name) like lower('%#{params[:keyword]}%') or lower(last_name) like lower('%#{params[:keyword]}%') or lower(userid) like lower('%#{params[:keyword]}%') or lower(account_type) like lower('%#{params[:keyword]}%') or lower(last_login_ip) like lower('%#{params[:keyword]}%')" : ""

			start_index = params['start-index'] != nil ? params['start-index'] : 0
			max_results = params['max-results'] != nil ? params['max-results'] : 20

			offset = "offset #{start_index} limit #{max_results}"
			offset = '' if condition != ''

			items = User.find_by_sql(
				"select uqid, userid, first_name, last_name, account_type, expired_date, photo, last_login_ip, last_login_time, nouser
				from \"user\"
				#{condition}
				order by last_login_time desc, userid asc
				#{offset}")

			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					email: item.userid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					account_type: item.account_type,
					expired_date: item.expired_date != nil ? item.expired_date.to_datetime : nil,
					last_login_ip: item.last_login_ip,
					last_login_time: item.last_login_time != nil ? item.last_login_time.to_datetime : nil,
					photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
					nouser: item.nouser
				})
			}

			user = User.find_by_sql(
				"select
					sum(case when nouser = true then 1 else 0 end) nouser_size,
					sum(case when nouser = false then 1 else 0 end) user_size,
					sum(case to_char(create_time::timestamp + interval '8 hours', 'YYYY-MM-DD') = to_char(now()::timestamp + interval '8 hours', 'YYYY-MM-DD') and nouser = true when true then 1 else 0 end) ntoday_size,
					sum(case to_char(create_time::timestamp + interval '8 hours', 'YYYY-MM-DD') = to_char(now()::timestamp + interval '8 hours', 'YYYY-MM-DD') and nouser = false when true then 1 else 0 end) utoday_size
				from \"user\"").first

			render :json => {
				users: content,
				size: {
					user_total: user.nouser_size,
					user_today: user.ntoday_size,
					nouser_total: user.user_size,
					nouser_today: user.utoday_size
				}
			}
		end
	end

	def knowledge
		domain = session[:userinfo][:userid].split('@')[1]

		if false #domain != 'ischool.com.tw'
			render :json => []
		else
			condition = params[:keyword] != nil ? "where lower(k.name) like lower('%#{params[:keyword]}%')" : ""

			start_index = params['start-index'] != nil ? params['start-index'] : 0
			max_results = params['max-results'] != nil ? params['max-results'] : 20

			offset = "offset #{start_index} limit #{max_results}"
			offset = '' if condition != ''

			items = Knowledge.find_by_sql(
				"select k.id, k.uqid, k.name, k.is_public, k.is_destroyed, k.last_update,
					count(r.id) reader, sum(case when is_archived = true then 1 else 0 end) archived
				from knowledge k
					left join reader r on r.ref_know_id = k.id
				#{condition}
				group by k.id, k.uqid, k.name, k.is_public, k.is_destroyed, k.last_update
				order by k.last_update desc
				#{offset}")

			content = []
			items.each {|item|
				ke = DraftKnowledgeEditor.find_by_sql(
					"select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
					from draft_knowledge_editor dke
						join \"user\" u on u.id = dke.ref_user_id
						join draft_knowledge dk on dk.id = dke.ref_know_id
						join knowledge k on k.uqid = dk.uqid
					where k.id = #{item.id} and dke.role = 'owner'
					order by dke.id").first

				if ke != nil
					owner = {
						uqid: ke.uqid,
						full_name: parse_full_name(ke.first_name, ke.last_name, ke.userid, ke.nouser),
						photo: get_image('user', { uqid: ke.uqid, nouser: ke.nouser, type: 'photo' }),
						page: "#{request.protocol}#{request.host_with_port}/user/#{ke.uqid}",
					}
				else
					owner = nil
				end

				content.push({
					uqid: item.uqid,
					name: item.name,
					last_update: item.last_update,
					reader: item.reader.to_i,
					archived: item.archived.to_i,
					privacy: item.is_public != nil ? item.is_public : false,
					destroyed: item.is_destroyed != nil ? item.is_destroyed : false,
					logo: get_image('knowledge', { uqid: item.uqid.split('-')[0] }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					owner: owner
				})
			}

			knowledge = Knowledge.find_by_sql(
				"select
					count(id) total_size,
					sum(case when is_public = true then 1 else 0 end) public_size,
					sum(case when is_public = false then 1 else 0 end) private_size
				from knowledge").first

			render :json => {
				knowledges: content,
				size: {
					total: knowledge.total_size,
					private: knowledge.private_size,
					public: knowledge.public_size
				}
			}
		end
	end

	def channel
		domain = session[:userinfo][:userid].split('@')[1]

		if false #domain != 'ischool.com.tw'
			render :json => []
		else
			condition = params[:keyword] != nil ? "where lower(chl.name) like lower('%#{params[:keyword]}%')" : ""

			start_index = params['start-index'] != nil ? params['start-index'] : 0
			max_results = params['max-results'] != nil ? params['max-results'] : 20

			offset = "offset #{start_index} limit #{max_results}"
			offset = '' if condition != ''

			items = Channel.find_by_sql(
				"select chl.id, chl.uqid, chl.name, chl.last_update, count(cm.id) subscriber
				from channel chl
					left join channel_member cm on cm.ref_channel_id = chl.id and cm.role = 'member'
				#{condition}
				group by chl.id, chl.uqid, chl.name, chl.last_update, chl.last_update
				order by chl.last_update desc
				#{offset}")

			content = []
			items.each {|item|
				cm = ChannelMember.find_by_sql(
					"select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
					from channel_member cm
						join \"user\" u on u.id = cm.ref_user_id
						join channel cl on cl.id = cm.ref_channel_id
					where cl.id = #{item.id} and cm.role = 'owner'
					order by u.last_name, u.first_name").first

				if cm != nil
					owner = {
						uqid: cm.uqid,
						full_name: parse_full_name(cm.first_name, cm.last_name, cm.userid, cm.nouser),
						photo: get_image('user', { uqid: cm.uqid, nouser: cm.nouser, type: 'photo' }),
						page: "#{request.protocol}#{request.host_with_port}/user/#{cm.uqid}",
					}
				else
					owner = nil
				end

				content.push({
					uqid: item.uqid,
					name: item.name,
					subscriber: item.subscriber.to_i,
					last_update: item.last_update,
					logo: get_image('channel', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/channel/#{item.uqid}",
					owner: owner
				})
			}

			render :json => {
				channels: content,
				size: Channel.select('id').size
			}
		end
	end

	def group
		domain = session[:userinfo][:userid].split('@')[1]

		if false #domain != 'ischool.com.tw'
			render :json => []
		else
			keyword = params['keyword']

			start_index = params['start-index'] != nil ? params['start-index'] : 0
			max_results = params['max-results'] != nil ? params['max-results'] : 20

			if keyword == nil
				items = Group.find_by_sql(
					"select g.id, g.uqid, g.name, g.last_update, g.is_public, g.is_destroyed
					from \"group\" g
					where g.is_destroyed = false
					order by g.last_update desc
					offset #{start_index} limit #{max_results}")
			else
				items = Group.find_by_sql(
					"select g.id, g.uqid, g.name, g.last_update, g.is_public, g.is_destroyed
					from \"group\" g
					where lower(g.name) like lower('%#{keyword}%') or lower(g.description) like lower('%#{keyword}%')
					order by g.last_update desc")
			end

			content = []
			items.each_with_index {|item, index|
				owner = User.find_by_sql(
					"select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
					from \"user\" u
						join group_member gm on gm.ref_user_id = u.id
					where gm.ref_group_id = #{item.id} and gm.role = 'owner'").first

				content.push({
					uqid: item.uqid,
					name: item.name,
					member: item.members.size,
					knowledge: item.knowledges.size,
					last_update: item.last_update,
					public: item.is_public,
					destroyed: item.is_destroyed,
					logo: get_image('group', { uqid: item.uqid.split('-')[0] }),
					page: "#{request.protocol}#{request.host_with_port}/group/#{item.uqid}",
					user: owner != nil ? {
						uqid: owner.uqid,
						full_name: parse_full_name(owner.first_name, owner.last_name, owner.userid, owner.nouser),
						photo: get_image('user', { uqid: owner.uqid, nouser: owner.nouser, type: 'photo' }),
						page: "#{request.protocol}#{request.host_with_port}/user/#{owner.uqid}"
					} : nil
				})
			}

			render :json => {
				groups: content,
				size: Group.select('id').size
			}
		end
	end
end