Red [
	Date: 1-June-2019
	Last: 13-May-2020
	Author: "Toomas Vooglaid"
	Licence: "Public domain"
	Description: "Table formatting. Produces top or panel VID. Resulting table is editable"
]
context [
	style: special-style: _default: arr: editor: sp-pane: none
	special: make block! 10
	widths: make block! 10
	get-size: func [c][either widths/:c [as-pair widths/:c 20][1000x20]]

	dummy: layout/options [
		_default: 		panel [] 
		style: 			panel [] 
		special-style: 	panel [] 
	][visible?: no]
	arr-block: [
		at 0x0 arr: box 182x105 0.0.0.254 
			draw [pen blue] 
			on-down [
				append face/draw compose/deep [
					line (quote (ofs: event/offset)) (quote (ofs)) 
					transform 0x0 0 1 1 (quote (ofs)) [
						shape [move -4x-2 'line 4x2 -4x2 move -10x5]
					]
				]
				line: skip tail face/draw -10
			]
			all-over on-over [
				if event/down? [
					line/3: line/9: event/offset 
					diff: line/3 - line/2
					line/6: arctangent2 diff/y diff/x
				]
			]
	]
	edit: func [face][
		editor/offset: face/offset
		editor/size: face/size
		editor/extra: face
		editor/text: face/text
		editor/font: face/font
		editor/visible?: yes
		face/parent/parent/selected: editor
	]
	extend system/view/VID/styles [
		cell: [template: [
			type: 'base color: white 
			para: make para! [wrap?: yes] 
			font: make font! [size: 11] 
			actors: [on-dbl-click: func [face event][edit face]]
		]]
		arrows: [
			template: [
				type: 'base
				color: 0.0.0.254
				draw: copy []
				actors: [
					ofs: line: none
					on-down: func [face event][
						ofs: event/offset
						append event/face/draw compose [line: line (ofs) (ofs)]
					]
					on-over: func [face event][
						line/3: event/offset
					]
				]
			]
		]
	]
	make-special: func [frmt r c][
		either found: find/tail special reduce [r c][
			either block? found/1 [
				unique append found/1 frmt
			][
				found/1: unique append to-block found/1 frmt
			]
		][
			append special-style/pane layout/only append copy [cell] frmt
			repend special [r c frmt sp-pane: back tail special-style/pane]
			sp-pane/1/size: get-size c
		]
	]

	set 'table function [
		{Formats block of data into editable table}
		data 			[block!] 	{Block of data to format, if data element is block  
									it is interpreted as a cell with special format}
		columns 		[block! integer!] 	{Block of formats for each column or a number of columns}
		/size    sz 	[integer!] 	{Table width, default 700}
		/backdrop bd	[tuple!]	{Layout's backdrop}
		/margin  mrg	[pair!]		{Sets `origin` for layout}
		/head    th 	[block!]	{Table has head with common format. 
									(`th` e.g [gray white bold ["Col1" "Col2" [right "Col3"]]])}
		/tight 						{Default width is ignored, size is calculated from cells}
		/rows    rws 	[block!]	{Block of rotating styles for rows}
		/cond    cnd    [block!]	{Conditional format for specific cells, rows or arbitrary conditions}
		;/default def 	[block! word! integer!]
		/lines	 bg 	[tuple! integer! pair! block!]	{Color of inter-cell lines or width of lines 
		                            (vertical_x_horizontal if pair!) or both if block!}
		/border  pd		[integer! pair!] {Width of table's border (vertical_x_horizontal if pair!)}
		/arrows                     {Allows to draw arrows on table}
		/only                       {Generates top-VID; without only generates panel VID to be used inside main layout}
		/with    args   [block!]    {Can be used instead of /refinement args}
		/extern 
			editor sp-pane special widths
	][
		ctx: self
		default-size: 700
		styles: make block! 10
		cols: make block! 10
		free-widths: make block! 10
		heights: make block! 50
		body: copy []
		texts: copy []
		unsized: height: 0
		row: 1
		spc: none
		sps: 0
		clear special
		clear widths
		view/no-wait dummy
		if with [
			parse args [any [
			  'size     set sz skip  (size: yes)
			| 'backdrop set bd skip  (backdrop: yes)
			| 'margin   set mrg skip (margin: yes)
			| 'head     set th skip  (head: yes)
			| 'tight    (tight: yes)
			| 'rows     set rws skip (rows: yes)
			| 'cond     set cnd skip (cond: yes)
			| 'lines    set bg skip  (lines: yes)
			| 'border   set pd skip  (border: yes)
			| 'arrows   (arrows: yes)
			| 'only     (only: yes)
			| skip
			]]
		]
		data: copy data
		case [
			tuple? bg [ln: 1x1]
			word?  bg [bg: get bg ln: 1x1]
			integer? bg [ln: to-pair bg bg: gray]
			pair? bg [ln: bg bg: gray]
			block? bg [
				parse bg [any [
				  [set w tuple! | set x word! if (tuple? y: get x)(w: y)] (bg: w)
				| [set w pair! | set x integer! (w: to pair! x)] (ln: w)	
				| skip
				]]
			]
			true [bg: gray ln: 1x1]
		]
		;if def [insert _default/pane append copy [cell] def]
		if head [
			if all [found: find th block! any ['font <> first back found found: find next found block!]] [
				if spc: th/line [remove/part find th 'line 2]
				heads: take found		;Add heads to data
				forall heads [
					switch type?/word heads/1 [
						string! [data: insert/only data append copy th heads/1]
						block!	[data: insert/only data union copy th heads/1]
					]
				]
				if spc [insert next data reduce ['space ln]]
				data: system/words/head data
				if spc [insert data reduce ['space as-pair ln/x spc]]
			]
		]
		if integer? columns [columns: append/only/dup clear [] copy [] columns]
		forall columns [
			width: case [
				integer? columns/1 [also columns/1 columns/1: as-pair columns/1 1]
				pair? columns/1 [columns/1/x]
				block? columns/1 [
					case [
						w: find columns/1 pair! [w/1/x] 
						all [w: find columns/1 integer! 'font-size <> first back w][also w/1 w/1: as-pair w/1 1]
					]
				]
			]
			append widths width 
			if not width [unsized: unsized + 1]
			append cols word: to-word rejoin ["col" index? columns]
			if block? columns/1 [bind columns/1 self]
			append styles sty: compose [style (to-set-word word) cell (columns/1)]
			append style/pane layout/only at sty 3 
		]
		len-cols: length? cols
		if size [default-size: sz]
		if all [not tight unsized > 0] [
			auto-size: default-size / unsized
			replace/all widths none auto-size
		]
		forall data [
			either 'space = data/1 [
				sps: sps + 2 
				append texts copy/part data 2
				data: next data 
			][
				c: (index? data) - sps - 1 % len-cols + 1
				r: (index? data) - sps - 1 / len-cols + 1
				sp-st: no      ;by default no special-style
				txt: switch/default type?/word data/1 [
					string! [data/1]
					block! [   ; special-style!
						txt: either all [
							txt: find data/1 string! 
							any [
								'font-name <> first back txt 
								txt: find next txt string!
							]
						] [take txt][copy ""]
						make-special data/1 r c
						sp-st: yes
						txt
					]
				][form data/1]
				if cond [
					foreach [cd frmt] cnd [
						if any [
							all [pair? cd cd = as-pair r c] 	; Specific cell at row x col
							all [integer? cd cd = r]			; Specific row
							all [block? cd attempt [do bind cd :table]]		; Evaluation of condition returns true
						][
							make-special frmt r c
							sp-st: yes
						]
					]
				]
				style/pane/:c/size: get-size c
				text-size: size-text/with either sp-st [sp-pane/1][style/pane/:c] txt
				;print [txt text-size]
				unless widths/:c [
					put free-widths c either fw: select free-widths c [ 
						max fw text-size/x
					][
						text-size/x
					] 
				]
				height: either row = r [
					max height text-size/y
				][
					row: r 
					append heights height
					0
				]
				append texts txt
			]
		]
		sps: 0
		append heights height
		if c < len-cols []  ; ???
		row: 1
		;probe texts
		forall texts [
			either 'space = texts/1 [
				sps: sps + 2
				append body copy/part texts 2
				texts: next texts
			][
				c: (index? texts) - sps - 1 % len-cols + 1
				r: (index? texts) - sps - 1 / len-cols + 1
				found: find/tail special reduce [r c]
				td: reduce [
					either found ['cell][cols/:c] texts/1 either widths/:c [
						as-pair widths/:c heights/:r
					][
						as-pair select free-widths c heights/:r
					]
				]
				if all [rows any [not th r > 1]][append td rws/(r - 1 % (length? rws) + 1)]
				;if row <> r [row: r insert td 'return]
				if found [append td found/1]
				new-line td true
				append body td
			]
		]
		unview/all
		;system/view/metrics/margins/base: [3x0 0x3]
		pd: either integer? pd [to pair! pd][any [pd ln]]
		
		pan: compose/deep [
			panel (len-cols) (bg) [
				;across
				origin (pd) space (ln)
				(styles) 
				(body)
				at 0x0 editor: field hidden ;no-border 
					on-enter [face/visible?: no]
				(either arrows [bind compose/deep arr-block self][])
			]
		]
		lay: compose/deep [
			(either only []['panel])
			(either backdrop [either only [reduce ['backdrop bd]][bd]][])
			(either all [only margin] [reduce ['origin mrg]][])
			(either only [pan][compose/deep either margin [[[origin (mrg) (pan)]]][[[(pan)]]]])
			do [if (arrows) [arr/size: arr/parent/size]]
		] 
	]
]
e.g.: :comment 
e.g. [;Table as main layout
	files: read %.
	texts: copy []
	foreach file files [
		probe modified: query file 
		append texts reduce [mold file modified/date rejoin [modified/hour ":" modified/minute]]
	]
	tbl: table/only/tight/rows/head texts [[] [center beige] [right]] [silver white] [gray white ["File" "Date" "Time"]]
	view tbl
]
e.g. [;Table as panel in layout
	files: collect [foreach file read %. [mod: query file keep file keep mod/date keep mod/time]]
	view compose [
		below text "My files" (
			table/with files [[bold left][center][center orange red]] 
			[tight margin 20x20 backdrop leaf lines orange border 2 cond [2x2 [leaf gold bold]] head [gray white bold ["File" "Date" "Time"] line 2]]
		)
	] 
]
e.g. [
	;Doesn't use table; plain simple
	view [panel black [
		origin 1x1 space 1x1 
		style c: text wrap center white 50x32 
		c bold "Row 1" c "Cell 1.2" c "Cell 1.3" c "Longer text" return 
		c bold "Row 2" c "Cell 2.2" c "Cell 2.3" c "Cell 2.4"
	]]
]