require "net/http"

class Private::ClassroomController < ApplicationController
	def start_classroom
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if params[:type] == 'knowledge'
			target = Knowledge.where(uqid: params[:targetUqid]).first
		elsif params[:type] == 'activity'
			target = GroupActivity.where(uqid: params[:targetUqid]).first
		end

		if group != nil and target != nil
			user = User.where(id: session[:userinfo][:id]).first

			if user.account_type == 'free'
				render :json => { error: 'Free 帐号不提供同步教学功能，如需使用此功能，建议升级至 Plus or Pro 帐号!' }
			else
				item = Classroom.find_by_sql(
					"select cr.*
					from classroom cr
						join \"group\" g on g.id = cr.ref_group_id
					where cr.ref_group_id = #{group.id}").first

				if item == nil
					item = Classroom.new
					item.ref_group_id = group.id
					item.ref_target_id = target.id
					item.ref_target_type = params[:type]
					item.lock_screen = false
					item.teacher_offline = false
					item.last_update = Time.new
					item.create_time = Time.new
					item.save()

					render :json => { success: "Well done!" }
				else
					item.ref_target_id = target.id
					item.ref_target_type = params[:type]
					item.lock_screen = false
					item.teacher_offline = false
					item.last_update = Time.new
					item.save()

					render :json => { success: "Well done!" }
				end
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def set_classroom_status
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		unit = Unit.where(uqid: params[:unitUqid]).first

		if group != nil and unit != nil
			item = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first
			
			if item != nil
				item.ref_unit_id = unit.id
				item.last_update = Time.new
				item.save()
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_classroom_status
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			classroom = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if classroom != nil
				if classroom.ref_target_type == 'knowledge'
					target = Knowledge.where(id: classroom.ref_target_id).first

					items = Unit.find_by_sql(
						"select k.uqid k_uqid, k.name k_name, c.uqid ch_uqid, c.name ch_name, u.id, u.uqid, u.name, u.priority, u.unit_type,
							u.content_url, u.content_time, u.supplementary_description, u.content
						from knowledge k
							join chapter c on c.ref_know_id = k.id
							join unit u on u.ref_chapter_id = c.id
						where k.id = #{classroom.ref_target_id} and u.is_destroyed is null
						order by c.priority, u.priority")
				else
					target = GroupActivity.where(id: classroom.ref_target_id).first
					goal = JSON.parse(target.goal)
					units = []
					goal.each {|u| units.push(u['unit']['uqid']) }

					temp = Unit.find_by_sql(
						"select k.uqid k_uqid, k.name k_name, c.uqid ch_uqid, c.name ch_name, u.id, u.uqid, u.name, u.priority, u.unit_type,
							u.content_url, u.content_time, u.supplementary_description, u.content
						from knowledge k
							join chapter c on c.ref_know_id = k.id
							join unit u on u.ref_chapter_id = c.id
						where u.uqid in ('#{units.join("','")}')")

					items = []
					goal.each {|g|
						temp.each {|t|
							if g['unit']['uqid'] == t.uqid
								items.push t
							end
						}
					}
				end

				content = []
				items.each {|item|
					quizzes = []
					if item.unit_type == 'quiz'
						item.questions.each {|item|
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

					content.push({
						uqid: item.uqid,
						name: item.name,
						priority: item.priority,
						unit_type: item.unit_type,
						content_url: item.content_url,
						description: item.supplementary_description,
						content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
						current: (item.id == classroom.ref_unit_id),
						quizzes: quizzes,
						chapter: {
							uqid: item.ch_uqid,
							name: item.ch_name
						},
						knowledge: {
							uqid: item.k_uqid,
							name: item.k_name
						}
					})
				}

				render :json => {
					classroom: {
						lock_screen: classroom.lock_screen,
						dispatch_url: (classroom.dispatch_url != nil and classroom.dispatch_url != '') ? JSON.parse(classroom.dispatch_url) : nil,
						content: { name: target.name, type: classroom.ref_target_type }
					},
					unit: content
				}
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def response_teacher
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		status = params[:status]

		if group != nil
			item = Classroom.where(ref_group_id: group.id).first
			if item != nil
				item.teacher_offline = status == 'offline' ? true : false
				item.save()
			end

			render :text => 'Well done!'
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def add_teach_member_behavior
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			member = GroupMember.where(uqid: params[:memberUqid], status: 'approved').first
			behavior = GroupBehavior.where(uqid: params[:behaviorUqid]).first

			if member != nil and behavior != nil
				item = GroupMemberBehavior.new
				item.uqid = UUID.new.generate.split('-')[0..1].join('')
				item.ref_behavior_id = behavior.id
				item.ref_group_id = group.id
				item.ref_user_id = member.ref_user_id
				item.points = behavior.points
				item.gained_time = Time.new
				item.save()

				item = User.find_by_sql(
					"select gm.uqid gm_uqid, u.uqid uqid, sum(gmb.points) behavior_points
					from \"user\" u
						join group_member gm on gm.ref_user_id = u.id
						left join group_member_behavior gmb on gmb.ref_user_id = gm.ref_user_id and gmb.ref_group_id = gm.ref_group_id
					where gm.id = #{member.id}
					group by gm.uqid, u.uqid").first

				if item != nil
					render :json => { 
						item_uqid: member.uqid,
						behavior: {
							name: behavior.name,
							icon: behavior.icon,
							points: behavior.points
						},
						behavior_points: item.behavior_points
					}
				else
					render :json => nil
				end
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_student
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			items = User.find_by_sql(
				"select u.uqid, u.userid, u.first_name, u.last_name, u.nouser, u.last_login_ip, gm.uqid gm_uqid, gm.role, gm.order, sum(gmb.points) behavior_points
				from \"user\" u
					join group_member gm on gm.ref_user_id = u.id
					left join group_member_behavior gmb on gmb.ref_user_id = gm.ref_user_id and gmb.ref_group_id = gm.ref_group_id
				where gm.ref_group_id = #{group.id} and gm.role = 'member'
				group by u.uqid, u.userid, u.first_name, u.last_name, u.nouser, u.last_login_ip, gm.uqid, gm.role, gm.order
				order by gm.order")

			content = []
			items.each {|item|
				content.push({
					uqid: item.uqid,
					email: item.userid,
					first_name: item.first_name,
					last_name: item.last_name,
					full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
					behavior_points: item.behavior_points,
					photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
					nouser: item.nouser,
					remote_ip: item.last_login_ip,
					item_uqid: item.gm_uqid,
					role: item.role,
					order: item.order
				})
			}

			render :json => content
		else
			render :json => []
		end
	end

	def lock_screen
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			target = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if target != nil
				target.lock_screen = (params[:status] == true ? true : false) if params[:status] != nil
				target.save()
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def dispatch_url
		group = Group.find_by_sql(
			"select g.*, gm.role
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.role in ('owner', 'admin')
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil and params[:content] != nil
			target = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if target != nil
				target.lock_screen = false
				target.dispatch_url = params[:content]
				target.save()
			end

			render :json => { success: "Well done!" }
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	def get_study_result
		group = Group.where(uqid: params[:groupUqid]).first
		unit = Unit.where(uqid: params[:unitUqid]).first

		if group != nil and unit != nil
			target = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if target != nil
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

				items = StudyResult.find_by_sql(
					"select u.uqid, u.first_name, u.last_name, u.userid, u.nouser, sr.content, sr.learning_time
					from study_result sr
						join \"user\" u on u.id = sr.ref_user_id
						join classroom_member cm on cm.ref_user_id = u.id
					where sr.ref_unit_id = #{unit.id} and cm.ref_classroom_id = #{target.id} and u.uqid in ('#{params[:userUqid].split(',').join("','")}')
					order by u.last_name, u.first_name")

				content = []
				items.each {|item|
					include = false
					content.each {|result| include = true if result[:uqid] == item.uqid }

					if !include
						result = JSON.parse(item.content) if ['quiz', 'draw'].include?(unit.unit_type)
						result = JSON.parse(item.content)['result'] if ['poll', 'qa'].include?(unit.unit_type)

						content.push({
							uqid: item.uqid,
							first_name: item.first_name,
							last_name: item.last_name,
							full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
							email: item.userid,
							nouser: item.nouser,
							result: result,
							learning_time: item.learning_time
						})
					end
				}

				render :json => {
					unit: {
						uqid: unit.uqid,
						name: unit.name,
						unit_type: unit.unit_type,
						content: unit.content != nil ? (['poll', 'draw'].include?(unit.unit_type) ? JSON.parse(unit.content) : unit.content) : nil,
						content_url: unit.content_url,
						quizzes: quizzes
					},
					user: content
				}
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end

	# -- student --

	def get_study_status
		group = Group.find_by_sql(
			"select g.*
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first

		if group != nil
			target = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if target != nil
				member = ClassroomMember.where(ref_user_id: session[:userinfo][:id], ref_classroom_id: target.id).first
				if member == nil
					member = ClassroomMember.new
					member.ref_user_id = session[:userinfo][:id]
					member.ref_classroom_id = target.id
					member.join_time = Time.now
					member.save()
				end

				item = Unit.find_by_sql(
					"select u.id, k.uqid k_uqid, k.name k_name, c.uqid ch_uqid, c.name ch_name, u.uqid, u.name, u.priority, u.unit_type,
						u.content_url, u.content_time, u.supplementary_description, u.content
					from knowledge k
						join chapter c on c.ref_know_id = k.id
						join unit u on u.ref_chapter_id = c.id
					where u.id = #{target.ref_unit_id}
					order by c.priority, u.priority").first

				quizzes = []
				if item.unit_type == 'quiz'
					quizzes = []
					item.questions.each {|item|
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
							answer: item.answer,
							solution: item.solution,
							explain: item.explain,
							explain_url: item.explain_url,
							solution: item.solution
						})
					}
				end

				sr = StudyResult.where(ref_user_id: session[:userinfo][:id], ref_unit_id: item.id).first
				profile = User.find_by_sql(
					"select u.first_name, u.last_name, u.userid, u.nouser
					from \"user\" u
						join classroom_member cm on cm.ref_user_id = u.id
					where cm.ref_classroom_id = #{target.id} and u.id = #{session[:userinfo][:id]}").first

				gm = GroupMember.where(ref_group_id: group.id, ref_user_id: session[:userinfo][:id]).first
				behavior = GroupMemberBehavior.find_by_sql(
					"select sum(case when gmb.points > 0 then 1 else 0 end) positive,
						sum(case when gmb.points < 0 then 1 else 0 end) negative,
						sum(gmb.points) total, count(gmb.id) count
					from group_member_behavior gmb
						join group_member gm on gm.ref_user_id = gmb.ref_user_id and gm.ref_group_id = gmb.ref_group_id
					where gm.ref_user_id = #{session[:userinfo][:id]} and gm.ref_group_id = #{group.id}").first

				content = {
					uqid: item.uqid,
					name: item.name,
					priority: item.priority,
					unit_type: item.unit_type,
					content_url: item.content_url,
					description: item.supplementary_description,
					content: item.content != nil ? (['poll', 'draw'].include?(item.unit_type) ? JSON.parse(item.content) : item.content) : nil,
					quizzes: quizzes,
					chapter: {
						uqid: item.ch_uqid,
						name: item.ch_name
					},
					knowledge: {
						uqid: item.k_uqid,
						name: item.k_name
					},
					study_result: sr != nil ? JSON.parse(sr.content) : nil,
					learning_time: sr != nil ? sr.learning_time : nil,
					profile: {
						email: profile.userid,
						first_name: profile.first_name,
						last_name: profile.last_name,
						full_name: parse_full_name(profile.first_name, profile.last_name, profile.userid, profile.nouser),
						nouser: profile.nouser,
						item_uqid: gm.uqid,
						behavior: {
							positive: behavior.positive,
							negative: behavior.negative,
							total: behavior.total,
							count: behavior.count
						}
					},
					lock_screen: target.lock_screen == nil ? false : target.lock_screen,
					dispatch_url: (target.dispatch_url != nil and target.dispatch_url != '') ? JSON.parse(target.dispatch_url) : nil,
					hangouts_url: target.hangouts_url == nil ? '' : target.hangouts_url,
					teacher_offline: target.teacher_offline == nil ? false : target.teacher_offline
				}

				render :json => content
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end
	
	def update_study_result
		if session[:userinfo] == nil
			render :json => { error: "We're sorry, but something went wrong." }
			return
		end
		
		group = Group.find_by_sql(
			"select g.*
			from \"group\" g
				join group_member gm on gm.ref_group_id = g.id
			where gm.status = 'approved'
				and gm.ref_user_id = #{session[:userinfo][:id]}
				and g.uqid = '#{params[:groupUqid]}'").first
		unit = Unit.where(uqid: params[:unitUqid]).first

		if group != nil and unit != nil
			target = Classroom.find_by_sql(
				"select cr.*
				from classroom cr
					join \"group\" g on g.id = cr.ref_group_id
				where cr.ref_group_id = #{group.id}").first

			if target != nil and params[:content] != nil
				sr = StudyResult.where(ref_user_id: session[:userinfo][:id], ref_unit_id: unit.id).first

				if sr == nil
					sr = StudyResult.new
					sr.ref_user_id = session[:userinfo][:id]
					sr.ref_unit_id = unit.id
					sr.ref_know_id = unit.ref_know_id
					sr.content = params[:content]
					sr.learning_time = Time.now
					sr.save()
				else
					sr.content = params[:content]
					sr.learning_time = Time.now
					sr.save()
				end

				render :json => { content: JSON.parse(sr.content), learning_time: sr.learning_time }
			else
				render :json => { error: "We're sorry, but something went wrong." }
			end
		else
			render :json => { error: "We're sorry, but something went wrong." }
		end
	end
end