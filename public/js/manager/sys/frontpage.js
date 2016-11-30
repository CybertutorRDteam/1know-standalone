_1know.controller('FrontpageCtrl_mainCfg', function($scope, $http, $utility) {
	var self = this;

	self.saveConfig = function() {
		$http({
			method: 'POST',
			url: [$utility.SERVICE_URL, '/sys/frontpage'].join(''),
			data: { "content": 
						$.extend(self.currentConfig,
							{'front_slider_obj': self.slider.join(',')},
							{'front_twobanner_obj': self.banner.join(',')})
				},
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
				self.errMessage = '首頁配置_儲存成功';
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	};

	self.loadConfig = function() {
		self.currentConfig = {};
		$http.get([$utility.SERVICE_URL, '/sys/frontpage'].join(''), {})
		.success(function(response, status) {
			if (!response.error) {
				response.forEach(function(item){
					switch (item.name) {
						case 'front_hide_default_discovery':
						case 'front_hide_search_banner':
						case 'front_twobanner_activate':
						case 'front_slider_activate':
						case 'front_tagfunction_activate':
							self.currentConfig[item.name] = (item.content == 'true');
							break;
						case 'front_slider_obj':
							self.slider = item.content.split(',');
							break;
						case 'front_twobanner_obj':
							self.banner = item.content.split(',')
							break;
						default:
							self.currentConfig[item.name] = item.content;
					}
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
		self.slider = [];
		self.banner = [];
		$.getScript('/library/bootstrap/js/bootstrap-tagsinput.js');
		$.getScript('/library/bootstrap/js/bootstrap-tagsinput-angular.js');
		$('<link rel="stylesheet" type="text/css" href="/library/bootstrap/css/bootstrap-tagsinput.css">').appendTo($('body'));
		self.loadConfig();
	}

	self.init();
})
/*--------------------------------------------------------------------------------------------------*/
_1know.controller('FrontpageCtrl_objCfg', function($scope, $http, $window, $utility) {
	var self = this;

	self.saveObject = function() {
		$http({
			method: 'POST',
			url: [$utility.SERVICE_URL, '/sys/frontpage/objects'].join(''),
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
				self.init();
				self.errMessage = '首頁配置_儲存成功';
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	};

	self.addKnowledage = function(){
		if(self.insert.length == 0) return false;
		var input = self.insert.split('/');
		var id = input[input.length-1];
		$http.get([$utility.SERVICE_URL, '/sys/frontpage/getKnowledage/', id].join(''))
		.success(function(response, status) {
			if (response.error) {
				self.errMessage = response.error;
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
			else {
				var isCollision = false;
				$.each(self.currentConfig.knowledges, function(i,o){
					if(o.id == response.id){ isCollision = true; return false; }
				});
				if(isCollision){
					self.errMessage = '物件配置_課程已存在';
				}else{
					self.currentConfig.knowledges.push(response);
					self.errMessage = '物件配置_新增成功';
				}
				self.insert = '';
				$('#errorMessageModal').modal('show');
				$('#errorMessageModal').on('hidden.bs.modal', function() {
					delete self.errMessage;
				});
			}
		});
	}
	self.removeKnoeledage = function(id){
		var ary = [];   
		$.each(self.currentConfig.knowledges, function(i,o){
			if(o.id != id) ary.push(o);
		});
		self.currentConfig.knowledges = ary;
	}
	self.loadObjects = function() {
		$http.get([$utility.SERVICE_URL, '/sys/frontpage/objects'].join(''))
		.success(function(response){
			if(!response.error){
				response.forEach(function(item){
					if(item.bImg != '')
						item.bigImg = '/images/frontobject/' + item.bImg;
					if(item.sImg != '')
						item.smallImg = '/images/frontobject/' + item.sImg;
					item.knowledges = JSON.parse(item.knowledges);
					item.useForTag = (item.bTag == 'true' || (typeof item.bTag === 'boolean' && item.bTag));
					self.objects.push(item);
				});
			}
		});
	};

	self.focusItem = function(o){
		self.currentConfig = angular.copy(o);
		if(self.currentConfig.knowledges == null)
			self.currentConfig.knowledges = [];
		$window.scrollTo(0, 0);
		$('#objectUploadForm').stop().effect( "shake"  , 1000);
	}

	self.reNew = function(){
		delete self.currentConfig.id
		delete self.currentConfig.name
		delete self.currentConfig.description
		delete self.currentConfig.sImg
		delete self.currentConfig.bImg
		self.currentConfig.knowledges = [];
		self.currentConfig.bigImg = '/img/addIcon.png';
		self.currentConfig.smallImg = '/img/addIcon.png';
	}

	$window.cvImg = function(e){
		var target = $(e).data('for');
		var f = e.files[0];
		var FR = new FileReader();
		FR.onload = function(event){
			$(target).val(event.target.result);
			var $t = angular.element(target);
  			$t.triggerHandler('input');
		};
		FR.readAsDataURL(f);
	}

	self.init = function() {
		self.objects = [];
		self.insert = '';
		self.currentConfig = {
			knowledges: [],
			bigImg: '/img/addIcon.png',
			smallImg: '/img/addIcon.png'
		};
		$('input[type=file]').val('');
		self.loadObjects();
	}

	self.init();
})