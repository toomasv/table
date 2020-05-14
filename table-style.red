Red [
	Date: 14-May-2020
	Author: "Toomas Vooglaid"
	Licence: "Public domain"
	Description: "Add `table` style to VID. Resulting table is editable"
	Table-DSL: {
		data 			    [block!] 	{Block of data to format, if data element is block  
										it is interpreted as a cell with special format}
		extra [
			columns clms    [block! integer!] 	{Block of formats for each column or a number of columns}
		|	size    sz 	    [integer! pair!] 	{Table width if integer (default 700) 
										 TBD! width_x_height if pair (default max height 2/3rds of screen)}
		|	head    th 	    [block!]	{Table has head with common format. 
										(`th` e.g [gray white bold ["Col1" "Col2" [right "Col3"]]])}
		|	tight 						{Default width is ignored, size is calculated from cells}
		|	rows    rws 	[block!]	{Block of rotating styles for rows}
		|	cond    cnd     [block!]	{Conditional format for specific cells, rows or arbitrary conditions}
			;/default def 	[block! word! integer!]
		|	lines	bg 	    [tuple! integer! pair! block!]	{Color of inter-cell lines or width of lines 
										(vertical_x_horizontal if pair!) or both if block!}
		|	border  pd		[integer! pair!] {Width of table's border (vertical_x_horizontal if pair!)}
		]
	}
]
context [
	style: special-style: _default: editor: sp-pane: none
	special:  make block! 10
	widths:   make block! 10
	get-size: func [col][either widths/:col [as-pair widths/:col 20][1000x20]]

	dummy: layout/options [
		_default: 		panel [] 
		style: 			panel [] 
		special-style: 	panel [] 
	][visible?: no]
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
			extra: copy []
			actors: [on-dbl-click: func [face event][edit face]]
		]]
		table: [
			template: [type: 'panel]
			init: [table face]
		]
	]
	make-special: func [frmt row col][
		either found: find/tail special reduce [row col][
			either block? found/1 [
				unique append found/1 frmt
			][
				found/1: unique append to-block found/1 frmt
			]
		][
			append special-style/pane layout/only append copy [cell] frmt
			repend special [row col frmt sp-pane: back tail special-style/pane]
			sp-pane/1/size: get-size col
		]
	]

	table: function [
		{Formats block of data into editable table}
		face
		/extern 
			editor sp-pane special widths
	][
		columns: size: sz: head: th: tight: rows: rws: cond: cnd: lines: bg: border: pd: none
		data: face/data
		args: face/extra
		;columns: args/columns
		ctx: self
		default-size: as-pair 700 system/view/screens/1/size/y / 3 * 2
		pan-size: none                ;table-panel-size
		styles: make block! 100       ;to keep custom styles
		cols: make block! 100         ;styles for columns
		free-widths: make block! 100  ;
		heights: make block! 1000     ;height of each row
		body: copy []                 ;final table VID
		texts: copy []                ;data prepared for body
		unsized: height: 0            ;
		current-row: 1                ;to keep track of rows
		spc: none                     ;changing space value
		sps: 0                        ;to keep track of `space` changes
		clear special
		clear widths
		view/no-wait dummy
		if args [
			parse args [any [
			  'columns  set columns skip 
			| 'size     set sz  skip (size:     yes)
			| 'backdrop set bd  skip (backdrop: yes)
			| 'margin   set mrg skip (margin:   yes)
			| 'head     set th  skip (head:     yes)
			| 'rows     set rws skip (rows:     yes)
			| 'cond     set cnd skip (cond:     yes)
			| 'lines    set bg  skip (lines:    yes)
			| 'border   set pd  skip (border:   yes)
			| 'tight    (tight:  yes)
			| skip
			]]
		]
		if not columns [cause-error 'user 'message ["`columns` needs to be defined. See Table-DSL in header of %table-style.red."]]
		data: copy data ;as we might be changing data (inserting `space xy` somewhere)
		if not margin [margin: yes mrg: 0x0] ;don't use margin by default for panel layout
		case [
			tuple?   bg [ln: 1x1]
			word?    bg [bg: get bg ln: 1x1]
			integer? bg [ln: to-pair bg bg: none]
			pair?    bg [ln: bg bg: none]
			block?   bg [
				parse bg [any [
				  [set w tuple! | set x word! if (tuple? y: get x)(w: y)] (bg: w)
				| [set w pair!  | set x integer! (w: to pair! x)] (ln: w)	
				| skip
				]]
			]
			true [bg: none ln: 1x1]
		]
		face/color: any [bg gray]
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
				if spc [insert next data reduce ['space ln]] ;if we need to underline head, restore here default space
				data: system/words/head data
				if spc [insert data reduce ['space as-pair ln/x spc]] ;thicker y space
			]
		]
		if integer? columns [columns: append/only/dup clear [] copy [] columns]
		forall columns [
			width: switch type?/word columns/1 [
				integer! [also columns/1 columns/1: as-pair columns/1 1]
				pair! [columns/1/x]
				block! [
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
		if size [
			switch type?/word sz [
				integer! [default-size/x: sz] 
				pair!    [default-size:   sz]
			]
		]
		if all [not tight unsized > 0] [
			auto-size: default-size/x / unsized
			replace/all widths none auto-size
		]
		forall data [
			either 'space = data/1 [
				sps: sps + 2 
				append texts copy/part data 2
				data: next data 
			][
				col: (index? data) - sps - 1 % len-cols + 1
				row: (index? data) - sps - 1 / len-cols + 1
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
						make-special data/1 row col
						sp-st: yes
						txt
					]
				][form data/1]
				if cond [
					foreach [cd frmt] cnd [
						if any [
							all [pair? cd cd = as-pair row col] 	        ; Specific cell at row x col
							all [integer? cd cd = row]			            ; Specific row
							all [block? cd attempt [do bind cd :table]]		; Evaluation of condition returns true
						][
							make-special frmt row col
							sp-st: yes
						]
					]
				]
				style/pane/:col/size: get-size col
				text-size: size-text/with either sp-st [sp-pane/1][style/pane/:col] txt
				unless widths/:col [
					put free-widths col either fw: select free-widths col [ 
						max fw text-size/x
					][
						text-size/x
					] 
				]
				height: either current-row = row [
					max height text-size/y
				][
					current-row: row 
					append heights height
					0
				]
				append texts txt
			]
		]
		sps: 0
		append heights height
		if col < len-cols []  ; ???
		current-row: 1
		forall texts [
			either 'space = texts/1 [
				sps: sps + 2
				append body copy/part texts 2
				texts: next texts
			][
				col: (index? texts) - sps - 1 % len-cols + 1
				row: (index? texts) - sps - 1 / len-cols + 1
				found: find/tail special reduce [row col]
				td: reduce [
					either found ['cell][cols/:col] 
					texts/1 
					either widths/:col [
						as-pair widths/:col heights/:row
					][
						as-pair select free-widths col heights/:row
					]
				]
				if all [rows any [not th row > 1]][append td rws/(row - 1 % (length? rws) + 1)]
				if found [append td found/1]
				new-line td true
				append body td
			]
		]
		unview/all
		pd: either integer? pd [to pair! pd][any [pd ln]]
		layout/parent compose/deep [
			origin (pd) space (ln)
			(styles) 
			(body)
			at 0x0 editor: field hidden ;no-border 
				on-enter [face/visible?: no]
		] face len-cols
		
	]
]
e.g.: :comment

e.g. [
	;do %table-style.red 
	view [
		table data ["a" 2 3 "b" 1.5 13% "c" now %file.red] extra [
			columns 3 
			head [orange white bold ["One" "Two" "Three"] line 3] 
			tight 
			lines [leaf 2x0] 
			border 3
		]
	]
]

e.g. [
	;do %table-style.red 
	files: collect [
		foreach file copy/part read %. 50 [
			mod: query file 
			keep file keep mod/date keep mod/time
		]
	] 
	view [
		table data files extra [
			columns [[left bold] [center 120] center] 
			head [gray white bold ["File" "Date" "Time"]] 
			lines 0x1 
			border 1 
			tight
		]
	]
]
