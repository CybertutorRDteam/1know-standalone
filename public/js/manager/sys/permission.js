_1know.controller('PermissionCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility, $window, $interval) {
	var self = this;

	self.disableAccount = function(dateStr) {
		return new Date(dateStr) < new Date();
	}

	self.getList = function() {
		$http.get([$utility.SERVICE_URL, '/sys/permission/permissions'].join(''))
		.then(function(response) {
			self.permissions = response.data;
		});
	}

	self.getImportList = function() {
		$http.get([$utility.SERVICE_URL, '/sys/permission/i_permissions'].join(''))
		.then(function(response) {
			self.i_permissions = response.data;
			$scope.home2AccountTotal = 0;
			angular.forEach(self.i_permissions, function(item, key){
				if(item.expired_date && !self.disableAccount(item.expired_date))
					$scope.home2AccountTotal++;
			});
		});
		/*
		if(self.home2Interval){
			cancel(self.home2Interval)
			delete self.home2Interval;
			self.home2AccountTotal = 0;
		}
		$scope.home2Interval = $interval(function(){
			$scope.home2AccountTotal++;
			if($scope.home2AccountTotal == self.i_permissions.length)
				$interval.cancel($scope.home2Interval);
		}, 200);*/
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
                    self.active.tab = "home2";
                    self.currShow = true;
                }
                self.create.createBtnDisabled = false;
            }, function(response) {
                self.create.createBtnDisabled = false;
            });
        }
    }

	self.importPermission = function() {
		self.create2.uploadBtnDisabled = true;
		self.create2.data = {};
		var fd = new FormData();
		fd.append('importFile', $("#importFile")[0].files[0]);
		$http({
			method: 'POST',
			url: [$utility.SERVICE_URL, '/sys/permission/import_permission'].join(''),
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
					self.create2.info = response.data;
					self.create2.layout = "checked";
				}
				self.create2.uploadBtnDisabled = false;
			}, function(response) {
				self.create2.uploadBtnDisabled = false;
		});
	}

	self.createImport = function() {
        if (self.create2.info && self.create2.info.filename) {
            self.create.createBtnDisabled = true;
            $http.post([$utility.SERVICE_URL, '/sys/permission/create_import'].join(''), {
                filename: self.create2.info.filename
            })
            .then(function(response) {
                if (response.data.error) {
                    self.errMessage = response.data.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
                } else {
                    self.getImportList();
                    self.active.tab = "home2";
                }
                self.create.createBtnDisabled = false;
            }, function(response) {
                self.create.createBtnDisabled = false;
            });
        }
    }

    self.saveUserChange = function(){
    	var log = [];
		angular.forEach(self.home2.selectedImportPermssion, function(val, key) {
			if(self.home2.selectedImportPermssion[key] && val.trim() != '') this.push(val);
		}, log);
		var set = self.home2.selectedSetting;
		var day = self.home2.setDate? self.home2.setDate : 0;
		console.log({ id: log, setTo: set, day: day });
    	if(log.length){
    		$http.post([$utility.SERVICE_URL, '/sys/permission/update_i_permissions'].join(''), { id: log, setTo: set, days: day })
			.then(function(response) {
				if(response.data.error){
					self.errMessage = response.data.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
				}else{
					self.getImportList();
					delete self.home2.setDate;
					self.home2.selectedImportPermssion=[];
					self.home2.selectedSetting=false;
                    self.active.tab = "home2";
				}
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
			case "home2":
				self.currShow = false;
				self.getImportList();
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
			case "create2":
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
		self.enableTempUseCode = $window.enable_tempuse_code;
		self.enableDefaultLogin = $window.enable_default_login;
		if(self.enableTempUseCode) self.getList();
		if(self.enableDefaultLogin) self.getImportList();
		self.currShow = false;
		self.create = {
			layout: "upload",
			uploadBtnDisabled: false,
			createBtnDisabled: false,
			info: {}
		};
		self.create2 = {
			example: [$utility.SERVICE_URL, '/sys/permission/example'].join(''),
			layout: "upload",
			uploadBtnDisabled: false,
			createBtnDisabled: false,
			info: {}
		};
		
		$scope.home2AccountTotal = 0;
		$scope.home2AccountMax = $window.default_login_max;
		$scope.c2example = [{id:1,u:'user1',p:'26iYh',f: '小名',l:'王',d:60},
			{id:2,u:'user2',p:'26iw',f: 'awesome',l:'Jone',d:80},
			{id:'#',u:'user5',p:'Jtw3',f: '小山',l:'张',d:50}
		];
	}

	self.init();
})
