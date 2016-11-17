_1know.controller('DiscoveryCtrl', function($scope, $http, $location, $routeParams, $utility) {
	var self = this;
	self.language = $utility.LANGUAGE;

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

	self.init = function() {
		if ($routeParams.t !== undefined) {
			self.target = $routeParams.t;
			self.orderType = 'date';

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
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})