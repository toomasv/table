Red []
;#include %../utils/leak-check.red
#include %style.red
#include %re.red
~: make op! func [a b][re a b]
tpl: [
	type: 'base 
	size: 300x200 
	color: silver
	flags: [scrollable all-over]
	options: [auto-index: #[true]]
	extra: make map! [tmp: 0x0 current: 0x0 frozen: 0x0]
	me: self
	menu: [
		"Cell" [
			;"Freeze"   freeze-cell
			;"Unfreeze" unfreeze-cell
			"Edit"     edit-cell
		] 
		"Row" [
			"Freeze"   freeze-row
			"Unfreeze" unfreeze-row
			;"Edit"     edit-row
		] 
		"Column" [
			"Sort"   ["Loaded" ["Up" sort-loaded-up "Down" sort-loaded-down] "Up" sort-up "Down" sort-down]
			"Filter ..." filter
			"Unfilter"   unfilter
			"Freeze" freeze-col
			"Unfreeze"   unfreeze-col
			;"Edit ..."   edit-column
			"Type"   ["integer!" integer! "float!" float! "percent!" percent! "string!" string! "block!" block! "date!" date! "time!" time!]
		]
	]
	actors: [
		vscr: hscr: data: down: loaded: size:       ;current: 
		rows: cols: grid: rows-total: cols-total: 
		indexes: default-row-index: row-index: current-row-index: 
		default-col-index: col-index: on-border?: tbl-editor: 
		filtered: col-sizes: 
		marks: last-mark: active: active-offset: anchor: anchor-offset: 
		extra?: extend?: by-key?: none ; latest: latest-offset:
		
		frozen-cols: make block! 20
		frozen-rows: make block! 20
		draw-block:  make block! 1000
		filter-cmd:  make block! 10
		box: 100x25
		
		on-border: func [face ofs /local cum col][
			col-sizes: head col-sizes
			cum: 0
			if not empty? frozen-cols [
				forall frozen-cols [
					col: frozen-cols/1
					cum: cum + col-sizes/:col
					if 2 >= absolute cum - ofs [return index? frozen-cols]
				]
			]
			current: face/extra/current/x
			repeat i cols [
				col: current + i
				if col-sizes/:col [
					cum: cum + col-sizes/:col
					if 2 >= absolute cum - ofs [return face/extra/frozen/x + i]
				]
			] 
			false
		]

		scroll: func [face sc-pos [integer!] /h /local dim][
			;current: face/extra/current
			dim: pick [x y] h
			face/extra/current/:dim: sc-pos - 1
			fill/horizontal face h
		]

		adjust-scroller: func [face][;probe reduce [length? at col-index face/extra/current/x]
			vscr/max-size:  max 1    length? row-index ;at row-index face/extra/current/y
			vscr/page-size: min rows vscr/max-size
			hscr/max-size:  max 1    length? col-index ;at col-index face/extra/current/x
			hscr/page-size: min cols hscr/max-size
		]

		adjust-size: func [/local cum i][
			rows: min round/ceiling/to size/y / box/y 1  rows-total
			;cols: min round/ceiling/to size/x / box/x 1  cols-total
			cols: cols-total
			cum: 0
			repeat i cols-total [
				cum: cum + col-sizes/:i
				if cum >= size/x [cols: i break]
			]
		]

		init-grid: func [face /local i][
			if not empty? data [
				rows-total: length? data
				cols-total: length? first data
				if face/options/auto-index [cols-total: cols-total + 1] ; add auto-index
				col-sizes: make block! cols-total
				append/dup col-sizes box/x cols-total
				;repeat i cols-total [append col-sizes i * box/x]
				adjust-size
				grid: as-pair cols rows
				clear frozen-rows
				clear frozen-cols
			]
		]

		init-indices: func [face /force /local i][
			;Prepare indexes
			either all [indexes not force] [
				clear indexes
				clear default-row-index
				clear default-col-index
				clear frozen-rows
				clear frozen-cols
			][
				indexes: make map! cols-total                   ;Room for index for each column
				filtered: 
					copy row-index: 
					copy default-row-index: make block! rows-total        ;Room for row numbers
				col-index: copy default-col-index: make block! cols-total ;Room for col numbers
			]
			
			repeat i rows-total [append default-row-index i]    ;Default is just simple sequence in initial order
			indexes/1: copy default-row-index                   ;Default is for first (auto-key) column
			append clear row-index default-row-index            ;Set default as active index
			
			repeat i cols-total [append default-col-index i] 
			append clear col-index default-col-index
			
			current-row-index: 1
			adjust-scroller face
		]

		init-fill: function [face /extern marks][
			clear draw-block
			repeat i rows [
				row: make block! cols ;+ 1 ;add index column
				repeat j cols  [;+ 1
					cell: make block! 11    ;each column has 11 elements, see below
					s: (as-pair j i) - 1 * box
					text: form either face/options/auto-index [
						either j = 1 [i][c: col-index/(j - 1) data/:i/:c]
					][
						data/:i/(col-index/:j)
					]
					;Cell structure
					repend cell [
						'line-width 1
						'fill-pen pick [white snow] odd? i
						'box s s + box
						'clip s s + box - 1 
						reduce ['text s + 4x2  text]
					]
					append/only row cell
				]
				append/only draw-block row
			]
			marks: insert tail face/draw: draw-block [line-width 3 fill-pen glass]
		]

		init: func [face /force][
			if not empty? data [
				init-grid face
				either force [init-indices/force face][init-indices face]
				init-fill face
			]
			face/extra/frozen: face/extra/current: 0x0
			hscr/position: vscr/position: 1
		]

		fill-cell: function [face cell r x /sizes sz0 sz1][
			cell/11/3: form either face/options/auto-index [
				either x = 1 [r][c: col-index/(x - 1) data/:r/:c]
			][
				data/:r/(col-index/:x)
			]
			if sizes [
				cell/9/x:         cell/6/x: sz0
				cell/10/x:   -1 + cell/7/x: sz1
				cell/11/2/x:  4 + sz0
			]
		]

		fill: function [face /horizontal h][
			recycle/off
			system/view/auto-sync?: off
			current: face/extra/current
			frozen: face/extra/frozen
			cum: 0
			foreach col frozen-cols [
				cum: cum + col-sizes/:col
			]
			if h [
				repeat i frozen/y [
					r: frozen-rows/:i
					row: face/draw/:i
					x: current/x
					sz0: sz1: cum
					repeat j cols  [
						x: x + 1
						cell: row/(j + frozen/x)
						sz1: sz0 + any [col-sizes/:x 0] ;col-sizes/:x ;
						fill-cell/sizes face cell r x sz0 sz1
						sz0: sz1
					]
				]
			]
			y: current/y 
			repeat i rows [
				y: y + 1
				row: face/draw/(i + frozen/y)
				either y <= length? row-index [
					r: row-index/:y
					unless h [
						repeat j frozen/x [
							x: frozen-cols/:j
							cell: row/:x
							fill-cell face cell r x
						]
					]
					x: current/x
					sz0: sz1: cum
					repeat j cols  [
						x: x + 1
						cell: row/(j + frozen/x)
						cell/4: pick [white snow] odd? y
						sz1: sz0 + any [col-sizes/:x 0] ;col-sizes/:x ;
						fill-cell/sizes face cell r x sz0 sz1
						sz0: sz1
					]
				][;No more data
					repeat j cols  [
						row/:j/4: silver
						row/:j/11/3: ""
					]
				]
			]

			show face
			system/view/auto-sync?: on
			;if all [editor/visible? current/y] [
			;	editor/offset/y: editor/offset/y + (current/y - face/extra/current/y * box/y)
			;]
			;recycle
			recycle/on
		]

		get-draw-address: function [face event][
			col: get-draw-col face event
			row: round/ceiling/to event/offset/y / box/y 1
			as-pair col row
		]
		
		get-draw-offset: function [face cell][
			if s: face/draw/(cell/y)/(cell/x) [
				copy/part at s 6 2
			]
		]

		get-draw-col: function [face event][
			row: face/draw/1
			forall row [if row/1/7/x > event/offset/x [col: index? row break]]
			col
		]
		
		get-col-number: function [face event][ 
			col: get-draw-col face event
			either col <= face/extra/frozen/x [
				frozen-col/:col
			][
				col - face/extra/frozen/x + face/extra/current/x
			]
		]

		get-data-address: function [face event /with cell][
			if not cell [
				x: get-draw-col face event
				y: round/ceiling/to event/offset/y / box/y 1
				cell: as-pair x y
			]
			out: cell - face/extra/frozen + face/extra/current
			if face/options/auto-index [out/x: out/x - 1]
			out
		]

		ask-code: function [][
			view [
				below text "Code:" 
				code: area 400x100 focus
				across button "OK" [out: code/text unview] 
				button "Cancel" [out: none unview]
			]
			out
		]
		
		make-editor: func [table][
			append table/parent/pane layout/only [
				at 0x0 tbl-editor: field hidden with [
					options: [text: none]
					extra: #()
				] on-enter [
					face/visible?: no 
					update-data face 
				] on-key-down [
					switch event/key [
						#"^[" [ ;esc
							append clear face/text face/options/text
							face/visible?: no
						]
						down  [show-editor face/extra/table none face/extra/draw + 0x1];[either cell/y > (cols + face/extra/frozen)]
						up    [show-editor face/extra/table none face/extra/draw - 0x1]
						#"^-" [
							either find event/flags 'shift [
								show-editor face/extra/table none face/extra/draw - 1x0
							][
								show-editor face/extra/table none face/extra/draw + 1x0
							]
						]
					]
				] on-focus [
					face/options/text: copy face/text
				]
			] 
		]
		
		show-editor: function [face event cell][
			addr: get-data-address/with face event cell
			ofs:  get-draw-offset face cell
			either not all [face/options/auto-index addr/x = 0] [ ;Don't edit autokeys
				txt: face/draw/(cell/y)/(cell/x)/11/3
				tbl-editor/extra/data: addr                       ;Register cell
				tbl-editor/extra/draw: cell
				;sz: as-pair col-sizes/(cell/x) box/y
				fof: face/offset                                  ;Compensate offset for VID space
				edit fof + ofs/1 ofs/2 - ofs/1 txt
			][tbl-editor/visible?: no]
		]
		
		hide-editor: does [
			if all [tbl-editor tbl-editor/visible?] [tbl-editor/visible?: no]
		]
		
		add-mark: func [face ofs][
			repend marks ['box ofs/1 ofs/2]
			last-mark: skip tail marks -2
		]
		
		set-anchor: func [face cell][
			anchor: cell
			anchor-offset: get-draw-offset face anchor
		]

		move-anchor: func [step box][
			anchor: anchor + step
			anchor-offset/1: anchor-offset/1 + (step: step * box)
			anchor-offset/2: anchor-offset/2 + step
		]
		
		set-new-mark: func [face cell ofs][
			set-anchor face cell
			add-mark face ofs
		]
		
		extend-last-mark: does [
			last-mark/1: min anchor-offset/1 active-offset/1
			last-mark/2: max anchor-offset/2 active-offset/2
		]
		
		mark-active: func [face cell /extend /extra][
			active-offset: get-draw-offset face cell
			active: cell
			either pair? last face/draw [
				case [
					extend [
						extend?: true
						extend-last-mark
					]
					extra  [
						extend?: false extra?: true
						set-new-mark face cell active-offset
					]
					true   [
						if extra? [clear skip marks 3 extra?: false]
						extend?: false
						set-anchor face cell
						change/part next marks active-offset 2
					]
				]
			] [set-new-mark face cell active-offset]
		]
		
		unmark-active: func [face][
			if active [
				clear marks
				extra?: false
				active: none
			]
		]
		
		update-data: function [face][
			switch type?/word e: face/extra/data [
				pair! [
					type: type? data/(e/y)/(e/x)
					data/(e/y)/(e/x): to type face/text
				]
			] 
		]

		edit: function [ofs sz txt][
			win: tbl-editor
			until [win: win/parent win/type: 'window]
			tbl-editor/offset:    ofs
			tbl-editor/size:      sz
			tbl-editor/text:      txt
			tbl-editor/visible?:  yes
			win/selected:         tbl-editor
		]

		normalize-range: function [range [block!]][
			bs: charset range
			clear range
			repeat i length? bs [if bs/:i [append range i]]
		]

		filter: function [face col [integer!] crit /extern filtered][
			clear filtered
			c: col
			if auto: face/options/auto-index [c: c - 1];col-index/(col - 1)
			either block? crit [
				switch/default type?/word w: crit/1 [
					word! [
						case [
							op? get/any w [
								forall row-index [
									if not find frozen-rows row: first row-index [
										insert/only crit either all [auto col = 1] [row][data/:row/:c]
										if do crit [append filtered row]
										remove crit
									]
								]
							]
							function? get/any w [
								forall row-index [
									row: first row-index
									case [ ;???
										w = 'parse [insert next crit row]
									]
								]
							]
						]
					]
					path! [
						
					]
					paren! [
						
					]
				][  ;Simple list
					either all [auto col = 1] [
						normalize-range crit  ;Use charset spec to select rows
						filtered: intersect row-index crit
					][
						
					]
				]
			][  ;Single entry
				either all [auto  col = 1] [
					filtered: to-block crit
				][
					forall row-index [
						row: row-index/1
						if data/:row/:c = crit [append filtered row]
					]
				]
			]
			append clear row-index filtered
			adjust-scroller face
			fill face
		]

		freeze: function [face event dim /extern cols rows][
			frozen: face/extra/frozen
			current: face/extra/current
			;row: face/draw/1
			face/extra/frozen/:dim: either dim = 'x [
				get-draw-col face event
				;forall row [if row/1/7/x > event/offset/x [col: index? row break]]
				;col
			][
				1 + to-integer event/offset/:dim / box/:dim ; How many first visible rows/cols are frozen?
			]
			frozen/:dim: face/extra/frozen/:dim - frozen/:dim
			if frozen/:dim > 0 [
				either dim = 'y [
					idx: row-index 
					blk: frozen-rows
					rows: rows - frozen/y
					scr: vscr
				][
					idx: col-index 
					blk: frozen-cols
					cols: cols - frozen/x
					scr: hscr
				]
				append blk copy/part at idx current/:dim + 1 frozen/:dim
			]
			face/extra/current/:dim: current/:dim + frozen/:dim
			face/extra/tmp/:dim: face/extra/current/:dim - face/extra/frozen/:dim
			adjust-scroller face
			scr/position: face/extra/current/:dim + 1
			either dim = 'y [
				repeat i face/extra/frozen/y [
					repeat j cols [
						j: j + face/extra/frozen/x 
						face/draw/:i/:j/4: 192.192.192
					]
				]
			][
				repeat i rows [
					i: i + face/extra/frozen/y
					repeat j face/extra/frozen/:dim [face/draw/:i/:j/4: 192.192.192]
				]
			]
		]

		unfreeze: function [face dim][
			set pick [rows cols] dim = 'y to-integer face/size/:dim / box/:dim
			face/extra/tmp/:dim: face/extra/frozen/:dim: 0
			either dim = 'y [scr: vscr blk: frozen-rows][scr: hscr blk: frozen-cols]
			scr/position: 1 + face/extra/current/:dim: 0 
			clear blk
			
			fill face
			adjust-scroller face
		]

		set-scr-pos: function [face dim key][
			scr: get pick [hscr vscr] dim = 'x
			sz:  get pick [cols rows] dim = 'x
			scr/position: min scr/max-size - sz + 2;1 
				max face/extra/frozen/:dim + face/extra/tmp/:dim + 1 
					switch key [
						;track [either event/picked > (rows-total / 2) [event/picked + rows][event/picked]]
						up        left       [scr/position - 1]
						page-up   page-left  [scr/position - scr/page-size]
						down      right      [scr/position + 1]
						page-down page-right [scr/position + scr/page-size]
					] 
		]
		
		on-scroll: function [face event /extern by-key?][;/local key pos1 pos2 dif szx current][
			key: event/key
			unless key = 'end [
				by-key?: false
				case [
					key = 'track [
						either event/orientation = 'vertical [
							dim: 'y scr: vscr steps: rows total: rows-total
						][
							dim: 'x scr: hscr steps: cols total: cols-total
						]
						pos1: scr/position
						pos2: scr/position: 
							min scr/max-size - steps + 1 
								max face/extra/frozen/:dim + face/extra/tmp/:dim + 1 
									either event/picked > (total / 2) [event/picked + steps][event/picked]
						dif: pos2 - pos1 * box/:dim
						either event/orientation = 'vertical [
							scroll face pos2
						][
							scroll/h face pos2
						]
						parse marks [any ['box | s: pair! (s/1/:dim: s/1/:dim + dif)]]
					]
					find [up down page-up page-down] key [
						pos1: vscr/position
						pos2: set-scr-pos face 'y key
						dif: pos1 - pos2 * box/y
						scroll face pos2
						parse marks [any ['box | s: pair! (s/1/y: s/1/y + dif)]]
					]
					true [
						current: face/extra/current
						pos1: hscr/position
						if key = 'left  [szx: col-sizes/(current/x)]
						pos2: set-scr-pos face 'x key
						scroll/h face pos2
						if key = 'right [szx: col-sizes/(current/x + 1)]
						dif: pos1 - pos2
						if szx [dif: dif * szx]
						parse marks [any ['box | s: pair! (s/1/x: s/1/x + dif)]]
					]
				]
			]
		]

		on-wheel: function [face event][;May-be switch shift and ctrl ?
			self/by-key?: false
			either event/shift? [
				face/extra/current/x: 
					min hscr/max-size - cols ; rows-total
						max face/extra/frozen/x + face/extra/tmp/x
							face/extra/current/x - to-integer (event/picked * either event/ctrl? [cols][1])
				hscr/position: face/extra/current/x + 1
				fill/horizontal face true
			][
				face/extra/current/y: 
					min vscr/max-size - rows ; rows-total
						max face/extra/frozen/y + face/extra/tmp/y
							face/extra/current/y - to-integer (event/picked * either event/ctrl? [rows][3])
				vscr/position: face/extra/current/y + 1
				fill face
			]
		]

		on-down: func [face event /local cell][
			set-focus face
			unless on-border?: on-border face event/offset/x [
				hide-editor
				cell: get-draw-address face event
				case [
					event/shift? [mark-active/extend face cell]
					event/ctrl?  [mark-active/extra face cell]
					true [mark-active face cell]
				]
			]
		]
		
		on-unfocus: func [face][
			hide-editor
			unmark-active face
		]

		on-over: function [face event /extern active active-offset anchor anchor-offset][;probe reduce [event/down? on-border?]
			box*: 7 clip: 10
			if event/down? [
				either on-border? [
					ofs0: face/draw/1/:on-border?/:box*/x
					ofs1: event/offset/x
					df: ofs1 - ofs0
					foreach row face/draw [
						if block? row [
							cells: at row on-border?
							forall cells [
								if 1 < index? cells [
									x: cells/-1/:box*/x 
									cells/1/(box* - 1)/x: cells/1/(clip - 1)/x: x
									cells/1/11/2/x: x + 4 ;add text offset
								]
								x: cells/1/:box*/x
								cells/1/:clip/x: -1 + cells/1/:box*/x: x + df
							]
						]
					]
				][;probe reduce [event/offset/x  size/x event/offset/x > size/x]
					case [
						event/offset/y > size/y [
							pos1: vscr/position
							scroll face pos2: set-scr-pos face 'y 'down
							if pos2 > pos1 [
								move-anchor 0x-1 box
								extend-last-mark
							]
						]
						event/offset/y <= 0 [
							pos1: vscr/position
							scroll face pos2: set-scr-pos face 'y 'up
							if pos2 < pos1 [
								move-anchor 0x1 box
								extend-last-mark
							]
						]
						event/offset/x >= size/x [
							pos1: hscr/position
							scroll/h face pos2: set-scr-pos face 'x 'right
							cell: get-draw-offset face face/extra/frozen + 1
							cell: cell/2 - cell/1
							if pos2 > pos1 [
								move-anchor 0x-1 cell
								extend-last-mark
							]
						]
						event/offset/x <= 0 [
							pos1: hscr/position
							cell: get-draw-offset face face/extra/frozen + 1
							cell: cell/2 - cell/1
							scroll/h face pos2: set-scr-pos face 'x 'left
							if pos2 < pos1 [
								move-anchor 1x0 cell
								extend-last-mark
							]
						]
						true [
							if attempt [adr: get-draw-address face event] [
								if all [adr <> active] [
									mark-active/extend face adr
								]
							]
						]
					]
				]
			]
		]

		on-up: function [face event][
			if on-border? [
				ofs0: face/draw/1/:on-border?/6/x
				ofs1: face/draw/1/:on-border?/7/x
				df: ofs1 - ofs0
				col: either on-border? <= col: face/extra/frozen/x [
					frozen-cols/:col
				][
					on-border? - col + face/extra/current/x
				]
				col-sizes/:col: df
			]
		]

		on-dbl-click: function [face event /local e][
			either tbl-editor [
				if tbl-editor/visible? [
					update-data tbl-editor   ;Make sure field is updated according to correct type
					face/draw: face/draw     ;Update draw in case we edited a field and didn't enter
				]
			][
				make-editor face
			]
			tbl-editor/extra/table: face
			cell: get-draw-address face event                     ;Draw-cell address
			show-editor face event cell
		]
		
		on-key-down: func [face event /local key step frozen pos1 pos2 cell szx ofs][;/extern by-key? anchor active anchor-offset active-offset][ ;
			key: event/key
			step: switch key [
				down      [0x1]
				up        [0x-1]
				left      [-1x0]
				right     [1x0]
				page-up   [as-pair 0 negate rows]
				page-down [as-pair 0 rows]
			]
			if all [active step] [
				by-key?: true
				frozen: face/extra/frozen
				current: face/extra/current
				either dim: case [
					any [
						all [key = 'down    frozen/y + rows = active/y]
						all [key = 'up      frozen/y + 1    = active/y]
						find [page-up page-down] key
					][
						pos1: vscr/position
						pos2: set-scr-pos face 'y key
						scroll face pos2
						switch key [
							page-up   [if step/y < step/y: pos2 - pos1 [active/y: active/y - rows - step/y]]
							page-down [if step/y > step/y: pos2 - pos1 [active/y: active/y + rows - step/y]]
						]
						cell: box
						'y
					]
					any [
						all [key = 'right frozen/x + cols = active/x] 
						all [key = 'left  frozen/x + 1    = active/x] 
						all [key = 'right ofs: get-draw-offset face active + step ofs/2/x > size/x] 
					][
						pos1: hscr/position
						if key = 'left  [szx: col-sizes/(current/x)]
						pos2: set-scr-pos face 'x key
						scroll/h face pos2
						if key = 'right [szx: col-sizes/(current/x + 1)]
						step/x: pos2 - pos1
						if szx [cell: as-pair szx 0]
						'x
					]
				][
					either pos1 = pos2 [
						if switch key [
							page-up   [active/y: frozen/y + 1]
							page-down [active/y: rows]
						][
							either event/shift? [;find event/flags 'shift [
								mark-active/extend face active
							][	mark-active face active]
						]
					][
						if find event/flags 'shift [extend?: true]
						;probe reduce [pos1 pos2  pos2 - pos1  "step" step  step * absolute pos2 - pos1 "cell" cell step * cell extend?]
						;step: step * absolute pos2 - pos1
						either any [extra? extend?] [
							cell: step * cell
							anchor: anchor - step
							anchor-offset/1: anchor-offset/1 - cell
							anchor-offset/2: anchor-offset/2 - cell
							active-offset: get-draw-offset face active
							;probe reduce ["active" active "anchor" anchor "cell" cell]
							parse marks [any ['box s: 2 pair! (
								either 2 = length? s [
									s/1/:dim: min anchor-offset/1/:dim active-offset/1/:dim
									s/2/:dim: max anchor-offset/2/:dim active-offset/2/:dim
								][
									s/1: s/1 - cell
									s/2: s/2 - cell
								]
							)]]
						][
							if all [key = 'right ofs: get-draw-offset face active + step ofs/2/x > size/x][
								scroll/h face set-scr-pos face 'x key
							]
							mark-active face active
						]
					]
				][;probe reduce [active step active + step]
					active: active + step
					either find event/flags 'shift [
						mark-active/extend face active
					][	mark-active face active]
				]
			]
		]
		
		on-created: func [face event][
			;put get-scroller face 'horizontal 'visible? no
			vscr: get-scroller face 'vertical
			hscr: get-scroller face 'horizontal
			size: face/size - 17
			if face/data [
				switch type?/word face/data [
					file!  [data: load face/data] ;load/as head clear tmp: find/last read/part file 5000 lf 'csv ;
					block! [data: face/data]
				]
				init face
			]
		]
		
		on-sort: func [face event /loaded /down /local col c frozen current][
			recycle/off
			recycle/off
			col: get-col-number face event
			if down [col: negate col]
			either all [face/options/auto-index  1 = absolute col  indexes/:col][
				;row-index: indexes/:col
				append clear row-index default-row-index
				if down [reverse row-index]
			][
				either indexes/:col [clear indexes/:col][indexes/:col: make block! rows-total]
				;either indexes/:col [
				;	append clear row-index indexes/:col
				;][
					;indexes/:col: make block! rows-total
					c: absolute col
					if face/options/auto-index [c: c - 1]
					sort/compare row-index function [a b][
						attempt [case [
							all [loaded down][(load data/:a/:c) > (load data/:b/:c)]
							down             [data/:a/:c > data/:b/:c]
							loaded           [(load data/:a/:c) <= (load data/:b/:c)]
							true             [data/:a/:c <= data/:b/:c]
						]]
					]
					append indexes/:col row-index
				;]
			]
			vscr/position: either 0 < frozen: face/extra/frozen/y [
				if found: find row-index frozen-rows/:frozen [
					current: face/extra/current/y: index? found
					face/extra/tmp/y: current - frozen
					current + 1
				]
			][
				face/extra/tmp/y: face/extra/current/y: 0
				1
			]
			fill face
			;recycle
			recycle/on
		]
		
		on-menu: function [face event /extern rows cols current-row-index frozen-rows frozen-cols][
			switch event/picked [
				edit-cell [on-dbl-click face event]
			
				freeze-row   [freeze face event 'y]
				unfreeze-row [unfreeze face 'y]
				freeze-col   [freeze face event 'x]
				unfreeze-col [unfreeze face 'x]
				
				sort-up          [on-sort face event]
				sort-down        [on-sort/down face event]
				sort-loaded-up   [on-sort/loaded face event]
				sort-loaded-down [on-sort/loaded/down face event]
				
				filter [
					if code: ask-code [
						code: load code
						col: get-col-number face event
						filter face col code
					]
				]
				unfilter [
					append clear row-index default-row-index
					adjust-scroller face
					fill face
				]
				
				edit-column [
					if code: ask-code [
						code: load code 
						col: get-col-number face event
						if not all [face/options/auto-index col = 1][
							foreach row data [parse row/:col code]
							fill face
						]
					]
				]
				integer! float! percent! string! block! date! time! [
					col: get-col-number face event
					if not all [auto: face/options/auto-index  col = 1][
						if auto [col: col - 1]
						type: reduce event/picked
						forall data [if not find frozen-rows index? data [data/1/:col: to type data/1/:col]]
					]
				]
			]
		]
	]
]
