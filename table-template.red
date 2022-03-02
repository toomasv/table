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
	menu: [
		"Cell" [
			;"Freeze"   freeze-cell
			;"Unfreeze" unfreeze-cell
			;"Edit"     edit-cell
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
		default-col-index: col-index: frozen-rows: frozen-cols: on-border?: none 
		
		draw-block: make block! 1000
		filter-cmd: make block! 10
		filtered: col-sizes: none
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
				cum: cum + col-sizes/:col
				if 2 >= absolute cum - ofs [return face/extra/frozen/x + i]
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

		adjust-size: does [
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
				frozen-rows: make block! rows
				frozen-cols: make block! cols
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

		init-fill: function [face][
			clear draw-block
			repeat i rows [
				row: make block! cols ;+ 1 ;add index column
				repeat j cols  [;+ 1
					cell: make block! 9    ;each column has 9 elements, see below
					s: (as-pair j i) - 1 * box
					text: form either face/options/auto-index [
						either j = 1 [i][c: col-index/(j - 1) data/:i/:c]
					][
						data/:i/(col-index/:j)
					]
					;Cell structure
					repend cell [
						'fill-pen pick [white snow] odd? i
						'box s s + box
						'clip s s + box - 1 reduce [
							'text s + 4x2  text
						]
					]
					append/only row cell
				]
				append/only draw-block row
			]
			face/draw: draw-block
		]

		init: func [face /force][
			if not empty? data [
				init-grid face
				either force [init-indices/force face][init-indices face]
				init-fill face
			]
			face/extra/current/y: 0 vscr/position: 1
			face/extra/current/x: 0 hscr/position: 1
		]

		fill-cell: function [face cell r x /sizes sz0 sz1][
			cell/9/3: form either face/options/auto-index [
				either x = 1 [r][c: col-index/(x - 1) data/:r/:c]
			][
				data/:r/(col-index/:x)
			]
			if sizes [
				cell/7/x:        cell/4/x: sz0
				cell/8/x:   -1 + cell/5/x: sz1
				cell/9/2/x:  4 + sz0
			]
		]

		fill: function [face /horizontal h][
			recycle/off
			system/view/auto-sync?: off
			current: face/extra/current
			frozen: face/extra/frozen
			cum: 0
			if h [
				foreach col frozen-cols [
					cum: cum + col-sizes/:col
				]
				repeat i frozen/y [
					r: frozen-rows/:i
					row: face/draw/:i
					x: current/x
					sz0: sz1: cum
					repeat j cols  [
						x: x + 1
						cell: row/(j + frozen/x)
						sz1: sz0 + col-sizes/:x
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
						cell/2: pick [white snow] odd? y
						sz1: sz0 + col-sizes/:x
						fill-cell/sizes face cell r x sz0 sz1
						sz0: sz1
					]
				][;No more data
					repeat j cols  [
						row/:j/2: silver
						row/:j/9/3: ""
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

		get-col-number: function [face event][ 
			row: face/draw/1
			forall row [if row/1/5/x > event/offset/x [col: index? row break]]
			;col: 1 + to-integer event/offset/x / box/x 
			either col <= face/extra/frozen/x [
				frozen-col/:col
			][
				col - face/extra/frozen/x + face/extra/current/x
			]
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
			row: face/draw/1
			forall row [if row/1/5/x > event/offset/x [col: index? row break]]
			face/extra/frozen/:dim: col ;1 + to-integer event/offset/:dim / box/:dim ; How many first visible rows/cols are frozen?
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
						face/draw/:i/:j/2: 192.192.192
					]
				]
			][
				repeat i rows [
					i: i + face/extra/frozen/y
					repeat j face/extra/frozen/:dim [face/draw/:i/:j/2: 192.192.192]
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

		on-scroll: func [face event][
			unless event/key = 'end [
				case [
					event/key = 'track [
						;either 
						scroll face vscr/position: 
							min vscr/max-size - rows + 1 
								max face/extra/frozen/y + face/extra/tmp/y + 1 
									either event/picked > (rows-total / 2) [event/picked + rows][event/picked]
					]
					find [up down page-up page-down] event/key [
						scroll face vscr/position: 
							min vscr/max-size - rows + 1 
								max face/extra/frozen/y + face/extra/tmp/y + 1 
									switch event/key [
										;track [either event/picked > (rows-total / 2) [event/picked + rows][event/picked]]
										up        [vscr/position - 1]
										page-up   [vscr/position - vscr/page-size]
										down      [vscr/position + 1]
										page-down [vscr/position + vscr/page-size]
									] 
					]
					true [
						scroll/h face hscr/position: 
							min hscr/max-size - cols + 1
								max face/extra/frozen/x + face/extra/tmp/x + 1 
									switch event/key [
										;track [probe 'track]
										left       [hscr/position - 1]
										page-left  [hscr/position - hscr/page-size]
										right      [hscr/position + 1]
										page-right [hscr/position + hscr/page-size]
									]
					]
				]
			]
		]

		on-wheel: function [face event][
			;current: face/extra/current
			face/extra/current/y: 
				min vscr/max-size - rows ; rows-total
					max face/extra/frozen/y + face/extra/tmp/y
						face/extra/current/y - to-integer (event/picked * either event/ctrl? [rows][3])
			vscr/position: face/extra/current/y + 1
			fill face
		]

		on-down: func [face event][
			on-border?: on-border face event/offset/x
		]

		on-over: function [face event][;probe reduce [event/down? on-border?]
			box: 5 clip: 8
			if all [event/down? on-border?][
				ofs0: face/draw/1/:on-border?/:box/x
				ofs1: event/offset/x
				df: ofs1 - ofs0
				foreach row face/draw [
					cells: at row on-border?
					forall cells [
						if 1 < index? cells [
							x: cells/-1/:box/x 
							cells/1/(box - 1)/x: cells/1/(clip - 1)/x: x
							cells/1/9/2/x: x + 4 ;add text offset
						]
						x: cells/1/:box/x
						cells/1/:clip/x: -1 + cells/1/:box/x: x + df
					]
				]
			]
		]

		on-up: function [face event][
			if on-border? [
				ofs0: face/draw/1/:on-border?/4/x
				ofs1: face/draw/1/:on-border?/5/x
				df: ofs1 - ofs0
				col: either on-border? <= col: face/extra/frozen/x [
					frozen-cols/:col
				][
					on-border? - col + face/extra/current/x
				]
				col-sizes/:col: df
			]
		]

		;on-dbl-click: function [face event /local ofs cell y found txt][
		;	if editor/visible? [face/draw: face/draw]                ;Update draw in case we edited a field and didn't enter
		;	ofs: as-pair round/down/to event/offset/x box/x     ;Get cell coordinates
		;				 round/down/to event/offset/y box/y
		;	cell: ofs / box                                     ;Get cell address
		;	either cell/x > 0 [                                ;Don't edit autokeys
		;		found: find find face/draw as-pair 0 ofs/y 'text  ;Which row do we have? Find autokey (first entry in row)
		;		either empty? found/3 [
		;			editor/visible?: no
		;		][
		;			y: to-integer found/3                          ;Autokey's value
		;			txt: data/(y - 1 * (cols - 1) + cell/x)        ;Get original entry from data
		;			editor/extra/current/y: cell/x + 1                       ;Register column
		;			edit ofs + 10 txt                              ;Compensate offset for VID space
		;		]
		;	][editor/visible?: no]
		;]
		
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
