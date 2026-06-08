```
% pandoc -f latex+cell_tabulars -t native
\begin{table}
\centering
\caption{Bounds.}
\label{tab:bounds}
\begin{tabular}{lll}
\hline
\multicolumn{1}{c}{\textbf{Parameter}} & \multicolumn{1}{c}{\textbf{\begin{tabular}[c]{@{}c@{}}Upper\\ bound\end{tabular}}} & \multicolumn{1}{c}{\textbf{\begin{tabular}[c]{@{}c@{}}Lower\\ bound\end{tabular}}} \\ \hline
$x$ & 1 & 0 \\ \hline
\end{tabular}
\end{table}
^D
[ Table
    ( "tab:bounds" , [] , [] )
    (Caption Nothing [ Plain [ Str "Bounds." ] ])
    [ ( AlignLeft , ColWidthDefault )
    , ( AlignLeft , ColWidthDefault )
    , ( AlignLeft , ColWidthDefault )
    ]
    (TableHead
       ( "" , [] , [] )
       [ Row
           ( "" , [] , [] )
           [ Cell
               ( "" , [] , [] )
               AlignCenter
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Strong [ Str "Parameter" ] ] ]
           , Cell
               ( "" , [] , [] )
               AlignCenter
               (RowSpan 1)
               (ColSpan 1)
               [ Plain
                   [ Strong [ Str "Upper" , LineBreak , Str "bound" ] ]
               ]
           , Cell
               ( "" , [] , [] )
               AlignCenter
               (RowSpan 1)
               (ColSpan 1)
               [ Plain
                   [ Strong [ Str "Lower" , LineBreak , Str "bound" ] ]
               ]
           ]
       ])
    [ TableBody
        ( "" , [] , [] )
        (RowHeadColumns 0)
        []
        [ Row
            ( "" , [] , [] )
            [ Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Math InlineMath "x" ] ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "1" ] ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "0" ] ]
            ]
        ]
    ]
    (TableFoot ( "" , [] , [] ) [])
]
```

```
% pandoc -f native -t latex+cell_tabulars --wrap=none
[Table ("",[],[]) (Caption Nothing []) [(AlignCenter,ColWidthDefault)] (TableHead ("",[],[]) [Row ("",[],[]) [Cell ("",[],[]) AlignCenter (RowSpan 1) (ColSpan 1) [Plain [Strong [Str "Upper",LineBreak,Str "bound"]]]]]) [] (TableFoot ("",[],[]) [])]
^D
{\def\LTcaptype{none} % do not increment counter
\begin{longtable}[]{@{}c@{}}
\toprule\noalign{}
\textbf{\begin{tabular}[c]{@{}c@{}}Upper\\bound\end{tabular}} \\
\midrule\noalign{}
\endhead
\bottomrule\noalign{}
\endlastfoot
\end{longtable}
}
```

```
% pandoc -f latex+cell_tabulars -t native
\begin{tabular}{ll}
\hline
\multirow{2}{*}{\begin{tabular}[c]{@{}l@{}}Summer:\\ Jun--Aug\end{tabular}} & A \\
 & \begin{tabular}[c]{@{}l@{}}\\B\\C\\\\ \end{tabular} \\
\end{tabular}
^D
[ Table
    ( "" , [] , [] )
    (Caption Nothing [])
    [ ( AlignLeft , ColWidthDefault )
    , ( AlignLeft , ColWidthDefault )
    ]
    (TableHead ( "" , [] , [] ) [])
    [ TableBody
        ( "" , [] , [] )
        (RowHeadColumns 0)
        []
        [ Row
            ( "" , [] , [] )
            [ Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 2)
                (ColSpan 1)
                [ Plain
                    [ Str "Summer:" , LineBreak , Str "Jun\8211Aug" ]
                ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "A" ] ]
            ]
        , Row
            ( "" , [] , [] )
            [ Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "B" , LineBreak , Str "C" ] ]
            ]
        ]
    ]
    (TableFoot ( "" , [] , [] ) [])
]
```
