"GNU Smalltalk adapter for the smalltalk_polycall native shim."

Error subclass: PolycallError [
    | status |

    <category: 'Polycall-Errors'>

    PolycallError class >> status: anInteger [
        ^self new
            status: anInteger;
            yourself
    ]

    status [
        ^status
    ]

    status: anInteger [
        status := anInteger
    ]

    messageText [
        ^'libpolycall failed with status ', status printString
    ]
]

Object subclass: Polycall [
    <category: 'Polycall-Core'>

    Polycall class >> loadLibrary: libraryName [
        DLD addLibrary: libraryName
    ]

    Polycall class >> runConfigPrimitive: configPath [
        <cCall: 'smalltalk_polycall_run_config'
            returning: #int
            args: #(#string)>
    ]

    Polycall class >> runConfigStatus: configPath [
        configPath isString ifFalse: [
            self error: 'configPath must be a String'
        ].
        ^self runConfigPrimitive: configPath
    ]

    Polycall class >> runConfig: configPath [
        | status |
        status := self runConfigStatus: configPath.
        status = 0 ifFalse: [
            (PolycallError status: status) signal
        ].
        ^status
    ]
]
