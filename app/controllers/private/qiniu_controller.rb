require "qiniu"
require "qiniu/http"
require "net/http"
require "net/https"

class Private::QiniuController  < ApplicationController
    before_filter :establish_key

    def establish_key
        Qiniu.establish_connection! :access_key => 'bEA9JzrIBDkfXR5HPz6t1GnaEdNWw9erAip83Jwl',
                                    :secret_key => '5X39U2Kp12UQ9QB89UjVPEZBwTALwMxC4NV5uFf3'
    end

    def get_uptoken_test
        # 文件上传后的命名将遵循以下规则：
        # 客户端已指定Key，以Key命名；
        # 客户端未指定Key，上传策略中设置了saveKey，以saveKey的格式命名；
        # 客户端未指定Key，上传策略中未设置saveKey，以文件hash（etag）命名。
        # bucket：key形式是用来限制客户端上传的名字必须和服务端一致才可以
        # saveKey 是另一個參數 與 key 不同

        # ###### 皆不指定，只可新增檔案，以 client 的 key 為檔名，client 未設定就會是 hash ######
        # ### 上傳相同檔名不同內容會顯示 => 文件已存在。(614：file exists)
        # ### 相同檔案相同檔名不會出錯
        # put_policy = Qiniu::Auth::PutPolicy.new "iknow"

        # put_policy = Qiniu::Auth::PutPolicy.new(
        #     'iknow'
        #     # bucket,     # 存储空间
        #     # key,        # 最终资源名，可省略，即缺省为“创建”语义
        #     # expires_in, # 相对有效期，可省略，缺省为3600秒后 uptoken 过期
        #     # deadline    # 绝对有效期，可省略，指明 uptoken 过期期限（绝对值），通常用于调试
        # )

        # ###### 影片測試 ######
        # 1. 轉成 mp4
        # 2. 對原資料HLS切片，檔名sample.m3u8
        # 3. 擷取縮圖為 jpg 格式，第7秒，480x360，檔名sample.m3u8
        put_policy = Qiniu::Auth::PutPolicy.new 'iknow'
        put_policy.mime_limit = "image/*;video/*"
        # 目標路徑的EncodedEntryURI格式
        # entry = Qiniu::Utils.urlsafe_base64_encode('iknow:example.m3u8')
        # ops_data = ["avthumb/mp4", ";avthumb/m3u8/segtime/15/vb/440k|saveas/#{entry}", ";vframe/jpg/offset/7/w/480/h/360"]
        # put_policy.persistent_ops = ops_data * "" # ary to string
        put_policy.persistent_notify_url = "http://140.126.57.223:8080/private/qiniu/notify"

        # ###### 縮圖200x200，檔名sample.jpg ######
        # entry = Qiniu::Utils.urlsafe_base64_encode('iknow:sample.jpg')
        # put_policy = Qiniu::Auth::PutPolicy.new "iknow"
        # put_policy.mime_limit = "image/*"
        # put_policy.persistent_ops = "imageView2/1/w/200/h/200|saveas/#{entry}"
        # put_policy.persistent_notify_url = "http://140.126.57.223:8080/private/qiniu/notify"

        # ###### 指定檔名 = client 的 key 同為client_sample1.jpg，這樣才能重複檔名 ######
        # put_policy = Qiniu::Auth::PutPolicy.new "iknow", "client_sample1.jpg" # 或 "iknow:client_sample1.jpg"

        uptoken = Qiniu::Auth.generate_uptoken(put_policy)
        render :json => { uptoken: uptoken }
    end

    def notify
        # 某個檔已轉檔完成
        render :text => nil
    end

    def get_uptoken
        ####################################################################################
        # 傳入
        # type = [ video | doc | image ]
        # bucket = [ custom | iknow ]
        # 圖檔：直接上傳
        # 文件：上傳後轉 PDF？
        # 影片：上傳後轉 m3u8，兩檔並存
        ####################################################################################

        # A. 單一帳號方案(single)
        # 空間：iknow
        # 命名：使用規則前綴+原始檔名 /userid/type/原始檔名；

        # B. 父子帳號方案(parent, parent and child)
        # 空間：iknow
        # 命名：使用規則前綴+原始檔名 /type/原始檔名；

        # C. 個人帳號方案(personal)
        # 空間：自訂
        # 命名：原始檔名；客户端指定Key

        type = params[:type];
        bucket = params[:bucket] || 'iknow'
        filename = params[:filename] || ''
        model = 'personal'
        prefix = getPrefix(model, type)

        case model
        when 'single'
            put_policy = Qiniu::Auth::PutPolicy.new "iknow"
        when 'parent'
            put_policy = Qiniu::Auth::PutPolicy.new "iknow"
        when 'personal'
            put_policy = Qiniu::Auth::PutPolicy.new bucket
        end

        case type
        when 'video'
            put_policy.mime_limit = "video/mp4"
            # 轉m3u8後儲存的目標路徑，以EncodedEntryURI格式編碼
            # encodedEntryURI = Qiniu::Utils.urlsafe_base64_encode("#{bucket}:#{prefix}#{filename}-m3u8")
            # # 以预转持久化形式，将mp4视频按video_240k预设规格切片（15秒一片）
            # ops_data = "avthumb/mp4;avthumb/m3u8/segtime/15/video_240k|saveas/#{encodedEntryURI}"
            # put_policy.persistent_ops = ops_data
            # put_policy.persistent_notify_url = "http://140.126.57.223:8080/private/qiniu/notify"
        when 'doc'
        when 'image'
            put_policy.mime_limit = "image/*"
        end

        # 指定檔名
        put_policy.save_key = prefix + filename
        uptoken = Qiniu::Auth.generate_uptoken(put_policy)
        render :text => uptoken
    end

    def management
        type = params[:type];
        bucket = params[:bucket] || 'iknow'
        marker = params[:marker] == '0' ? '' : params[:marker]
        limit = 3
        delimiter = ''
        model = 'personal'
        prefix = getPrefix(model, type)

        list_policy = Qiniu::Storage::ListPolicy.new(bucket, limit, prefix, delimiter)
        list_policy.marker = marker
        code, body, response_headers, has_more, new_list = Qiniu::Storage.list(list_policy)
        if (code != 200)
            render :json => { error: body.error }
        else
            render :json => body
        end
    end

    # 获取账户管理凭证
    def get_token
        uri = URI('https://acc.qbox.me/oauth2/token')
        res = Net::HTTP.post_form(uri,
            'grant_type' => 'password',
            'username' => 'henry@dr-cloud.net', #UrlEncoded
            'password' => 'cyber3579080' #UrlEncoded
        )

        if (res.body.error)
            render :json => res.body
        else
            session[:qiniu_access_token] = res.body.access_token
            session[:qiniu_expires_in] = res.body.expires_in
            session[:qiniu_refresh_token] = res.body.refresh_token
        end
    end

    # 刷新账户管理凭证
    def get_refresh_token
        uri = URI('https://acc.qbox.me/oauth2/token')
        res = Net::HTTP.post_form(uri,
            'grant_type' => 'refresh_token',
            'refresh_token' => session[:qiniu_refresh_token] #UrlEncoded
        )

        if (res.body.error)
            render :json => res.body
        else
            session[:qiniu_access_token] = res.body.access_token
            session[:qiniu_expires_in] = res.body.expires_in
            session[:qiniu_refresh_token] = res.body.refresh_token
        end
    end

    # 获取账户信息
    def get_user_info
        uri = URI.parse('https://acc.qbox.me/user/info')
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true
        req = Net::HTTP::Post.new(uri.path, initheader = {
            'Content-Type' =>'application/x-www-form-urlencoded',
            'Authorization' => 'Bearer ' + session[:qiniu_access_token]
        })
        res = https.request(req)

        if (res.body.error)
            render :json => res.body
        else
            # res.body.userid
            # res.body.uid
            # res.body.parent_uid
            # res.body.email
            # res.body.is_disabled
        end
    end

    # 创建子账号
    def user_create_child
        uri = URI.parse('https://acc.qbox.me/user/create_child')
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true
        req = Net::HTTP::Post.new(uri.path, initheader = {
            'Content-Type' =>'application/x-www-form-urlencoded',
            'Authorization' => 'Bearer w6PQLatuvjv16mdiRGhTyy3QRBFAcHLR-It0s61H1t1IUZ_8WXOJeZcLW3fAShpFfMqNiD6wEH4qNVzaHEHiGKUQC6Kr1UdnkBk5_h1gJNTb1ef1_Qqm4oWonQSKjKnedUXHUcpLDI-Mch1SHALLWjTVX1XxVzQPhTOBlzu_FA6wRGWluBnUGSscbsmtOv4mJeCQScSXb6a_Bc0Tw-cmFA=='
        })
        req.set_form_data(
            'email' => 'test1@flip.dr-cloud.net', #xxx@flip.dr-cloud.net
            'password' => 'cyber12345'
        )
        res = https.request(req)

        if (res.body.error)
            render :json => res.body
        else
            # "device_num": 0,
            # "email": "test1@flip.dr-cloud.net",
            # "invitation_num": 0,
            # "is_activated": true,
            # "is_disabled": false,
            # "last_parent_operation_at": "2015-10-22T18:39:44.23+08:00",
            # "parent_uid": 1380438574,
            # "uid": 1380581367,
            # "user_type": 4,
            # "userid": "test1@flip.dr-cloud.net",
            # "username": ""
        end
    end

    # 禁用子账号
    def user_disable_child
        # params[:uid], params[:reason]
        if params[:uid]
            uri = URI.parse('https://acc.qbox.me/user/disable_child')
            https = Net::HTTP.new(uri.host, uri.port)
            https.use_ssl = true
            req = Net::HTTP::Post.new(uri.path, initheader = {
                'Content-Type' =>'application/x-www-form-urlencoded',
                'Authorization' => 'Bearer ' + session[:qiniu_access_token]
            })
            req.set_form_data(
                'uid' => params[:uid],
                'reason' => params[:reason] #UrlEncoded
            )
            res = https.request(req)

            if (res.body.error)
                render :json => res.body
            else
                # "device_num": 0,
                # "email": "test1@flip.dr-cloud.net",
                # "invitation_num": 0,
                # "is_activated": true,
                # "is_disabled": true,
                # "last_parent_operation_at": "2015-10-22T18:46:56.175+08:00",
                # "parent_uid": 1380438574,
                # "uid": 1380581367,
                # "user_type": 32772,
                # "userid": "test1@flip.dr-cloud.net",
                # "username": ""
            end
        end
    end

    # 启用子账号
    def user_enable_child
        if params[:uid]
            uri = URI.parse('https://acc.qbox.me/user/enable_child')
            https = Net::HTTP.new(uri.host, uri.port)
            https.use_ssl = true
            req = Net::HTTP::Post.new(uri.path, initheader = {
                'Content-Type' =>'application/x-www-form-urlencoded',
                'Authorization' => 'Bearer ' + session[:qiniu_access_token]
            })
            req.set_form_data(
                'uid' => params[:uid]
            )
            res = https.request(req)

            if (res.body.error)
                render :json => res.body
            else
                # "device_num": 0,
                # "email": "test1@flip.dr-cloud.net",
                # "invitation_num": 0,
                # "is_activated": true,
                # "is_disabled": false,
                # "last_parent_operation_at": "2015-10-22T18:49:53.839+08:00",
                # "parent_uid": 1380438574,
                # "uid": 1380581367,
                # "user_type": 4,
                # "userid": "test1@flip.dr-cloud.net",
                # "username": ""
            end
        end
    end

    # 列举子账号
    def user_children
        if params[:offset] and params[:limit]
            uri = URI.parse('https://acc.qbox.me/user/children')
            https = Net::HTTP.new(uri.host, uri.port)
            https.use_ssl = true
            req = Net::HTTP::Get.new(uri.path, initheader = {
                'Content-Type' =>'application/x-www-form-urlencoded',
                'Authorization' => 'Bearer ' + session[:qiniu_access_token]
            })
            req.set_form_data(
                'offset' => params[:offset], #0
                'limit' => params[:limit] #1000
            )
            res = https.request(req)
            render :json => res.body

            # [{
            #     "device_num": 0,
            #     "email": "test1@flip.dr-cloud.net",
            #     "invitation_num": 0,
            #     "is_activated": true,
            #     "is_disabled": false,
            #     "last_parent_operation_at": "2015-10-22T18:49:53.839+08:00",
            #     "parent_uid": 1380438574,
            #     "uid": 1380581367,
            #     "user_type": 4,
            #     "userid": "test1@flip.dr-cloud.net",
            #     "username": ""
            # }]
        end
    end

    # 查询子账号密钥
    def user_child_key
        if params[:uid]
            uri = URI.parse('https://acc.qbox.me/user/child_key')
            https = Net::HTTP.new(uri.host, uri.port)
            https.use_ssl = true
            req = Net::HTTP::Post.new(uri.path, initheader = {
                'Content-Type' =>'application/x-www-form-urlencoded',
                'Authorization' => 'Bearer ' + session[:qiniu_access_token]
            })
            req.set_form_data(
                'uid' => params[:uid]
            )
            res = https.request(req)

            if (res.body.error)
                render :json => res.body
            else
                # {
                #     "uid": 1380581367,
                #     "appName": "default",
                #     "appId": 2403763639,
                #     "key": "hTEY-7K8l6dvao5OvzElzqwLywVK_GXgwsm04XuU",
                #     "secret": "ZI_qtS_dnZKiZHYFzSEkkQvYGvBRpO4ou-MHqjX_",
                #     "last-modified": "2015-10-23T14:11:09.06+08:00",
                #     "creation-time": "2015-10-23T14:11:09.06+08:00",
                #     "last-modified2": "0001-01-01T00:00:00Z",
                #     "creation-time2": "0001-01-01T00:00:00Z"
                # }
            end


        end
    end

    # 存储空间
    def buckets
        Qiniu.establish_connection! :access_key => 'hTEY-7K8l6dvao5OvzElzqwLywVK_GXgwsm04XuU',
                                    :secret_key => 'ZI_qtS_dnZKiZHYFzSEkkQvYGvBRpO4ou-MHqjX_'

        url = Qiniu::Config.settings[:rs_host] + '/buckets'
        resp_code, resp_body, resp_headers = Qiniu::HTTP.management_post(url)
        if resp_code == 200
            render :json => resp_body
        else
            render :json => { error: resp_body }
        end
    end

    # 创建存储空间
    def mkbucket
        Qiniu.establish_connection! :access_key => 'hTEY-7K8l6dvao5OvzElzqwLywVK_GXgwsm04XuU',
                                    :secret_key => 'ZI_qtS_dnZKiZHYFzSEkkQvYGvBRpO4ou-MHqjX_'

        url = Qiniu::Config.settings[:rs_host] + '/mkbucket/iknow/public/1'
        resp_code, resp_body, resp_headers = Qiniu::HTTP.management_post(url)
        # if resp_code == 200
        #     render :json => resp_code
        # else
        #     render :json => resp_body
        # end
    end

    private
    def getPrefix(model, type)
        case model
        when 'single'
            prefix = userid + '/' + type + '/'
        when 'parent'
            prefix = type + '/'
        when 'personal'
            prefix = ''
        end
        return prefix
    end
end

# :scope                  => "scope"               ,
# :save_key               => "saveKey"             ,
# :end_user               => "endUser"             ,
# :return_url             => "returnUrl"           ,
# :return_body            => "returnBody"          ,
# :callback_url           => "callbackUrl"         ,
# :callback_host          => "callbackHost"        ,
# :callback_body          => "callbackBody"        ,
# :callback_body_type     => "callbackBodyType"    ,
# :persistent_ops         => "persistentOps"       ,
# :persistent_notify_url  => "persistentNotifyUrl" ,
# :persistent_pipeline    => "persistentPipeline"  ,

# # 数值类型参数
# :deadline               => "deadline"            ,
# :insert_only            => "insertOnly"          ,
# :fsize_limit            => "fsizeLimit"          ,
# :callback_fetch_key     => "callbackFetchKey"    ,
# :detect_mime            => "detectMime"          ,
# :mime_limit             => "mimeLimit"
