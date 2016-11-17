class Private::SuperadminController  < ApplicationController
    before_filter :require_login_superaccount

    def require_login_superaccount
        if (session['role'] != "superadmin")
            render :json => { error: "We're sorry, but something went wrong. [role]" }
        end
    end

    # 取得所有管理者資料
    def get_accounts
        item = AdminAccount.order("account").select("id, account, acc_name")
        render :json => item
    end

    # 建立管理者資料
    def create_account
        account = params[:acc] || ''
        password = params[:pass] || ''
        password_confirmation = params[:pass_confirmation] || ''
        acc_name = params[:acc_name] || ''
        if (account != "" && password != "" && password_confirmation != "")
            password = Digest::SHA1.hexdigest password
            password_confirmation = Digest::SHA1.hexdigest password_confirmation
            adminAccount = AdminAccount.new({
                :account => account,
                :password => password,
                :password_confirmation => password_confirmation,
                :acc_name => acc_name
            })
            if adminAccount.valid?
                adminAccount.save!
                render :json => { success: "Well done!" }
            else
                render :json => { error: adminAccount.errors.messages }
            end
        else
            render :json => { error: "We're sorry, but something went wrong." }
        end
    end

    # 變更管理者資料
    def set_account
        id = params[:id] || ''
        newpwd = params[:newpwd] || ''
        newpwd_confirmation = params[:newpass_confirmation] || ''
        acc_name = params[:acc_name] || ''
        if (id != "" && newpwd != "" && newpwd_confirmation != "")
            adminAccount = AdminAccount.where([ "id = ?", id ]).take
            if (!adminAccount.nil?)
                newpwd = Digest::SHA1.hexdigest newpwd
                newpwd_confirmation = Digest::SHA1.hexdigest newpwd_confirmation
                adminAccount.password = newpwd
                adminAccount.password_confirmation = newpwd_confirmation
                adminAccount.acc_name = acc_name if acc_name != ""
                if adminAccount.valid?
                    adminAccount.save!
                    render :json => { success: "Well done!" }
                else
                    render :json => { error: adminAccount.errors.messages }
                end
            else
                render :json => { error: "We're sorry, but something went wrong." }
            end
        else
            render :json => { error: "We're sorry, but something went wrong." }
        end
    end

    # 刪除管理者
    def destroy_accounts
        id = params[:id] || ''
        if (id != "")
            adminAccount = AdminAccount.where([ "id = ?", id ]).take
            if (!adminAccount.nil?)
                account = AdminAccount.find(id)
                account.destroy
                render :json => { success: "Well done!" }
            else
                render :json => { error: "We're sorry, but something went wrong." }
            end
        else
            render :json => { error: "We're sorry, but something went wrong." }
        end
    end

    # 啟動碼異動清單
    def change_code
        item = CancelCodeLog.order("updated_at DESC").all
        render :json => item
    end

    # 取得系統設置值
    def get_sys_config
        item = Sysconfig.where({ target: ["system"] }).select("name, content")
        render :json => item
    end

    # 設定系統設置值
    def set_sys_config
        content = params[:content] || {}
        # 刪除舊資料
        sysconfig = Sysconfig.where({ target: ["system"] })
        sysconfig.destroy_all

        # 重新建立
        # key = host_name, need_activation,
        # oauth_client_id, oauth_client_secret, oauth_redirect_uri,
        # upload_video_type, upload_video_server, upload_video_url, upload_doc_url, upload_image_url, upload_icons_url
        # konzesys_activate, konzesys_url
        content.each do |key, value|
            sysconfig = Sysconfig.new({
                :target => 'system',
                :name => key,
                :content => value.to_s,
                :ref_admin_accounts_id => session['admin_id']
            })
            sysconfig.save! if sysconfig.valid?
            case key
            when 'upload_doc_url'
                APP_CONFIG['upload_path'][0]['doc'] = value
            when 'upload_image_url'
                APP_CONFIG['upload_path'][0]['image'] = value
            when 'upload_video_url'
                APP_CONFIG['upload_path'][0]['video'] = value
            when 'konzesys_activate'
                APP_CONFIG['konzesys']['activate'] = (value.to_s == 'true')
            when 'konzesys_url'
                APP_CONFIG['konzesys']['url'] = value
            when 'oauth_client_id'
                APP_CONFIG['client_id'] = value
            when 'oauth_client_secret'
                APP_CONFIG['client_secret'] = value
            when 'oauth_redirect_uri'
                APP_CONFIG['redirect_uri'] = value
            when 'need_activation'
                APP_CONFIG['need_activation'] = (value.to_s == 'true')
            else
                APP_CONFIG[key] = value
            end
        end

        render :json => { success: "Well done!" }
    end
end