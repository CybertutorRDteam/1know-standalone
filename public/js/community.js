_1know.controller('CommunityCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
	var self = this;

	self.changeLayout = function(target) {
		self.target = target;

		if (target === 'group')
			self.loadGroup();
		else if (target === 'public')
			self.loadAllGroup(0);
	}

	self.loadAllGroup = function(start_index) {
		self.start_index = start_index;

		$http({method: 'GET', url: [$utility.SERVICE_URL, '/join/all?start-index=', start_index * 15, '&max-results=15'].join('')})
		.success(function(response, status) {
			if (self.start_index === 0)
				self.groups = response;
			else
				self.groups = self.groups.concat(response);

			if (response.length < 15)
				self.start_index = -1;
		});
	}

	self.search = function(event) {
		if (event.keyCode !== 13) return;

		if (self.keyWord !== undefined && self.keyWord !== '') {
			$http({method: 'GET', url: [$utility.SERVICE_URL, '/join/all?start-index=0&keyword=', self.keyWord].join('')})
			.success(function(response, status) {
				self.groups = response;
			});
		}
		else {
			delete self.keyWord;
			delete self.groups;

			self.loadAllGroup(0);
		}
	}

	self.loadGroup = function() {
		$http({method: 'GET', url: [$utility.SERVICE_URL, '/join'].join('')})
		.success(function(response, status) {
			angular.forEach(response, function(item) {
				if (item.message > 99)
					item.message = '99+';
				else if (item.message === 0)
					item.message = '';
			});

			self.groups = response;
		});
	}

	self.openGroup = function(target) {
		$location.path('/join/group/' + target.uqid);
	}

	self.openDiscoverGroup = function(target) {
		window.open(target.page, '_blank');
	}

	self.showJoinModal = function() {
		self.targetModal = 'join';
		self.errMsg = undefined;
		$('#targetModal').modal('show');
	}

	self.join = function() {
		self.guest = {
			first_name: $utility.account.first_name,
			last_name: $utility.account.last_name
		};

		if ($utility.account.nouser && [$utility.account.first_name, $utility.account.last_name].join('') === '') {
			$('#profileModal').modal('show');
		}
		else {
			if (self.onJoin === undefined && self.groupCode !== undefined && self.groupCode !== '') {
				self.onJoin = true;
				
				$http.post([$utility.SERVICE_URL, '/join/', self.groupCode, '/joinGroup'].join(''))
				.success(function(response, status) {
					if (!response.error) {
						$('#targetModal').modal('hide');
						self.loadGroup();
					}
					else
						self.errMsg = response.error;

					delete self.onJoin;
				});
			}
		}
	}

	self.saveNouser = function() {
		var data = {
			first_name: self.guest.first_name,
			last_name: self.guest.last_name
		}

		$http.put([$utility.SERVICE_URL, '/personal/profile'].join(''), data)
		.success(function(response, status) {
			if (!response.error) {
				$utility.account.first_name = response.first_name;
				$utility.account.last_name = response.last_name;
				$utility.account.full_name = response.full_name;
				$('#profileModal').modal('hide');
				self.join();
			}
		});
	}

	self.showCreateModal = function() {
		self.targetModal = 'create';
		self.errMsg = undefined;
		$('#targetModal').modal('show');
	}

	self.create = function() {
		if (self.onCreate === undefined && self.groupName !== undefined && self.groupName !== '') {
			self.onCreate = true;

			$http.post([$utility.SERVICE_URL, '/join'].join(''), { name: self.groupName })
			.success(function(response, status) {
				if (!response.error) {
					$('#targetModal').modal('hide');
					self.loadGroup();
				}
				else
					self.errMsg = response.error;

				delete self.onCreate;
			});
		}
	}

	self.init = function() {
		if ($routeParams.t !== undefined) {
			self.target = $routeParams.t;
			self.changeLayout($routeParams.t);
		}
		else
			$location.path('/join/group');
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})
