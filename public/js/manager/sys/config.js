_1know.controller('ConfigCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
    var self = this;

    self.editPicture = function(type) {
        self.editPictureType = type;
        self.setImageEvent();

        $timeout(function() {
            if (type === 'logo') {
                $('#input_logo').click();
            }
        },100);
    }

    self.setImageEvent = function() {
        var inputFile;
        if (self.editPictureType === 'logo') {
            inputFile = document.getElementById('input_logo');
        }
        if (inputFile === undefined) return;

        function readData(evt) {
            evt.stopPropagation();
            evt.preventDefault();
            var file = evt.dataTransfer !== undefined ? evt.dataTransfer.files[0] : evt.target.files[0];
            var reader = new FileReader();
            reader.onload = (function(theFile) {
                return function(e) {
                    var image = new Image();
                    image.src = e.target.result;
                    image.onload = function() {
                        var canvas = document.createElement('canvas');
                        var tmp = {};
                        // 等比例縮小，以高為主
                        tmp.height = image.height > 76 ? 76 : image.height;
                        tmp.width = image.height > 76 ? image.width * (76 / image.height) : image.width;

                        // 等比例縮小，以寬為主
                        canvas.width = tmp.width > 550 ? 550 : tmp.width;
                        canvas.height = tmp.width > 550 ? tmp.width * (550 / tmp.height) : tmp.height;

                        var ctx = canvas.getContext('2d');
                        ctx.drawImage(image, 0, 0, canvas.width, canvas.height);

                        $timeout(function() {
                            self.currentConfig.logo = canvas.toDataURL();
                        }, 100);
                    }
                }
            })(file);
            reader.readAsDataURL(file);
        }

        inputFile.addEventListener('click', function() {this.value = null;}, false);
        inputFile.addEventListener('change', readData, false);
    }

    self.removePicture = function(type) {
        if (type === 'logo') {
            self.currentConfig.logo = null;
        }
    }

    self.saveConfig = function() {
        $http({
            method: 'POST',
            url: [$utility.SERVICE_URL, '/sys/sysConfig'].join(''),
            data: { "content": self.currentConfig },
            async: false,
            cache: false,
            contentType: true,
            processData: true
        }).success(function(response, status) {
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
        self.currentConfig = {};
        $http.get([$utility.SERVICE_URL, '/sys/sysConfig'].join(''), {})
        .success(function(response, status) {
            if (!response.error) {
                response.forEach(function(item){
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
