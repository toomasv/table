Red [
	Description: {Nano spreadsheet}
	Date: 12-Jun-2019
	Author: "Toomas Vooglaid"
]
context [
	cells: copy []
	extend system/view/VID/styles [
		colh: [
			template: [
				type: 'base
				size: 80x20
				color: silver
				extra: copy [col: #[none]]
				flags: [all-over]
				actors: [
					ofs: pos: col: len: parent: none
					drag?: no 
					on-down: func [face event][
						if within? event/offset as-pair face/size/x - 5 0 5x25 [
							col: face/extra/col + 1
							len: face/parent/extra/x + 1
							ofs: event/offset/x
							par: face/parent
							pos: at face/parent/pane col
							drag?: yes
							system/view/auto-sync?: off
						]
					]
					on-over: func [face event /local current][
						if drag? [
							dfx: event/offset/x - ofs
							par/size/x: par/size/x + dfx
							current: pos
							until [
								current/1/size/x: current/1/size/x + dfx
								loop len - col [current: next current current/1/offset/x: current/1/offset/x + dfx]
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
					on-down: func [face event][
						set-focus face
						keypos: offset-to-caret face event/offset
						if face/extra/formula/1 = #"=" [face/text: face/extra/formula]
						;show face
					]
					on-enter: func [face event /local found][
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
							true [face/data: load face/text]
						]
						set face/extra/name face/data
						;show face
						len: face/parent/extra/x + 1
						pos: find face/parent/pane face
						if (length? pos) > len [set-focus first skip pos len]
						;set-focus first skip find face/parent/pane face face/parent/extra/x + 1
					]
					on-key-down: func [face event /local pos][
						index? pos: find face/parent/pane face
						len: face/parent/extra/x + 1
						idx: index? pos
						if find [left-shift right-shift] event/key [shift?: yes]
						if find [left-control right-control] event/key [ctrl?: yes]
						kp0: keypos
						switch/default event/key [
							left [
								if ctrl? [
									keypos: either found: find/reverse/tail at face/text keypos - 1 stop [
										index? found
									][	1]
								]
								case [
									all [
										keypos = 1 
										idx - 1 % len + 1 > 2  len + 2 < index? pos
									][set-focus first back pos]
									all [not ctrl? keypos > 1] [keypos: keypos - 1]
								]
							]
							right [
								if ctrl? [
									keypos: either found: find at face/text keypos + 1 stop [
										index? found
									][	length? face/text]
								]
								either all [
									keypos > length? face/text 
									idx - 1 % len + 1 < len
								][
									set-focus first next pos
								][	keypos: keypos + 1]
							]
							up [if idx - 1 / len > 1 [set-focus first skip pos 0 - len]]
							down [if (length? pos) > len [set-focus first skip pos len]]
							home [either ctrl? [set-focus r1c1][keypos: 1]]
							end [keypos: 1 + length? face/text]
							#"^-" [
								either shift? [
									if all [idx - 1 % len + 1 > 2  len + 2 < index? pos][set-focus first back pos]
								][
									if idx - 1 % len + 1 < len [set-focus first next pos]
								]
							]
							left-shift left-control right-shift right-control
						][keypos: keypos + 1]
						;print ["kp0:" kp0 "kp1:" keypos] 
					]
					on-key-up: func [face event][
						if find [left-shift right-shift] event/key [shift?: no]
						if find [left-control right-control] event/key [ctrl?: no]
					]
					on-focus: func [face event][keypos: 1 shift?: ctrl?: no]
				]
			]
		]
		sheet: [
			template: [
				type: 'panel
				pane: copy []
				color: black
				actors: [
					on-created: function [face event /local r c a][
						pane: copy [origin 1x1 space 1x1 base silver 30x20]
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
						layout/parent pane face none
						set-focus r1c1
					]
				]
			]
			init: [
				face/extra: face/size
				face/size: face/size * 80x20 + 30x20 + face/size + 1
			]
		]
	]
]