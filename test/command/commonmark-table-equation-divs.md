```
% pandoc -f commonmark_x+table_divs -t native
::: {#tab:x .table}
| A | B |
|---|---|
| 1 | 2 |

::: {.caption}
Caption.
:::

::: {.tablenotes}
Notes.
:::
:::
^D
[ Table
    ( "tab:x" , [] , [] )
    (Caption Nothing [ Para [ Str "Caption." ] ])
    [ ( AlignDefault , ColWidthDefault )
    , ( AlignDefault , ColWidthDefault )
    ]
    (TableHead
       ( "" , [] , [] )
       [ Row
           ( "" , [] , [] )
           [ Cell
               ( "" , [] , [] )
               AlignDefault
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Str "A" ] ]
           , Cell
               ( "" , [] , [] )
               AlignDefault
               (RowSpan 1)
               (ColSpan 1)
               [ Plain [ Str "B" ] ]
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
                [ Plain [ Str "1" ] ]
            , Cell
                ( "" , [] , [] )
                AlignDefault
                (RowSpan 1)
                (ColSpan 1)
                [ Plain [ Str "2" ] ]
            ]
        ]
    ]
    (TableFoot ( "" , [] , [] ) [])
, Div
    ( "" , [ "tablenotes" ] , [] ) [ Para [ Str "Notes." ] ]
]
```

```
% pandoc -f latex -t commonmark_x+citations+table_divs --wrap=none
\begin{table}
\caption{Base case configuration of particle-based CSP plant.}
\label{tab:BaseValuePlant}
\begin{tabular}{ll}
\hline
\textbf{Variables} & \textbf{Value} \\ \hline
Plant location$^1$ & Daggett, CA \\ \hline
\end{tabular}
\begin{tablenotes}
\item{1}. \citet{USDOE2019}
\end{tablenotes}
\end{table}
^D
::::: {#tab:BaseValuePlant .table}
| **Variables**      | **Value**   |
|:-------------------|:------------|
| Plant location$^1$ | Daggett, CA |

::: {.caption}
Base case configuration of particle-based CSP plant.
:::

::: {.tablenotes}
1. @USDOE2019
:::
:::::
```

```
% pandoc -f native -t commonmark_x+table_divs --wrap=none
[Table ("tab:x",[],[]) (Caption Nothing [Plain [Str "Caption."]]) [(AlignDefault,ColWidthDefault)] (TableHead ("",[],[]) []) [] (TableFoot ("",[],[]) [])]
^D
:::: {#tab:x .table}
|     |
|-----|

::: {.caption}
Caption.
:::
::::
```

```
% pandoc -f latex -t commonmark_x+equation_divs --wrap=none
\begin{equation}
\label{eq:foo}
E = mc^2
\end{equation}

See Eq. \ref{eq:foo}.
^D
::: {#eq:foo .equation}
$$\begin{equation}
\label{eq:foo}
E = mc^2
\end{equation}$$
:::

See Eq. [](#eq:foo){reference-type="ref" reference="eq:foo"}.
```
