_1know.controller('AccountsCtrl', function($scope, $http, $location, $timeout, $routeParams, $utility) {
    var self = this;

    self.showCreateAccountModal = function() {
        self.currentAccount = {};
        $('#createAccountModal').modal('show');
        $('#createAccountModal').on('hidden.bs.modal', function() {
            self.currentAccount = null;
            delete self.errMessage;
        });
    };

    self.showEditAccountModal = function(item) {
        self.currentAccount = item;
        $('#showChangeDiag').modal('show');
        $('#showChangeDiag').on('hidden.bs.modal', function() {
            delete self.currentAccount;
            delete self.errMessage;
        });
    };

    self.showDeleteAccountModal = function(item) {
        self.currentAccount = item;
        $('#deleteAccountModal').modal('show');
        $('#deleteAccountModal').on('hidden.bs.modal', function() {
            delete self.currentAccount;
            delete self.errMessage;
        });
    };

    self.createAccount = function() {
        if (!self.currentAccount.acc) {
            self.errMessage = "管理者_帳號不可為空值";
            $('#errorMessageModal').modal('show');
            $('#errorMessageModal').on('hidden.bs.modal', function() {
                delete self.errMessage;
            });
        } else if (!self.currentAccount.pass) {
            self.errMessage = "管理者_密碼不可為空值";
            $('#errorMessageModal').modal('show');
            $('#errorMessageModal').on('hidden.bs.modal', function() {
                delete self.errMessage;
            });
        } else if (self.currentAccount.pass !== self.currentAccount.pass_confirmation) {
            self.errMessage = "管理者_密碼不一致";
            $('#errorMessageModal').modal('show');
            $('#errorMessageModal').on('hidden.bs.modal', function() {
                delete self.errMessage;
            });
        } else {
            var data = {
                acc: self.currentAccount.acc,
                pass: self.currentAccount.pass,
                pass_confirmation: self.currentAccount.pass_confirmation,
                acc_name: self.currentAccount.acc_name
            };

            $http.post([$utility.SERVICE_URL, '/super/account'].join(''), data)
            .success(function(response, status) {
                if (response.error) {
                    self.errMessage = response.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
                }
                else {
                    self.loadAccounts();
                    $('#createAccountModal').modal('hide');
                }
            });
        }
    };

    self.editAccount = function() {
        if (!self.currentAccount.newpwd) {
            self.errMessage = "管理者_密碼不可為空值";
            $('#errorMessageModal').modal('show');
            $('#errorMessageModal').on('hidden.bs.modal', function() {
                delete self.errMessage;
            });
        } else if (self.currentAccount.newpwd !== self.currentAccount.newpass_confirmation) {
            self.errMessage = "管理者_密碼不一致";
            $('#errorMessageModal').modal('show');
            $('#errorMessageModal').on('hidden.bs.modal', function() {
                delete self.errMessage;
            });
        } else {
            var data = {
                newpwd: self.currentAccount.newpwd,
                newpass_confirmation: self.currentAccount.newpass_confirmation,
                acc_name: self.currentAccount.acc_name
            };

            $http.put([$utility.SERVICE_URL, '/super/account/', self.currentAccount.id].join(''), data)
            .success(function(response, status) {
                if (response.error) {
                    self.errMessage = response.error;
                    $('#errorMessageModal').modal('show');
                    $('#errorMessageModal').on('hidden.bs.modal', function() {
                        delete self.errMessage;
                    });
                }
                else {
                    self.loadAccounts();
                    $('#showChangeDiag').modal('hide');
                }
            });
        }
    };

    self.deleteAccount = function() {
        $http.delete([$utility.SERVICE_URL, '/super/account/', self.currentAccount.id].join(''))
        .success(function(response, status) {
            if (response.error) {
                self.errMessage = response.error;
                $('#errorMessageModal').modal('show');
                $('#errorMessageModal').on('hidden.bs.modal', function() {
                    delete self.errMessage;
                });
            }
            else {
                self.loadAccounts();
                $('#deleteAccountModal').modal('hide');
            }
        });
    };

    self.loadAccounts = function() {
        $http.get([$utility.SERVICE_URL, '/super/accounts'].join(''), {})
        .success(function(response, status) {
            if (!response.error) {
                self.accounts = response;
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
        self.loadAccounts();
    };

    self.init();
})
