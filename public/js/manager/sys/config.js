_1know.controller('ConfigCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
	var self = this;

	self.editPicture = function(type) {
		self.editPictureType = type;
		self.setImageEvent();

		$timeout(function() {
			if (type === 'logo') {
				$('#input_logo').click();
			}
			if (type === 'welcome_img'){
				$('#input_welcome_img').click();
			}
		},100);
	}

	self.setImageEvent = function() {
		var inputFile;
		if (self.editPictureType === 'logo') {
			inputFile = document.getElementById('input_logo');
		}
		if (self.editPictureType === 'welcome_img'){
			inputFile = document.getElementById('input_welcome_img');
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
						tmp.height = image.height > 960 ? 960 : image.height;
						tmp.width = image.height > 960 ? image.width * (960 / image.height) : image.width;

						// 等比例縮小，以寬為主
						canvas.width = tmp.width > 1920 ? 1920 : tmp.width;
						canvas.height = tmp.width > 1920 ? tmp.width * (1920 / tmp.height) : tmp.height;
						
						var ctx = canvas.getContext('2d');
						ctx.drawImage(image, 0, 0, canvas.width, canvas.height);

						$timeout(function() {
							var cv = canvas.toDataURL();
							if (self.editPictureType === 'logo'){
								self.currentConfig.logo = cv;	
							}
							if (self.editPictureType === 'welcome_img'){
								self.currentConfig.welcome_img = cv;
							}
						}, 100,true);
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
		if (type === 'welcome_img'){
			self.currentConfig.welcome_img = null;
		}
	}
	
	self.reStoreColor = function(){
		document.getElementById('welcome_color').jscolor.fromString('c8e7fc');
		self.currentConfig.welcome_color = 'C8E7FC';
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
			}
			else {
				self.loadConfig();
				self.errMessage = '系統配置_儲存成功';
			}
			$('#errorMessageModal').modal('show');
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
		$('#errorMessageModal').on('hidden.bs.modal', function() {
			delete self.errMessage;
		});
		$.getScript('/library/jscolor/jscolor.min.js');
	}

	self.init();
}).directive('setColor', function($timeout){
	return {
		restrict: 'A',
		link: function (scope, element, attr) {
			var waiting = function(){
				if (typeof element[0].jscolor == "undefined"){
					$timeout(function(){waiting();},1000);
				}else{
					var color = scope.configCtrl.currentConfig.welcome_color;
					element[0].jscolor.fromString(color? 'c8e7fc':color);
				}
			}
			waiting();
		}
	}
});