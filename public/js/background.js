_1know.controller('BackgroundCtrl', ['$scope', '$http', '$location', '$utility', function($scope, $http, $location, $utility) {
	var self = this;

	self.changeTarget = function(target) {
		self.target = target;

		if (target === 'user' && self.users === undefined)
			self.queryUserByIndex(0);
		else if (target === 'knowledge' && self.knowledges === undefined)
			self.queryKnowByIndex(0);
		else if (target === 'group' && self.groups === undefined)
			self.queryGroupByIndex(0);
		else if (target === 'channel' && self.channels === undefined)
			self.queryChannelByIndex(0);
	}

	self.queryUserByIndex = function(start_index) {
		self.userParams  = { start_index: start_index, keyword: '' };

		$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/user'].join(''), params: {'start-index': start_index * 20}})
		.success(function(response, status) {
			if (self.userParams.start_index === 0)
				self.users = response.users;
			else {
				self.users = self.users.concat(response.users);
			}

			self.userParams.size = response.size;

			if (response.users.length === 20)
				self.userParams.more = true;
		});
	}

	self.queryUserByKeyword = function(event) {
		if (event.keyCode !== 13) return;

		if (self.userParams.keyword !== undefined && self.userParams.keyword !== '') {
			self.userParams.more = false;

			$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/user'].join(''), params: {'keyword': self.userParams.keyword}})
			.success(function(response, status) {
				self.users = response.users;
				self.userParams.size = response.size;
			});
		}
		else
			self.queryUserByIndex(0);
	}

	self.queryKnowByIndex = function(start_index) {
		self.knowParams  = { start_index: start_index, keyword: '' };

		$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/knowledge'].join(''), params: {'start-index': start_index * 20}})
		.success(function(response, status) {
			if (self.knowParams.start_index === 0)
				self.knowledges = response.knowledges;
			else {
				self.knowledges = self.knowledges.concat(response.knowledges);
			}

			self.knowParams.size = response.size;

			if (response.knowledges.length === 20)
				self.knowParams.more = true;
		});
	}

	self.queryKnowByKeyword = function(event) {
		if (event.keyCode !== 13) return;

		if (self.knowParams.keyword !== undefined && self.knowParams.keyword !== '') {
			self.knowParams.more = false;

			$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/knowledge'].join(''), params: {'keyword': self.knowParams.keyword}})
			.success(function(response, status) {
				self.knowledges = response.knowledges;
				self.knowParams.size = response.size;
			});
		}
		else
			self.queryKnowByIndex(0);
	}

	self.queryGroupByIndex = function(start_index) {
		self.groupParams  = { start_index: start_index, keyword: '' };

		$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/group'].join(''), params: {'start-index': start_index * 20}})
		.success(function(response, status) {
			if (self.groupParams.start_index === 0)
				self.groups = response.groups;
			else {
				self.groups = self.groups.concat(response.groups);
			}

			self.groupParams.size = response.size;

			if (response.groups.length === 20)
				self.groupParams.more = true;
		});
	}

	self.queryGroupByKeyword = function(event) {
		if (event.keyCode !== 13) return;

		if (self.groupParams.keyword !== undefined && self.groupParams.keyword !== '') {
			self.groupParams.more = false;

			$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/group'].join(''), params: {'keyword': self.groupParams.keyword}})
			.success(function(response, status) {
				self.groups = response.groups;
				self.groupParams.size = response.size;
			});
		}
		else
			self.queryGroupByIndex(0);
	}

	self.queryChannelByIndex = function(start_index) {
		self.channelParams  = { start_index: start_index, keyword: '' };

		$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/channel'].join(''), params: {'start-index': start_index * 20}})
		.success(function(response, status) {
			if (self.channelParams.start_index === 0)
				self.channels = response.channels;
			else {
				self.channels = self.channels.concat(response.channels);
			}

			self.channelParams.size = response.size;

			if (response.channels.length === 20)
				self.channelParams.more = true;
		});
	}

	self.queryChannelByKeyword = function(event) {
		if (event.keyCode !== 13) return;

		if (self.channelParams.keyword !== undefined && self.channelParams.keyword !== '') {
			self.channelParams.more = false;

			$http({method: 'GET', url: [$utility.SERVICE_URL, '/background/channel'].join(''), params: {'keyword': self.channelParams.keyword}})
			.success(function(response, status) {
				self.channels = response.channels;
				self.channelParams.size = response.size;
			});
		}
		else
			self.queryChannelByIndex(0);
	}

	self.init = function() {
		self.userParams  = {};
		self.knowParams = {};
		self.groupParams  = {};
		self.channelParams  = {};

		self.target = 'user';
		self.changeTarget('user');
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
}])