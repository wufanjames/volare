define([
    'lodash',
    'underscore.string',
    'angular',
    'text!./uas.html'
], function(_, _s, angular, uasTemplate) {
    'use strict';

    var module = angular.module('volare.components.uas', []);

    module.directive('volareUas', [function() {
        return {
            restrict: 'E',
            replace: true,
            template: uasTemplate,
            scope: {
                station: '=',
                date: '='
            },
            controller: 'UASChartController',
            link: function(scope, element, attrs) {
                var width = element.width();
                var height = element.height();

                var margin = {
                    top: 10,
                    left: 50,
                    bottom: 15,
                    right: 10
                };

                var canvas = element.children('canvas')[0];
                canvas.width = width;
                canvas.height = height;

                var context = canvas.getContext('2d');

                var minTemperature = -90;
                var maxTemperature = 50;
                var minPressure = 100;
                var maxPressure = 1050;
                var pressures = [maxPressure, 1000, 925, 850, 700, 500, 400, 300, 250, 200, 150, 100];

                function getX(temperature) {
                    return (temperature - minTemperature)/(maxTemperature - minTemperature)*(width - (margin.left + margin.right)) + margin.left;
                }

                function getY(pressure) {
                    return (Math.log(pressure) - Math.log(minPressure))/(Math.log(maxPressure) - Math.log(minPressure))*(height - (margin.top + margin.bottom)) + margin.top;
                }

                function drawGrid(context) {
                    context.lineWidth = 0.1;
                    context.strokeStyle = 'black';
                    context.fillStyle = 'black';

                    var minX = getX(minTemperature);
                    var maxX = getX(maxTemperature);
                    var minY = getY(maxPressure);
                    var maxY = getY(minPressure);

                    context.textAlign = 'end';
                    context.textBaseline = 'middle';
                    _.each(pressures, function(p) {
                        context.strokeStyle = p === minPressure || p === maxPressure ? 'black' : 'gray';

                        var y = getY(p);
                        context.beginPath();
                        context.moveTo(minX, y);
                        context.lineTo(maxX, y);
                        context.stroke();

                        if (p !== maxPressure)
                            context.fillText(p, minX - 5, y);
                    });

                    var stepTemperature = 5;
                    context.textAlign = 'center';
                    context.textBaseline = 'top';
                    _.each(_.range(minTemperature, maxTemperature + 1, stepTemperature), function(t) {
                        var primary = t % (stepTemperature * 2) === 0;
                        context.strokeStyle = primary ? 'black' : 'gray';

                        var x = getX(t);
                        context.beginPath();
                        context.moveTo(x, minY);
                        context.lineTo(x, maxY);
                        context.stroke();

                        if (primary)
                            context.fillText(t, x, minY + 5);
                    });
                }

                var mixingRatio = {
                    t0: 273.16,
                    rv: 461.7,
                    lv: 2500000,
                    e0: 611.73,
                    ep: 0.622,
                    k: 273.15,
                    temperature: function(ratio, pressure) {
                        return 1 / (1 / this.t0 - this.rv / this.lv * Math.log(ratio / 1000 * pressure * 100 / (this.e0 * (this.ep + ratio / 1000)))) - this.k;
                    }
                };

                function drawMixingRatio(context) {
                    context.lineWidth = 0.5;
                    context.strokeStyle = 'purple';
                    context.fillStyle = 'purple';
                    context.textAlign = 'center';
                    context.textBaseline = 'bottom';

                    var ratios = [0.1, 0.4, 1, 2, 4, 7, 10, 16, 24, 32];
                    _.each(ratios, function(ratio) {
                        context.beginPath();
                        var x = getX(mixingRatio.temperature(ratio, pressures[0]));
                        var y = getY(pressures[0]);
                        context.lineTo(x, y);
                        _.each(_.tail(pressures), function(p) {
                            context.lineTo(getX(mixingRatio.temperature(ratio, p)), getY(p));
                        });
                        context.stroke();

                        context.fillText(ratio, x, y - 2);
                    });
                }

                function drawObservation(context, observation) {
                    if (!observation)
                        return;

                    var items = observation;

                    context.lineWidth = 2;

                    context.strokeStyle = 'red';
                    context.beginPath();
                    context.moveTo(getX(_.head(items).temperature), getY(_.head(items).pressure));
                    _.each(_.tail(items), function(item) {
                        if (item.temperature)
                            context.lineTo(getX(item.temperature), getY(item.pressure));
                    });
                    context.stroke();

                    context.strokeStyle = 'blue';
                    context.beginPath();
                    context.moveTo(getX(_.head(items).dewPoint), getY(_.head(items).pressure));
                    _.each(_.tail(items), function(item) {
                        if (item.dewPoint)
                            context.lineTo(getX(item.dewPoint), getY(item.pressure));
                    });
                    context.stroke();
                }

                function clear(context) {
                    context.clearRect(0, 0, width, height);
                }

                scope.$watch('observation', function(observation) {
                    clear(context);
                    drawGrid(context);
                    drawMixingRatio(context);
                    drawObservation(context, observation);
                });
            }
        };
    }]);

    module.controller('UASChartController', ['$scope', '$http', function($scope, $http) {
        var station = $scope.station;
        var date = $scope.date;

        var path = _s.sprintf('/uas/observation/%s/%04d/%02d/%02d/00', station.id,
            date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
        $http.get(path).success(function(observation) {
            $scope.observation = observation;
        });
    }]);

    return module;
});