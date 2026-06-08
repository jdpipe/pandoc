```
% pandoc -f commonmark_x+figure_divs -t native
::: {#fig:foo .figure layout=grid}
![A](a.png){#fig:a}

::: caption
A caption.
:::
:::
^D
[ Figure
    ( "fig:foo" , [] , [ ( "layout" , "grid" ) ] )
    (Caption
       Nothing [ Para [ Str "A" , Space , Str "caption." ] ])
    [ Para
        [ Image ( "fig:a" , [] , [] ) [ Str "A" ] ( "a.png" , "" ) ]
    ]
]
```

```
% pandoc -f commonmark_x -t native
::: {#fig:foo .figure}
![A](a.png)

::: caption
A caption.
:::
:::
^D
[ Div
    ( "fig:foo" , [ "figure" ] , [] )
    [ Para
        [ Image ( "" , [] , [] ) [ Str "A" ] ( "a.png" , "" ) ]
    , Div
        ( "" , [ "caption" ] , [] )
        [ Para [ Str "A" , Space , Str "caption." ] ]
    ]
]
```

```
% pandoc -f latex -t commonmark_x+figure_divs
\begin{figure}[h!]
\begin{subfigure}[b]{0.44\textwidth}
\includegraphics[width=\columnwidth]{figs/Whole mesh.pdf}
\end{subfigure}
\caption{Mesh overview.}
\label{fig:mesh}
\end{figure}
^D
:::: {#fig:mesh .figure latex-placement="h!"}
::: {.figure}
![](<figs/Whole mesh.pdf>){width="\\columnwidth"}
:::

::: {.caption}
Mesh overview.
:::
::::
```

```
% pandoc -f latex -t commonmark_x+figure_divs
\begin{figure}
\includegraphics{figs/mesh.pdf}
\caption{Mesh overview.}
\label{fig:mesh}
\end{figure}

Figure \ref{fig:mesh}; \autoref{fig:mesh}.
^D
:::: {#fig:mesh .figure}
![](figs/mesh.pdf)

::: {.caption}
Mesh overview.
:::
::::

Figure [](#fig:mesh){reference-type="ref" reference="fig:mesh"};
[](#fig:mesh){reference-type="ref+label" reference="fig:mesh"}.
```

```
% pandoc -f native -t commonmark_x+figure_divs
[Figure ("fig:optimisation diagram",[],[]) (Caption Nothing [Plain [Str "Optimisation",Space,Str "diagram."]]) [Plain [Image ("",[],[]) [] ("figs/optimisation-technique.pdf","")]]]
^D
:::: {id="fig:optimisation diagram" .figure}
![](figs/optimisation-technique.pdf)

::: {.caption}
Optimisation diagram.
:::
::::
```
