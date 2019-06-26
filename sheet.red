Red [
	Description: {Nano spreadsheet}
	Date: 12-Jun-2019
	Author: "Toomas Vooglaid"
	Licence: "MIT"
]
context [
	cells: copy []
	width: height: none
	selection: copy []
	
	extend system/view/VID/styles [
		colh: [
			template: [
				type: 'base
				size: 80x20
				color: silver
				extra: copy [col: #[none]]
				flags: [all-over]
				actors: [
					ofs: pos: col: parent: none
					drag?: no 
					on-down: func [face event /local pane][
						pane: face/parent/pane
						col: face/extra/col + 1
						either within? event/offset as-pair face/size/x - 5 0 5x25 [
							;width: face/parent/extra/x + 1
							ofs: event/offset/x
							par: face/parent
							pos: at pane col
							drag?: yes
							system/view/auto-sync?: off
						][
							;extract/into at pane width + col width clear selection
							;remove back tail selection
							;forall selection [selection/1: selection/1/data]
							;probe selection
						]
					]
					on-over: func [face event /local current][
						if drag? [
							dfx: event/offset/x - ofs
							par/size/x: par/size/x + dfx
							current: pos
							until [
								current/1/size/x: current/1/size/x + dfx
								loop width - col [current: next current current/1/offset/x: current/1/offset/x + dfx]
								current: skip current col
								tail? current
							]
							ofs: event/offset/x
							show face/parent
						]
					]
					on-up: func [face event][drag?: no system/view/auto-sync?: yes]
				]
			]
		]
		cell: [
			template: [
				type: 'field
				flags: 'no-border
				size: 80x20
				text: make string! 0
				extra: make reactor! [formula: make string! 0 code: none name: none face: none]
				actors: [
					keypos: 1
					shift?: ctrl?: no
					stop: charset " .:;"
					on-over: func [face event][either event/away? [][]]
					on-down: func [face event][
						set-focus face
						keypos: offset-to-caret face event/offset
						if face/extra/formula/1 = #"=" [face/text: face/extra/formula]
					]
					on-enter: func [face event /local s pos found loaded][
						case [
							face/text/1 = #"=" [
								face/extra/formula: copy face/text
								face/extra/code: parse load/all next face/text rule: [ 
									collect any [s: set wrd word! keep (
										either found: find/tail cells wrd [to-path reduce [found/1 'data]][wrd]
									) 
									| 	ahead block! into rule
									|	keep skip]
								]
								either found [
									react compose [(to-set-path reduce [face/extra/face 'data]) (face/extra/code)]
								][	face/data: do face/extra/code]
							]
							face/text/1 = #"!" [
								face/extra/formula: copy face/text
								face/extra/code: parse load/all next face/text rule: [ 
									collect any [s: set wrd word! keep (
										either found: find/tail cells wrd [to-path reduce [found/1 'data]][wrd]
									) 
									| 	ahead block! into rule
									|	keep skip]
								]
								do face/extra/code
							]
						]
						;set face/extra/name face/data
						pos: find face/parent/pane face
						if (length? pos) > width [set-focus first skip pos width]
					]
					on-key-down: func [face event /local pos idx step][
						pos: find face/parent/pane face
						idx: index? pos
						ctrl?: find event/flags 'control
						shift?: find event/flags 'shift
						switch/default event/key [
							left [
								either ctrl? [
									either keypos = 1 [
										if all [(step: idx - 1 % width + 1) > 2  width + 2 < index? pos] [
											set-focus first skip pos 2 - step
										]
									][
										keypos: either found: find/reverse/tail at face/text keypos - 1 stop [
											index? found
										][	1]
									]
								][
									case [
										all [
											keypos = 1 
											idx - 1 % width + 1 > 2  width + 2 < index? pos
										][set-focus first back pos]
										all [not ctrl? keypos > 1] [keypos: keypos - 1]
									]
								]
							]
							right [
								either ctrl? [
									either keypos > length? face/text [
										if (step: idx - 1 % width + 1) < width [
											set-focus first skip pos width - step
										]
									][
										keypos: either found: find at face/text keypos + 1 stop [
											1 + index? found
										][	1 + length? face/text]
									]
								][
									case [
										all [
											keypos > length? face/text 
											idx - 1 % width + 1 < width
										][set-focus first next pos]
										all [not ctrl? keypos <= length? face/text][keypos: keypos + 1]
									]
								]
							]
							up [
								if (step: idx - 1 / width) > 1 [
									either ctrl? [
										set-focus first skip pos 1 - step * width
									][
										set-focus first skip pos 0 - width
									]
								]
							]
							down [
								if 2 * width < length? pos [
									either ctrl? [
										step: height - (idx / (width + 1))
										set-focus first skip pos step * width
									][
										set-focus first skip pos width
									]
								]
							]
							home [either ctrl? [set-focus r1c1][keypos: 1]]
							end [either ctrl? [set-focus first skip tail pos -1 - width][keypos: 1 + length? face/text]]
							#"^-" [
								either shift? [
									if all [idx - 1 % width + 1 > 2  width + 2 < index? pos][set-focus first back pos]
								][
									if idx - 1 % width + 1 < width [set-focus first next pos]
								]
							]
							left-shift left-control right-shift right-control []
						][keypos: keypos + 1]
					]
					on-focus: func [face event][keypos: 1]
					;on-unfocus: func [face event][
					;	set face/extra/name face/data
					;]
					on-change: func [face event][
						set face/extra/name face/data
					]
				]
			]
		]
		sheet: [
			template: [
				type: 'panel
				pane: copy []
				color: gray
				actors: [
					on-created: function [face event /local r c a][
						pane: copy [origin 1x1 space 1x1 base silver "r" 30x20]
						cols: copy []
						a: copy "A"
						repeat c face/extra/x [
							append/only cols copy a
							append pane compose/deep [colh (copy a) with [extra/col: (c)]]
							either #"Z" = last a [
								change back tail a "AA"
							][
								change back tail a to-char 1 + last a
							]
						]
						append pane 'return
						repeat r face/extra/y [
							append pane compose [base 30x20 silver (form r)]
							repeat c face/extra/x [
								append pane to-set-word addr: rejoin ["r" r "c" c]
								append pane compose/deep/only [cell with [
									extra/name: (name: to-lit-word rejoin [copy cols/:c r])
									extra/face: (addr: to-lit-word addr)
									append cells (reduce [to-word name to-word addr])
								]]
							]
							append pane 'return
						]
						append pane [base "c" silver 30x20]
						repeat c face/extra/x [
							append pane compose/deep [colh (form c) with [extra/col: (c)]]
						]
						layout/parent pane face none
						set-focus r1c1
					]
				]
			]
			init: [
				face/extra: face/size
				face/size: face/size * 80x20 + 30x40 + face/size + 2
				width: face/extra/x + 1
				height: face/extra/y
				;total: face/extra/y + 2 * width
				;last-line: total - width
			]
		]
	]
]
