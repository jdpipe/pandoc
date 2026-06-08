```
% pandoc -f commonmark_x+citations+bracketed_spans+footnotes -t native
@doe
[@doe]
[see @doe, pp. 33-35; also @roe, chap. 2]
[-@smith]
[@doe](url)
[@doe]{.x}
hello@doe.com
see @doe
^D
[ Para
    [ Cite
        [ Citation
            { citationId = "doe"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = AuthorInText
            , citationNoteNum = 1
            , citationHash = 0
            }
        ]
        [ Str "@doe" ]
    , SoftBreak
    , Cite
        [ Citation
            { citationId = "doe"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = NormalCitation
            , citationNoteNum = 2
            , citationHash = 0
            }
        ]
        [ Str "[@doe]" ]
    , SoftBreak
    , Cite
        [ Citation
            { citationId = "doe"
            , citationPrefix = [ Str "see" ]
            , citationSuffix =
                [ Str "," , Space , Str "pp." , Space , Str "33-35" ]
            , citationMode = NormalCitation
            , citationNoteNum = 3
            , citationHash = 0
            }
        , Citation
            { citationId = "roe"
            , citationPrefix = [ Str "also" ]
            , citationSuffix =
                [ Str "," , Space , Str "chap." , Space , Str "2" ]
            , citationMode = NormalCitation
            , citationNoteNum = 3
            , citationHash = 0
            }
        ]
        [ Str "[see @doe, pp. 33-35; also @roe, chap. 2]" ]
    , SoftBreak
    , Cite
        [ Citation
            { citationId = "smith"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = SuppressAuthor
            , citationNoteNum = 4
            , citationHash = 0
            }
        ]
        [ Str "[-@smith]" ]
    , SoftBreak
    , Link ( "" , [] , [] ) [ Str "@doe" ] ( "url" , "" )
    , SoftBreak
    , Span ( "" , [ "x" ] , [] ) [ Str "@doe" ]
    , SoftBreak
    , Str "hello"
    , Str "@doe.com"
    , SoftBreak
    , Str "see"
    , Space
    , Cite
        [ Citation
            { citationId = "doe"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = AuthorInText
            , citationNoteNum = 5
            , citationHash = 0
            }
        ]
        [ Str "@doe" ]
    ]
]
```

```
% pandoc -f commonmark+citations -t native
[@doe]
^D
2> The extension 'citations' is not supported for commonmark.
2> Use --list-extensions=commonmark to list supported extensions.
=> 23
```

```
% pandoc -f commonmark_x+citations -t native
@doe.
-@roe?
@smith.v2.
^D
[ Para
    [ Cite
        [ Citation
            { citationId = "doe"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = AuthorInText
            , citationNoteNum = 1
            , citationHash = 0
            }
        ]
        [ Str "@doe" ]
    , Str "."
    , SoftBreak
    , Cite
        [ Citation
            { citationId = "roe"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = SuppressAuthor
            , citationNoteNum = 2
            , citationHash = 0
            }
        ]
        [ Str "-@roe" ]
    , Str "?"
    , SoftBreak
    , Cite
        [ Citation
            { citationId = "smith.v2"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = AuthorInText
            , citationNoteNum = 3
            , citationHash = 0
            }
        ]
        [ Str "@smith.v2" ]
    , Str "."
    ]
]
```

```
% pandoc -f commonmark_x+citations+sourcepos -t native
[@doe]
^D
[ Div
    ( ""
    , []
    , [ ( "wrapper" , "1" ) , ( "data-pos" , "1:1-2:1" ) ]
    )
    [ Para
        [ Span
            ( ""
            , []
            , [ ( "wrapper" , "1" ) , ( "data-pos" , "1:1-1:7" ) ]
            )
            [ Cite
                [ Citation
                    { citationId = "doe"
                    , citationPrefix = []
                    , citationSuffix = []
                    , citationMode = NormalCitation
                    , citationNoteNum = 1
                    , citationHash = 0
                    }
                ]
                [ Str "[@doe]" ]
            ]
        ]
    ]
]
```
