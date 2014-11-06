define([
    'lodash',
    'angular',
    'text!./name.css',
    'text!./name.html',
    'volare/util'
], function(_, angular, css, template) {
    'use strict';

    var name = angular.module('volare.components.name', [
        'volare.util'
    ]);

    name.directive('volareName', ['util', function(util) {
        util.loadCssInline(css);

        return {
            restrict: 'E',
            replace: true,
            transclude: true,
            template: template,
            scope: {
                name: '@',
                update: '&',
                delete: '&'
            },
            controller: ['$scope', function($scope) {
                $scope.editing = false;
                $scope.edit = function() {
                    $scope.editing = true;
                };
                $scope.save = function() {
                    $scope.editing = false;
                    $scope.update({
                        $name: $scope.name
                    });
                };
                $scope.keydown = function(event) {
                    if (event.keyCode === 0x0d)
                        this.save();
                };
            }],
            link: function(scope, element, attrs) {
                var inputName = element.find('input');

                scope.$watch('editing', function(editing) {
                    if (editing)
                        _.defer(_.bind(inputName.focus, inputName));
                });
            }
        };
    }]);

    return name;
});