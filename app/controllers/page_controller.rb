require "open-uri"

class PageController < ApplicationController
    before_filter :get_app_config

    def get_app_config
        @APP_CONFIG = APP_CONFIG
    end

    def user
        item = User.where(uqid: params[:uqid]).first

        if item != nil
            knowledges = Knowledge.find_by_sql(
                "select k.uqid, k.name
                from knowledge k
                    join draft_knowledge dk on dk.uqid = k.uqid
                    join draft_knowledge_editor dke on dke.ref_know_id = dk.id
                where dke.ref_user_id = #{item.id} and dke.is_show = true and k.is_public = true
                group by k.uqid, k.name, k.last_update
                order by k.last_update desc")

            knowledge = []
            knowledges.each {|item|
                knowledge.push({
                    uqid: item.uqid,
                    name: item.name,
                    logo: get_image('knowledge', { uqid: item.uqid }),
                    page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
                })
            }

            @content = {
                uqid: item.uqid,
                email: item.userid,
                first_name: item.first_name,
                last_name: item.last_name,
                full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                description: item.description,
                website: item.website,
                facebook: item.facebook,
                twitter: item.twitter,
                banner: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'banner' }),
                photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}",
                knowledge: knowledge,
                nouser: item.nouser
            }
        else
            redirect_to '/404.html'
        end
    end

    def knowledge
        know = Knowledge.find_by_sql(
            "select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed,
                sum(case when r.rating = 5 then 1 else 0 end) rating5,
                sum(case when r.rating = 4 then 1 else 0 end) rating4,
                sum(case when r.rating = 3 then 1 else 0 end) rating3,
                sum(case when r.rating = 2 then 1 else 0 end) rating2,
                sum(case when r.rating = 1 then 1 else 0 end) rating1
            from knowledge k
                left join reader r on r.ref_know_id = k.id
            where k.uqid = '#{params[:uqid]}' and k.is_destroyed = false
            group by k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed").first

        if know != nil and !know.is_destroyed
            subscribed = false
            groups = []
            channels = []
            if session[:userinfo] != nil
                reader = Reader.where(ref_know_id: know.id, ref_user_id: session[:userinfo][:id], is_archived: false).first
                subscribed = true if reader != nil

                groups = Group.find_by_sql(
                    "select g.uqid, g.name, gm.role, gk.id joined
                    from \"group\" g
                        join group_member gm on gm.ref_group_id = g.id and gm.ref_user_id = #{session[:userinfo][:id]}
                        left join group_knowledge gk on gk.ref_group_id = g.id and gk.ref_know_id = #{know.id}
                    where gm.role in ('owner', 'admin') and g.is_destroyed = false
                    order by g.name")
            end

            chapters = []
            know.chapters.each {|c|
                if c.is_destroyed == nil
                    units = []
                    c.units.each {|u|
                        if u.is_destroyed == nil
                            quizzes = []
                            if u.unit_type == 'quiz'
                                u.questions.each {|item|
                                    if item.is_destroyed == nil
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
                                            explain_url: item.explain_url
                                        })
                                    end
                                }
                            end

                            units.push({
                                uqid: u.uqid,
                                name: u.name,
                                priority: u.priority,
                                unit_type: u.unit_type,
                                content_url: u.content_url,
                                content_time: u.content_time,
                                description: u.supplementary_description,
                                content: u.content != nil ? ((u.unit_type == 'poll' or u.unit_type == 'draw') ? JSON.parse(u.content) : u.content) : nil,
                                quizzes: quizzes,
                                preview: know.is_public ? true : (u.is_preview == nil ? false : u.is_preview)
                            })
                        end
                    }

                    chapters.push({
                        name: c.name,
                        priority: c.priority,
                        units: units
                    })
                end
            }

            items = DraftKnowledgeEditor.find_by_sql(
                "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
                from draft_knowledge_editor dke
                    join \"user\" u on u.id = dke.ref_user_id
                    join draft_knowledge dk on dk.id = dke.ref_know_id
                    join knowledge k on k.uqid = dk.uqid
                where k.id = #{know.id} and (dke.is_show = true or dke.role = 'owner')
                order by dke.order")

            editors = []
            items.each {|e|
                editors.push({
                    uqid: e.uqid,
                    email: e.userid,
                    first_name: e.first_name,
                    last_name: e.last_name,
                    full_name: parse_full_name(e.first_name, e.last_name, e.userid, e.nouser),
                    photo: get_image('user', { uqid: e.uqid, nouser: e.nouser, type: 'photo' }),
                    page: "#{request.protocol}#{request.host_with_port}/user/#{e.uqid}",
                    nouser: e.nouser
                })
            }

            total_rate = know.rating5 + know.rating4 + know.rating3 + know.rating2 + know.rating1
            average_rate = ((know.rating5 * 5.0) + (know.rating4 * 4.0) + (know.rating3 * 3.0) + (know.rating2 * 2.0) + know.rating1).to_f
            rating = [know.rating5, know.rating4, know.rating3, know.rating2, know.rating1]

            @content = {
                uqid: know.uqid,
                name: know.name,
                description: know.description,
                release: know.last_update,
                reader: know.readers.size,
                code: know.code,
                privacy: know.is_public ? true : false,
                editors: editors,
                chapters: chapters,
                subscribed: subscribed,
                rating: rating,
                total_rate: total_rate,
                average_rate: average_rate != 0 ? average_rate / total_rate : 0,
                logo: get_image('knowledge', { uqid: know.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
                share_page: "#{request.protocol}#{request.host_with_port}/watch?k=#{know.uqid}",
                groups: groups
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def group
        group = Group.where(uqid: params[:uqid], is_destroyed: false).first

        if group != nil
            members = User.find_by_sql(
                "select u.userid, u.uqid, u.first_name, u.last_name, u.photo, u.nouser
                from \"user\" u
                    join group_member gm on gm.ref_user_id = u.id
                where gm.ref_group_id = #{group.id} and gm.status = 'approved'
                order by gm.last_view_time desc nulls last, gm.sign_time desc
                limit 24")

            member = []
            members.each {|item|
                member.push({
                    uqid: item.uqid,
                    email: item.userid,
                    first_name: item.first_name,
                    last_name: item.last_name,
                    full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                    nouser: item.nouser,
                    photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                    page: "#{request.protocol}#{request.host_with_port}/user/#{item.uqid}"
                })
            }

            knowledges = Knowledge.find_by_sql(
                "select k.uqid, k.name
                from knowledge k
                    join group_knowledge gk on gk.ref_know_id = k.id
                where gk.ref_group_id = #{group.id} and k.is_public = true and gk.is_show = true
                order by gk.priority")

            knowledge = []
            knowledges.each {|item|
                knowledge.push({
                    uqid: item.uqid,
                    name: item.name,
                    logo: get_image('knowledge', { uqid: item.uqid }),
                    page: "#{request.protocol}#{request.host_with_port}/knowledge/#{item.uqid}"
                })
            }

            activities = GroupActivity.find_by_sql(
                "select ga.uqid, ga.name, ga.description, ga.goal
                from group_activity ga
                where ga.ref_group_id = #{group.id} and ga.is_show = true
                order by ga.priority")

            activity = []
            activities.each {|item|
                activity.push({
                    uqid: item.uqid,
                    name: item.name,
                    description: item.description,
                    goal: JSON.parse(item.goal)
                })
            }

            joined = false
            if session[:userinfo] != nil
                gm = GroupMember.where(ref_user_id: session[:userinfo][:id], ref_group_id: group.id, status: 'approved').first
                joined = gm == nil ? false : true
            end

            @content = {
                uqid: group.uqid,
                name: group.name,
                description: group.description,
                knowledge_size: knowledges.size,
                member_size: members.size,
                activity_size: activity.size,
                knowledge: knowledge,
                member: member,
                activity: activity,
                privacy: group.is_public,
                content: group.content == nil ? [] : JSON.parse(group.content),
                logo: get_image('group', { uqid: group.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/group/#{group.uqid}",
                joined: joined
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def channel
        channel = Channel.where(uqid: params[:uqid]).first

        subscribed = false
        if channel != nil
            if session[:userinfo] != nil
                item = ChannelMember.where(ref_user_id: session[:userinfo][:id], ref_channel_id: channel.id, status: 'approved').first
                subscribed = true if item != nil
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

                    sub_knowledges = []
                    if session[:userinfo] != nil
                        knows = CategoryKnowledge.find_by_sql(
                            "select k.uqid, k.name, ck.priority, sum(case when r.rating is null then 0 else r.rating end) rating, sum(case when r.rating is null then 0 else 1 end) rate_count, count(r.id) reader, r2.id reader_id
                            from category_knowledge ck
                                join category ca on ca.id = ck.ref_category_id
                                join knowledge k on k.id = ck.ref_know_id
                                left join reader r on r.ref_know_id = k.id
                                left join reader r2 on r2.ref_know_id = k.id and r2.ref_user_id = #{session[:userinfo][:id]} and r2.is_archived != true
                            where ca.id = #{c.id}
                            group by k.uqid, k.name, ck.priority, r2.id
                            order by ck.priority")
                    else
                        knows = CategoryKnowledge.find_by_sql(
                            "select k.uqid, k.name, ck.priority, sum(case when r.rating is null then 0 else r.rating end) rating, sum(case when r.rating is null then 0 else 1 end) rate_count, count(r.id) reader
                            from category_knowledge ck
                                join category ca on ca.id = ck.ref_category_id
                                join knowledge k on k.id = ck.ref_know_id
                                left join reader r on r.ref_know_id = k.id
                            where ca.id = #{c.id}
                            group by k.uqid, k.name, ck.priority
                            order by ck.priority")
                    end

                    knows.each {|know|
                        sub_knowledges.push({
                            uqid: know.uqid,
                            name: know.name,
                            priority: know.priority,
                            rating: know.rating.to_f == 0 ? 0 : ((know.rating.to_f / know.rate_count.to_f) * 10).ceil / 10.0,
                            reader: know.reader.to_i,
                            subscribed: session[:userinfo] == nil ? false : (know.reader_id != nil ? true : false),
                            logo: get_image('knowledge', { uqid: know.uqid }),
                            page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
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

            @content = {
                uqid: channel.uqid,
                name: channel.name,
                description: channel.description,
                logo: get_image('channel', { uqid: channel.uqid }),
                page: "#{request.protocol}#{request.host_with_port}/channel/#{channel.uqid}",
                categories: categories,
                subscribed: subscribed
            }

            if session[:userinfo] != nil
                item = User.find(session[:userinfo][:id])
                if item != nil
                    if item.language != nil
                        language = JSON.parse(item.language)
                        if language['type'] == 'zh-tw'
                            language = {title: '繁體中文', type: 'zh-tw'}
                        elsif language['type'] == 'zh-cn'
                            language = {title: '简体中文', type: 'zh-cn'}
                        else
                            language = {title: 'English', type: 'en-us'}
                        end
                    else
                        language = {title: 'English', type: 'en-us'}
                    end

                    account = {
                        uqid: item.uqid,
                        email: item.userid,
                        first_name: item.first_name,
                        last_name: item.last_name,
                        full_name: parse_full_name(item.first_name, item.last_name, item.userid, item.nouser),
                        photo: get_image('user', { uqid: item.uqid, nouser: item.nouser, type: 'photo' }),
                        nouser: item.nouser,
                        language: language
                    }
                else
                    account = nil
                end
            else
                account = nil
            end

            @content['account'] = account

            respond_to do |format|
                format.html
                format.json { render :json => @content }
            end
        else
            respond_to do |format|
                format.html { redirect_to '/404.html' }
                format.json { render :json => { error: "We're sorry, but something went wrong." } }
            end
        end
    end

    def package_knowledge
        know = Knowledge.find_by_sql(
            "select k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed,
                sum(case when r.rating = 5 then 1 else 0 end) rating5,
                sum(case when r.rating = 4 then 1 else 0 end) rating4,
                sum(case when r.rating = 3 then 1 else 0 end) rating3,
                sum(case when r.rating = 2 then 1 else 0 end) rating2,
                sum(case when r.rating = 1 then 1 else 0 end) rating1
            from knowledge k
                left join reader r on r.ref_know_id = k.id
            where k.uqid = '#{params[:uqid]}'
            group by k.id, k.uqid, k.name, k.description, k.last_update, k.code, k.is_public, k.is_destroyed").first

        if know == nil
            render :json => { error: "We're sorry, but something went wrong." }
            return
        end

        owner = DraftKnowledgeEditor.find_by_sql(
            "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
            from draft_knowledge_editor dke
                join \"user\" u on u.id = dke.ref_user_id
                join draft_knowledge dk on dk.id = dke.ref_know_id
                join knowledge k on k.uqid = dk.uqid
            where k.id = #{know.id} and dke.ref_user_id = #{session[:userinfo][:id]}
            order by dke.order").first

        if owner == nil
            render :json => { error: "We're sorry, but something went wrong." }
            return
        end

        chapters = []
        know.chapters.each {|c|
            if c.is_destroyed == nil
                units = []
                c.units.each {|u|
                    if u.is_destroyed == nil
                        quizzes = []
                        if u.unit_type == 'quiz'
                            u.questions.each {|item|
                                if item.is_destroyed == nil
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
                                        explain_url: item.explain_url
                                    })
                                end
                            }
                        end

                        units.push({
                            uqid: u.uqid,
                            name: u.name,
                            priority: u.priority,
                            unit_type: u.unit_type,
                            content_url: u.content_url,
                            content_time: u.content_time,
                            description: u.supplementary_description,
                            content: u.content != nil ? ((u.unit_type == 'poll' or u.unit_type == 'draw') ? JSON.parse(u.content) : u.content) : nil,
                            quizzes: quizzes,
                            preview: u.is_preview == nil ? false : u.is_preview
                        })
                    end
                }

                chapters.push({
                    name: c.name,
                    priority: c.priority,
                    units: units
                })
            end
        }

        items = DraftKnowledgeEditor.find_by_sql(
            "select u.uqid, u.userid, u.first_name, u.last_name, u.photo, u.nouser
            from draft_knowledge_editor dke
                join \"user\" u on u.id = dke.ref_user_id
                join draft_knowledge dk on dk.id = dke.ref_know_id
                join knowledge k on k.uqid = dk.uqid
            where k.id = #{know.id} and dke.is_show = true
            order by dke.order")

        editors = []
        items.each {|e|
            editors.push({
                uqid: e.uqid,
                email: e.userid,
                first_name: e.first_name,
                last_name: e.last_name,
                full_name: parse_full_name(e.first_name, e.last_name, e.userid, e.nouser),
                photo: get_image('user', { uqid: e.uqid, nouser: e.nouser, type: 'photo' }),
                page: "#{request.protocol}#{request.host_with_port}/user/#{e.uqid}",
                nouser: e.nouser
            })
        }

        total_rate = know.rating5 + know.rating4 + know.rating3 + know.rating2 + know.rating1
        rating = [know.rating5, know.rating4, know.rating3, know.rating2, know.rating1]
        tmp = Array.new(rating)
        tmp.each do |r|
            c = r.to_f/total_rate.to_f*100
            rating << c.nan?? 0 : c
        end
        

        content = {
            uqid: know.uqid,
            name: know.name,
            description: know.description,
            reader: know.readers.size,
            code: know.code,
            privacy: know.is_public ? true : false,
            editors: editors,
            chapters: chapters,
            rating: rating,
            logo: get_image('knowledge', { uqid: know.uqid }),
            page: "#{request.protocol}#{request.host_with_port}/knowledge/#{know.uqid}",
            root_url: "#{request.protocol}#{request.host_with_port}"
        }

        item = User.find(session[:userinfo][:id])

        if item.language != nil
            language = JSON.parse(item.language)
            if language['type'] == 'zh-tw'
                language = {title: '繁體中文', type: 'zh-tw'}
            elsif language['type'] == 'zh-cn'
                language = {title: '简体中文', type: 'zh-cn'}
            else
                language = {title: 'English', type: 'en-us'}
            end
        else
            language = {title: 'English', type: 'en-us'}
        end

        account = {
            uqid: item.uqid,
            email: item.userid,
            first_name: item.first_name,
            last_name: item.last_name,
            nouser: item.nouser,
            language: language
        }
        
        html = render_to_string(
            partial: '/page/package_knowledge.html.erb',
            locals: {content: content, account: account},
            layout: false
        )

        send_data html, :filename => "#{content[:name]}.html"
    end
end