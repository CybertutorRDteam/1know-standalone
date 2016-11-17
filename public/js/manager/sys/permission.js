_1know.controller('PermissionCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
    var self = this;

    self.getList = function() {
        $http.get([$utility.SERVICE_URL, '/sys/permission/permissions'].join(''))
        .then(function(response) {
            self.permissions = response.data;
        });
    }

    self.getContent = function(item) {
        self.curr = {};
        self.curr.permission_name = item.permission_name;
        $http.get([$utility.SERVICE_URL, '/sys/permission/export/', item.permission_name, '.json'].join(''))
        .then(function(response) {
            self.curr.account_codes = response.data;
        });
    }

    self.uploadPermission = function() {
        self.create.uploadBtnDisabled = true;
        self.create.data = {};
        var fd = new FormData();
        fd.append('inputFile', $("#permissionFile")[0].files[0]);
        $http({
            method: 'POST',
            url: [$utility.SERVICE_URL, '/sys/permission/upload_permission'].join(''),
            transformRequest: angular.identity,
            headers: {'Content-Type': undefined},
            data: fd,
            async: false,
            cache: false,
            contentType: false,
            processData: false
        }).then(function(response) {
                if (response.data.error) {
                    self.errMessage = response.data.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
                } else {
                    self.create.info = response.data;
                    self.create.layout = "checked";
                }
                self.create.uploadBtnDisabled = false;
            }, function(response) {
                self.create.uploadBtnDisabled = false;
        });
    }

    self.createCode = function() {
        if (self.create.info && self.create.info.filename) {
            self.create.createBtnDisabled = true;
            $http.post([$utility.SERVICE_URL, '/sys/permission/create_code'].join(''), {
                filename: self.create.info.filename
            })
            .then(function(response) {
                if (response.data.error) {
                    self.errMessage = response.data.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
                } else {
                    self.getContent({ permission_name: response.data.pname });
                    self.getList();
                    self.active.tab = "home";
                    self.currShow = true;
                }
                self.create.createBtnDisabled = false;
            }, function(response) {
                self.create.createBtnDisabled = false;
            });
        }
    }

    self.searchCode = function() {
        self.search = {};
        self.search.code = self.search_code;
        if (self.search.code) {
            $http.post([$utility.SERVICE_URL, '/sys/permission/search_code'].join(''), { code: self.search_code })
            .then(function(response) {
                self.search.account_codes = response.data;
            });
        }
    }

    self.resetCode = function(item) {
        $http.post([$utility.SERVICE_URL, '/sys/permission/reset/', item.id].join(''))
        .then(function(response) {
            if (response.data.error) {
                self.errMessage = response.data.error;
                $('#errorMessageModal').modal('show');
                $('#errorMessageModal').on('hidden.bs.modal', function() {
                    delete self.errMessage;
                });
            } else {
                item.new_code = response.data.new_code;
            }
        });
    }

    self.getChangeCode = function(item) {
        $http.get([$utility.SERVICE_URL, '/sys/permission/changeCode'].join(''))
        .then(function(response) {
            self.changes = response.data;
        });
    }

    self.activeTab = function(tabname) {
        self.active.tab = tabname;
        switch(tabname) {
            case "home":
                self.currShow = false;
                self.getList();
                break;
            case "search":
                break;
            case "create":
                self.create = {
                    layout: "upload",
                    uploadBtnDisabled: false,
                    createBtnDisabled: false,
                    info: {}
                };
                break;
            case "changes":
                self.getChangeCode();
                break;
        }
    }

    self.init = function() {
        self.getList();
        self.currShow = false;
        self.create = {
            layout: "upload",
            uploadBtnDisabled: false,
            createBtnDisabled: false,
            info: {}
        };
    }

    self.init();
})
