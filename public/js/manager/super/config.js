_1know.controller('ConfigCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
    var self = this;

    self.saveConfig = function() {
        $http.post([$utility.SERVICE_URL, '/super/sysConfig'].join(''), { "content": self.currentConfig })
        .success(function(response, status) {
            if (response.error) {
                self.errMessage = response.error;
                $('#errorMessageModal').modal('show');
                $('#errorMessageModal').on('hidden.bs.modal', function() {
                    delete self.errMessage;
                });
            }
            else {
                self.loadConfig();
                self.errMessage = '系統配置_儲存成功';
                $('#errorMessageModal').modal('show');
                $('#errorMessageModal').on('hidden.bs.modal', function() {
                    delete self.errMessage;
                });
            }
        });
    };

    self.loadConfig = function() {
        self.currentConfig = {
            host_name: "",
            need_activation: "",
            oauth_client_id: "",
            oauth_client_secret: "",
            oauth_redirect_uri: "",
            upload_video_type: "",
            upload_video_server: "",
            upload_video_url: "",
            upload_doc_url: "",
            upload_image_url: "",
            upload_icons_url: "",
            konzesys_activate: "",
            konzesys_url: ""
        };
        $http.get([$utility.SERVICE_URL, '/super/sysConfig'].join(''), {})
        .success(function(response, status) {
            if (!response.error) {
                response.forEach(function(item){
                    switch (item.name) {
                        case 'need_activation':
                            item.content = (item.content == 'true');
                            break;
                        case 'konzesys_activate':
                            item.content = (item.content == 'true');
                            break;
                    }
                    self.currentConfig[item.name] = item.content;
                });
            }
            else {
                self.errMessage = response.error;
                $('#errorMessageModal').modal('show');
                $('#errorMessageModal').on('hidden.bs.modal', function() {
                    delete self.errMessage;
                });
            }
        });
    };

    self.init = function() {
        self.loadConfig();
    }

    self.init();
})
