"Loader check (tests/loader-errors.sh): load libpolycall the way a user does
 and report the outcome. Exit status: 0 loaded, 1 PolycallLoadError,
 2 any other error. Also checks that using the API without a usable library
 signals PolycallLoadError (never a crash)."

Eval [
    | code |
    code := [Polycall load.
             ('loaded ', Polycall libraryPath, ' (binding ABI ', Polycall abiVersion printString,
                 ', version ', Polycall version, ')') displayNl.
             0]
        on: PolycallLoadError
        do: [:e | ('PolycallLoadError: ', e messageText) displayNl. e return: 1].
    code = 1 ifTrue: [
        [Polycall runConfigStatus: 'smalltalk-polycallrc'.
         'API call without a usable library did not fail' displayNl.
         code := 2]
            on: PolycallLoadError
            do: [:e | 'API call without a usable library -> PolycallLoadError' displayNl. e return: nil]].
    ObjectMemory quit: code
]
