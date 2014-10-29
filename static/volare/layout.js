define(['jquery',
        'angular'],
       function($, angular) {
    var layout = angular.module('volare.layout', []);

    layout.directive('volareFill', [function() {
        return {
            link: function(scope, element, attrs) {
                function layout() {
                    element.width($(document).width());
                    var mapPosition = element.position();
                    element.height($(document).height() - mapPosition.top);
                }
                $(window).on('resize', layout);
                layout();
            }
        };
    }]);

    return layout;
});