_1know.controller('CreationCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
	var self = this;

	self.loadKnowledge = function() {
		$http.get([$utility.SERVICE_URL, '/creation/knowledges'].join(''))
		.success(function(response, status) {
			self.knowledges = response;
		});
	}

	self.modifyKnowledge = function(target) {
		$location.path('/create/knowledge/' + target.uqid);
	}

	self.loadChannel = function() {
		$http.get([$utility.SERVICE_URL, '/creation/channels'].join(''))
		.success(function(response, status) {
			self.channels = response;
		});
	}

	self.modifyChannel = function(target) {
		$location.path('/create/channel/' + target.uqid);
	}

	self.showCreateModal = function() {
		$('#createModal').modal('show');
		$('#createModal').on('hidden.bs.modal', function() {
			delete self.errMsg;
			if (self.modifyType !== undefined) {
				$scope.$apply(function() {
					if (self.modifyType === 'knowledge')
						self.modifyKnowledge(self.targetName);
					else if (self.modifyType === 'channel')
						self.modifyChannel(self.targetName);
				});
				
				delete self.modifyType;
				delete self.targetName;
			}
		});
	}

	self.createTarget = function(type) {
		if (self.onCreate === undefined && self.targetName !== undefined && self.targetName !== '') {
			self.onCreate = true;

			if (type === 'knowledge') {
				$http.post([$utility.SERVICE_URL, '/creation/knowledges'].join(''), { name: self.targetName, setInto: self.setIntoObj })
				.success(function(response, status) {
					if (!response.error) {
						self.targetName = response;
						 self.modifyType = 'knowledge';
						$('#createModal').modal('hide');
					}
					else
						self.errMsg = response.error;

					delete self.onCreate;
				});
			}
			else if (type === 'channel') {
				$http.post([$utility.SERVICE_URL, '/creation/channels'].join(''), { name: self.targetName })
				.success(function(response, status) {
					if (!response.error) {
						self.targetName = response;
						 self.modifyType = 'channel';
						$('#createModal').modal('hide');
					}
					else
						self.errMsg = response.error;

					delete self.onCreate;
				});
			}
		}
	}

	self.setIntoObj = function(e){
		self.setIntoObj = e.originalObject.id;
	}

	self.init = function() {
		if ($routeParams.t !== undefined) {
			self.target = $routeParams.t;

			if ($routeParams.t === 'knowledge')
				self.loadKnowledge();
			else if ($routeParams.t === 'channel')
				self.loadChannel();
		}
		else
			$location.path('/create/knowledge');
		$http.get([$utility.SERVICE_URL, '/creation/knowledges/get/tag'].join(''))
		.success(function(response, status){
			if(!response.error){
				self.frontObjects = response;
			}
		});
	}

	$scope.$watch('mainCtrl.account', function(newVal, oldVal) {
		if (newVal !== undefined && newVal !== 'NotLogin') self.init();
	});
})