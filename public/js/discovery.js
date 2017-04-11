_1know.controller('DiscoveryCtrl', function($scope, $http, $location, $routeParams, $utility, $window, $interval ) {
	var self = this;
	
	self.loadChannelList = function() {
		$http.get([$utility.SERVICE_URL, '/discovery/channels'].join(''))
		.success(function(response, status) {
			self.channels = response;
		});
	}

	self.loadChannel = function(uqid) {
		$http.get([$utility.SERVICE_URL, '/discovery/channels/', uqid].join(''))
		.success(function(response, status) {
			if (!response.error) {
				if (uqid === 'chle0ef90209f34')
					response.name = translations[$utility.LANGUAGE.type]['C007'];//編輯精選
				self.currentChannel = response;
				self.currentChannel.view = true;
				self.currentChannel.categoryPath = [];
				self.loadCategory(null, true);
			}
			else
				$location.path('/discover');
		});
	}

	self.loadCategory = function(category, lastItem) {
		delete self.keyWord;
		delete self.knowledges;
		
		if (category === null) {
			self.currentChannel.view = true;
			self.currentChannel.categoryPath = [];
			self.currentChannel.currentCategory = self.currentChannel;
			return;
		}

		self.currentChannel.currentCategory = category;

		if (lastItem) {
			category.view = true;
			self.currentChannel.view = false;
			self.currentChannel.categoryPath = [];
			self.currentChannel.categoryPath.push(category);
		}
		else {
			var path = [];
			for (var i=0;i<self.currentChannel.categoryPath.length;i++) {
				if (category.uqid !== self.currentChannel.categoryPath[i].uqid) {
					self.currentChannel.categoryPath[i].view = false;
					path.push(self.currentChannel.categoryPath[i]);
				}
				else
					i = self.currentChannel.categoryPath.length;
			}
			category.view = true;
			path.push(category);
			self.currentChannel.view = false;
			self.currentChannel.categoryPath = path;
		}

		if (self.currentChannel.currentCategory.isLoad === undefined) {
			$http.get([$utility.SERVICE_URL, '/discovery/channels/', self.currentChannel.uqid, '/categories/', self.currentChannel.currentCategory.uqid].join(''))
			.success(function(response, status) {
				self.currentChannel.currentCategory.categories = response.categories;
				self.currentChannel.currentCategory.knowledges = response.knowledges;
				self.currentChannel.currentCategory.isLoad = true;

				angular.forEach(response.knowledges, function(item) {
					item.format_time = new Date(949334400000 + item.total_time * 1000);
				});
			});
		}
	}

	self.loadKnowledge = function(start_index) {
		self.start_index = start_index;

		$http.get([$utility.SERVICE_URL, '/discovery/knowledges?start-index=', start_index * 15, '&max-results=15&order-by=', self.orderType].join(''))
		.success(function(response, status) {
			if (self.start_index === 0)
				self.knowledges = response;
			else
				self.knowledges = self.knowledges.concat(response);

			if (response.length < 15)
				self.start_index = -1;

			angular.forEach(self.knowledges, function(item) {
				item.format_time = new Date(949334400000 + item.total_time * 1000);
			});
		});
	}

	self.searchKnowledge = function(event) {
		if (event.keyCode !== 13) return;
		
		if (self.keyWord !== undefined && self.keyWord !== '') {
			if (self.target === 'knowledge') {
				$http.get([$utility.SERVICE_URL, '/discovery/knowledges?start-index=0&order-by=date&keyword=', self.keyWord].join(''))
				.success(function(response, status) {
					self.knowledges = response;

					angular.forEach(self.knowledges, function(item) {
						item.format_time = new Date(949334400000 + item.total_time * 1000);
					});
				});
			}
			else {
				$http.get([$utility.SERVICE_URL, '/discovery/channels/', self.currentChannel.uqid, '/knowledges?keyword=', self.keyWord].join(''))
				.success(function(response, status) {
					self.knowledges = response;

					angular.forEach(self.knowledges, function(item) {
						item.format_time = new Date(949334400000 + item.total_time * 1000);
					});
				});
			}
		}
		else {
			delete self.keyWord;
			delete self.knowledges;

			if (self.target === 'knowledge')
				self.loadKnowledge(0);
			else
				self.loadChannel(self.currentChannel.uqid);
		}
	}

	self.unsubscribe = function() {
		$http.delete([$utility.SERVICE_URL, '/discovery/channels/', self.currentChannel.uqid, '/unsubscribe'].join(''))
		.success(function(response, status) {
			delete self.channels;
			self.loadChannelList();
			$location.path('/discover/knowledge');
		});
	}

	self.openKnowledge = function(target) {
		if (!target.subscribed)
			window.open(target.page, '_blank');
		else
			$location.path(['/learn/knowledge/', target.uqid].join(''));
	}

	self.toggleOrder = function(type) {
		self.orderType = type;
		self.loadKnowledge(0);
		delete self.keyWord;
	}

	//frontpage
	self.loadFrontObjects = function(){
		var cfg = self.frontCfg;
		if(!(cfg.sliderActivate || cfg.twobannerActivate || cfg.tagfunctionActivate)) return;
		$http.get([$utility.SERVICE_URL, '/discovery/frontobjects'].join(''))
		.success(function(response, status){
			if(!response.error){
				self.frontdata = response;
				self.frontdata.knowledges = {};
			}
		});
	}
	$scope.$on('ngSliderRepeatFinished1', function(ngSliderRepeatFinishedEvent) {
		var myIndex = 0;
		carousel();
		function carousel() {
			var i;
			var x = document.getElementsByClassName("mSlider");
			for (i = 0; i < x.length; i++) {
			   x[i].style.display = "none";  
			}
			myIndex++;
			if (myIndex > x.length) {myIndex = 1}    
			x[myIndex-1].style.display = "block";  
			setTimeout(carousel, 4000); // Change image every 2 seconds
		}
	});
	$scope.$on('ngSliderRepeatFinished2', function(ngSliderRepeatFinishedEvent) {
		$('#multiBanner').slick({
			slidesToShow: 6,
			slidesToScroll: 1,
			autoplay: true,
			autoplaySpeed: 3500,
		});
	});
	
	self.banner_set_bg = function(o){
		return {'background': "url('/images/frontobject/"+o.sImg+"')", 'background-size': '100% 100%', 'background-repeat': 'no-repeat'};
	}
	self.get_frontObject_knowledges = function(tid, o, offset){
		var payload = {};
		if (o == null) return;
		payload.set = o;
		payload.start_index = offset? offset:0;
		$http.post([$utility.SERVICE_URL, '/discovery/frontknowledges'].join(''), payload)
		.success(function(response, status){
			if(!response.error){
				self.frontdata.knowledges[tid] = [];
				angular.forEach(response, function(item) {
					item.format_time = new Date(949334400000 + item.total_time * 1000);
					self.frontdata.knowledges[tid].push(item); 
				});
			}
		});
	}
	self.getObjDetail = function(o){
		self.get_frontObject_knowledges(o.id, o.knowledges);
		self.frontCfg.target = 'objDetail';
		$scope.select_obj = o;
	}
	//==========================//
	self.init = function() {
		if ($routeParams.t !== undefined) {
			self.target = $routeParams.t;
			self.orderType = 'date';
			self.language = $utility.LANGUAGE;
			self.frontCfg = $window.frontCfg;
			if (self.frontCfg.target == "") self.frontCfg.target = 'default';
			if (self.frontCfg.target == "dxVersion") self.frontCfg.show='normal';

			if ($routeParams.t === 'knowledge')
				self.loadKnowledge(0);
			else if ($routeParams.t === 'channel')
				self.loadChannel($routeParams.c);

			self.loadChannelList();
		}
		else {
			if ($utility.account.channels !== undefined && $utility.account.channels.length > 0)
				$location.path(['/discover/channel/', $utility.account.channels[0].uqid].join(''));
			else
				$location.path('/discover/knowledge/');
		}
		//frontpage option
		self.loadFrontObjects();
	}
	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
}).directive('onFinishRender1', function ($timeout) {
	return {
		restrict: 'A',
		link: function (scope, element, attr) {
			if (scope.$last === true) {
				$timeout(function () {
					scope.$emit(attr.onFinishRender1);
				});
			}
		}
	}
}).directive('onFinishRender2', function ($timeout) {
	return {
		restrict: 'A',
		link: function (scope, element, attr) {
			if (scope.$last === true) {
				$timeout(function () {
					scope.$emit(attr.onFinishRender2);
				});
			}
		}
	}
});