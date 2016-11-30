class Private::DiscoveryController < ApplicationController
	
	def knowledge
		keyword = params[:keyword] != nil ? "and lower(k.name) like lower('%#{params[:keyword]}%') or lower(k.code) like lower('#{params[:keyword]}')" : ""

		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20
		
		offset = "offset #{start_index} limit #{max_results}"
		offset = '' if keyword != ''

		order_by = 'order by k.last_update desc'
		order_by = 'order by k.last_update desc' if params['order-by'] == 'date'
		order_by = 'order by r.reader_size desc nulls last, r.average_rate desc nulls last' if params['order-by'] == 'subscribed'
		order_by = 'order by r.average_rate desc nulls last, r.reader_size desc nulls last' if params['order-by'] == 'rating'

		items = Knowledge.find_by_sql(
			"select k.id, k.uqid, k.name, k.last_update, k.is_public, k.total_time, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
			from knowledge k
				join draft_knowledge dk on dk.uqid = k.uqid
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
				left join \"user\" u on u.id = dke.ref_user_id
				left join (select r.ref_know_id, count(r.id) reader_size,
						sum(case when r.rating is null then 0 else r.rating end) total_rate,
						sum(case when r.rating is null then 0 else 1 end) rate_count,
						case when sum(case when r.rating is null then 0 else 1 end) <> 0
							then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
							else 0 end average_rate
					from reader r
					group by r.ref_know_id) as r on r.ref_know_id = k.id
			where k.is_public = true #{keyword}
			#{order_by}
			#{offset}")

		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				last_update: item.last_update,
				is_public: item.is_public,
				total_time: item.total_time.to_i,
				units: item.units.size,
				readers: item.reader_size || 0,
				rate_count: item.rate_count || 0,
				total_rate: item.total_rate || 0,
				average_rate: item.average_rate || 0,
				logo: get_image('knowledge', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
				editor: {
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
				}
			})
		}

		render :json => content
	end

	def list_channel
		if session[:userinfo] == nil
			render :json => []
			return
		end

		items = Channel.find_by_sql(
			"select chl.name, chl.uqid, cm.role
			from channel chl
				join channel_member cm on cm.ref_channel_id = chl.id and cm.status = 'approved'
			where cm.ref_user_id = #{session[:userinfo][:id]}
			order by chl.name")

		content = []
		items.each{|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				logo: get_image('channel', { uqid: item.uqid }),
				role: item.role
			})
		}

		render :json => content
	end

	def channel
		channel = Channel.where(['uqid = ?', params[:channelUqid]]).first

		if channel != nil
			subscribed = false, role = nil
			if channel != nil and session[:userinfo] != nil
				user = ChannelMember.where(['ref_user_id = ? and ref_channel_id = ?', session[:userinfo][:id], channel.id]).first
				subscribed = true if user != nil
				role = user.role if user != nil
			end

			categories = []
			channel.categories.each {|c|
				if c.ref_category_id == nil
					sub_categories = []
					c.categories.each {|sub|
						sub_categories.push({
							uqid: sub.uqid,
							name: sub.name,
							priority: sub.priority,
							logo: sub.logo ? get_image('channel_category', { uqid: sub.uqid }) : nil,
							category_size: sub.categories.size,
							knowledge_size: sub.knowledges.size
						})
					}

					items = Knowledge.find_by_sql(
						"select k.id, k.uqid, k.name, k.last_update, k.is_public, k.total_time, u.first_name, u.uqid u_uqid, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
						from category_knowledge ck
							join category ca on ca.id = ck.ref_category_id
							join knowledge k on k.id = ck.ref_know_id
							join draft_knowledge dk on dk.uqid = k.uqid
							left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
							left join \"user\" u on u.id = dke.ref_user_id
							left join (select r.ref_know_id, count(r.id) reader_size,
									sum(case when r.rating is null then 0 else r.rating end) total_rate,
									sum(case when r.rating is null then 0 else 1 end) rate_count,
									case when sum(case when r.rating is null then 0 else 1 end) <> 0
										then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
										else 0 end average_rate
								from reader r
								group by r.ref_know_id) as r on r.ref_know_id = k.id
						where ca.id = #{c.id}
						order by ca.priority, ck.priority")

					sub_knowledges = []
					items.each {|item|
						sub_knowledges.push({
							uqid: item.uqid,
							name: item.name,
							last_update: item.last_update,
							is_public: item.is_public,
							total_time: item.total_time.to_i,
							units: item.units.size,
							readers: item.reader_size || 0,
							rate_count: item.rate_count || 0,
							total_rate: item.total_rate || 0,
							average_rate: item.average_rate || 0,
							logo: get_image('knowledge', { uqid: item.uqid }),
							page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
							editor: {
								first_name: item.first_name,
								last_name: item.last_name,
								full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
								page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
							}
						})
					}

					categories.push({
						uqid: c.uqid,
						name: c.name,
						priority: c.priority,
						logo: c.logo ? get_image('channel_category', { uqid: c.uqid }) : nil,
						categories: sub_categories,
						knowledges: sub_knowledges,
						category_size: sub_categories.size,
						knowledge_size: sub_knowledges.size
					})
				end
			}

			content = {
				uqid: channel.uqid,
				name: channel.name,
				description: channel.description,
				logo: get_image('channel', { uqid: channel.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/channel/#{channel.uqid}",
				categories: categories,
				subscribed: subscribed,
				role: role
			}

			render :json => content
		else
			render :json => nil
		end
	end

	def channel_category
		category = Category.find_by_sql(
			"select ca.*
			from category ca
				left join channel c on c.id = ca.ref_channel_id
			where ca.uqid = '#{params[:itemUqid]}'
				and c.uqid = '#{params[:channelUqid]}'").first
		
		if category != nil
			sub_categories = []
			category.categories.each {|sub|
				sub_categories.push({
					uqid: sub.uqid,
					name: sub.name,
					priority: sub.priority,
					logo: sub.logo ? get_image('channel_category', { uqid: sub.uqid }) : nil,
					category_size: sub.categories.size,
					knowledge_size: sub.knowledges.size
				})
			}

			items = Knowledge.find_by_sql(
				"select k.id, k.uqid, k.name, k.last_update, k.is_public, k.total_time, u.first_name, u.uqid u_uqid, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
				from category_knowledge ck
					join category ca on ca.id = ck.ref_category_id
					join knowledge k on k.id = ck.ref_know_id
					join draft_knowledge dk on dk.uqid = k.uqid
					left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
					left join \"user\" u on u.id = dke.ref_user_id
					left join (select r.ref_know_id, count(r.id) reader_size,
							sum(case when r.rating is null then 0 else r.rating end) total_rate,
							sum(case when r.rating is null then 0 else 1 end) rate_count,
							case when sum(case when r.rating is null then 0 else 1 end) <> 0
								then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
								else 0 end average_rate
						from reader r
						group by r.ref_know_id) as r on r.ref_know_id = k.id
				where ca.id = #{category.id}
				order by ca.priority, ck.priority")

			sub_knowledges = []
			items.each {|item|
				sub_knowledges.push({
					uqid: item.uqid,
					name: item.name,
					last_update: item.last_update,
					is_public: item.is_public,
					total_time: item.total_time.to_i,
					units: item.units.size,
					readers: item.reader_size || 0,
					rate_count: item.rate_count || 0,
					total_rate: item.total_rate || 0,
					average_rate: item.average_rate || 0,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					editor: {
						first_name: item.first_name,
						last_name: item.last_name,
						full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
						page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
					}
				})
			}

			content = {
				uqid: category.uqid,
				name: category.name,
				categories: sub_categories,
				knowledges: sub_knowledges,
				logo: category.logo ? get_image('channel_category', { uqid: category.uqid }) : nil,
				category_size: sub_categories.size,
				knowledge_size: sub_knowledges.size
			}

			render :json => content
		else
			render :json => []
		end
	end

	def channel_knowledge
		channel = Channel.where(['uqid = ?', params[:channelUqid]]).first
		keyword = params[:keyword] != nil ? "and lower(k.name) like lower('%#{params[:keyword]}%') or lower(k.code) like lower('#{params[:keyword]}')" : ""

		if channel != nil
			items = Knowledge.find_by_sql(
				"select distinct k.id, k.uqid, k.name, k.last_update, k.is_public, k.total_time, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
				from category_knowledge ck
					join category ca on ca.id = ck.ref_category_id
					join knowledge k on k.id = ck.ref_know_id
					join draft_knowledge dk on dk.uqid = k.uqid
					left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
					left join \"user\" u on u.id = dke.ref_user_id
					left join (select r.ref_know_id, count(r.id) reader_size,
							sum(case when r.rating is null then 0 else r.rating end) total_rate,
							sum(case when r.rating is null then 0 else 1 end) rate_count,
							case when sum(case when r.rating is null then 0 else 1 end) <> 0
								then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
								else 0 end average_rate
						from reader r
						group by r.ref_know_id) as r on r.ref_know_id = k.id
				where (k.id in (select ref_know_id from category_knowledge where ref_channel_id = #{channel.id})) #{keyword}
				order by k.name")
			
			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					name: item.name,
					is_public: item.is_public,
					last_update: item.last_update,
					total_time: item.total_time.to_i,
					units: item.units.size,
					readers: item.reader_size || 0,
					rate_count: item.rate_count || 0,
					total_rate: item.total_rate || 0,
					average_rate: item.average_rate || 0,
					logo: get_image('knowledge', { uqid: item.uqid }),
					page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
					editor: {
						first_name: item.first_name,
						last_name: item.last_name,
						full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
						page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
					}
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def subscribe_channel
		if session[:userinfo] != nil
			channel = Channel.where(['uqid = ?', params[:channelUqid]]).first
			
			if channel != nil
				cm = ChannelMember.where(['ref_user_id = ? and ref_channel_id = ?', session[:userinfo][:id], channel.id]).first
				
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

				render :json => { success: "Well done!" }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => nil
		end
	end

	def unsubscribe_channel
		if session[:userinfo] != nil
			channel = Channel.where(['uqid = ?', params[:channelUqid]]).first

			if channel != nil
				user = ChannelMember.where(["ref_channel_id = ? and ref_user_id = ? and role = 'member'", channel.id, session[:userinfo][:id]]).first

				if user != nil
					user.destroy

					render :json => { success: "Well done!" }
				else
					render :json => nil
				end
			else
				render :json => nil
			end
		else
			render :json => nil
		end
	end

	def list_unit
		if params[:itemUqid] != nil
			items = Unit.find_by_sql(
				"select k.uqid k_uqid, k.name k_name, ch.uqid ch_uqid, ch.name ch_name, ch.priority ch_priority,
					u.id, u.uqid, u.name, u.priority, u.unit_type, u.content_url, u.content_time, u.supplementary_description, u.content
				from unit u
					join chapter ch on ch.id = u.ref_chapter_id
					join knowledge k on k.id = ch.ref_know_id
				where k.uqid = '#{params[:itemUqid]}' and u.is_destroyed is null
				order by ch.priority, u.priority")
			
			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					name: item.name,
					unit_type: item.unit_type,
					content_url: item.content_url,
					content_time: item.content_time.to_f,
					priority: item.priority.to_i,
					description: item.supplementary_description,
					content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
					chapter: {
						uqid: item.ch_uqid,
						name: item.ch_name,
						priority: item.ch_priority
					}
				})
			}

			render :json => content
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_front_objs
		collector = []
		collector.push('front_slider_obj') if APP_CONFIG['front_slider_activate']
		collector.push('front_twobanner_obj') if APP_CONFIG['front_twobanner_activate']
		cfg = Sysconfig.where( :target => 'frontpage' , :name => collector )
		set = {}
		cfg.each do |o|
			id = o[:content].split(',')
			set["#{o[:name]}"] = []
			id.each do |i|
				set["#{o[:name]}"].push(FrontObject.where( :id => i ).first)
			end
		end
		set[:front_tags] = FrontObject.order( "knowledges" ).where( :bTag => true ).all if APP_CONFIG['front_tagfunction_activate']
		render :json => set
	end

	def get_front_knowledgeset
		set = "and k.uqid in (\'"+params[:set].join("\',\'")+"\')"
		start_index = params['start-index'] != nil ? params['start-index'] : 0
		max_results = params['max-results'] != nil ? params['max-results'] : 20
		offset = "offset #{start_index} limit #{max_results}"
		items = Knowledge.find_by_sql(
			"select k.id, k.uqid, k.name, k.last_update, k.is_public, k.total_time, u.uqid u_uqid, u.first_name, u.last_name, u.userid, u.nouser, r.reader_size, r.total_rate, r.rate_count, r.average_rate
			from knowledge k
				join draft_knowledge dk on dk.uqid = k.uqid
				left join draft_knowledge_editor dke on dke.ref_know_id = dk.id and dke.role = 'owner'
				left join \"user\" u on u.id = dke.ref_user_id
				left join (select r.ref_know_id, count(r.id) reader_size,
						sum(case when r.rating is null then 0 else r.rating end) total_rate,
						sum(case when r.rating is null then 0 else 1 end) rate_count,
						case when sum(case when r.rating is null then 0 else 1 end) <> 0
							then sum(case when r.rating is null then 0 else r.rating end) / sum(case when r.rating is null then 0 else 1 end)
							else 0 end average_rate
					from reader r
					group by r.ref_know_id) as r on r.ref_know_id = k.id
			where k.is_public = true #{set} order by k.last_update desc
			#{offset}")
		content = []
		items.each {|item|
			content.push({
				uqid: item.uqid,
				name: item.name,
				last_update: item.last_update,
				is_public: item.is_public,
				total_time: item.total_time.to_i,
				units: item.units.size,
				readers: item.reader_size || 0,
				rate_count: item.rate_count || 0,
				total_rate: item.total_rate || 0,
				average_rate: item.average_rate || 0,
				logo: get_image('knowledge', { uqid: item.uqid }),
				page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}",
				editor: {
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					page: "#{request.protocol}#{request.host_with_port}/user/#{item.u_uqid}",
				}
			})
		}
		render :json => content
	end
end