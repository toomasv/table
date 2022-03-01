Red [Author: @toomasv Date: 7-Feb-2022]

style: function [name template /default 'actor /init body][
	system/view/VID/styles/:name: style: compose/only [template: (template)]
	if default [append style compose [default-actor: (to-get-word actor)]]
	if init [append style compose/only [init: (body)]]
]

