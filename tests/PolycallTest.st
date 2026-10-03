"SUnit tests of smalltalk-polycall against the REAL installed Polycall core.

 Run from the repository root (see tests/run-real-core.sh):
   gst-sunit -v -f src/Polycall.st -f tests/PolycallTest.st PolycallLibraryTest \
       PolycallConfigTest PolycallCallTest PolycallPeerTest PolycallInteropTest
 Environment: POLYCALL_LIBRARY (libpolycall), POLYCALL_CLI (the polycall
 executable, default 'polycall' on PATH), POLYCALL_ST_WAKER (the test-only
 native waker fixture, tests/fixtures/st_waker.c)."

Object subclass: PolycallTestSupport [
    <category: 'Polycall-Tests'>

    PolycallTestSupport class [ | token tmpRoot counter waker | ]

    PolycallTestSupport class >> token [
        ^token ifNil: [token := 'st-qa-', Time millisecondClock printString,
            (Random new between: 100000 and: 999999) printString]
    ]

    PolycallTestSupport class >> cli [
        | explicit |
        explicit := Smalltalk getenv: 'POLYCALL_CLI'.
        ^(explicit notNil and: [explicit notEmpty]) ifTrue: [explicit] ifFalse: ['polycall']
    ]

    PolycallTestSupport class >> cliWithToken: aToken [
        ^'POLYCALL_DEV_TOKEN=', aToken, ' POLYCALL_TELEMETRY=off ', self cli
    ]

    PolycallTestSupport class >> cliCommand [ ^self cliWithToken: self token ]

    PolycallTestSupport class >> newTempDir [
        | dir |
        tmpRoot isNil ifTrue: [
            tmpRoot := ((Smalltalk getenv: 'TMPDIR') ifNil: ['/tmp']), '/st-polycall-', self token.
            self shell: 'mkdir -p ', tmpRoot].
        counter := (counter ifNil: [0]) + 1.
        dir := tmpRoot, '/d', counter printString.
        self shell: 'mkdir -p ', dir.
        ^dir
    ]

    PolycallTestSupport class >> cleanup [
        tmpRoot isNil ifFalse: [self shell: 'rm -rf ', tmpRoot]
    ]

    PolycallTestSupport class >> shell: aCommand [
        "Exit status of /bin/sh -c aCommand (the VM blocks while it runs; the
         core's listener threads keep serving meanwhile)."
        ^(Smalltalk system: aCommand) bitShift: -8
    ]

    PolycallTestSupport class >> write: aString to: aPath [
        | f |
        f := FileStream open: aPath mode: FileStream write.
        [f nextPutAll: aString] ensure: [f close]
    ]

    PolycallTestSupport class >> read: aPath [
        | f |
        (File exists: aPath) ifFalse: [^''].
        f := FileStream open: aPath mode: FileStream read.
        ^[f contents] ensure: [f close]
    ]

    PolycallTestSupport class >> waitForFile: aPath [
        200 timesRepeat: [
            ((File exists: aPath) and: [(self read: aPath) notEmpty])
                ifTrue: [^(self read: aPath) trimSeparators].
            (Delay forMilliseconds: 50) wait].
        ^nil
    ]

    PolycallTestSupport class >> json: aString at: aKey [
        | marker start rest stop |
        marker := '"', aKey, '":"'.
        start := aString indexOfSubCollection: marker.
        start = 0 ifTrue: [^nil].
        rest := aString copyFrom: start + marker size to: aString size.
        stop := rest indexOf: $".
        stop = 0 ifTrue: [^nil].
        ^rest copyFrom: 1 to: stop - 1
    ]

    PolycallTestSupport class >> base64Decode: aString [
        | alphabet out buffer bits |
        alphabet := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.
        out := WriteStream on: (ByteArray new: 0).
        buffer := 0.
        bits := 0.
        aString do: [:c | | v |
            v := alphabet indexOf: c.
            v > 0 ifTrue: [
                buffer := ((buffer bitShift: 6) bitOr: v - 1) bitAnd: 16rFFFFFF.
                bits := bits + 6.
                bits >= 8 ifTrue: [
                    bits := bits - 8.
                    out nextPut: ((buffer bitShift: bits negated) bitAnd: 255)]]].
        ^out contents
    ]

    PolycallTestSupport class >> bytes: aString [ ^aString asByteArray ]

    PolycallTestSupport class >> loadWaker [
        "Bind st_waker_after from the native test fixture; answer false if absent."
        | path handle address |
        waker == true ifTrue: [^true].
        path := Smalltalk getenv: 'POLYCALL_ST_WAKER'.
        (path isNil or: [path isEmpty]) ifTrue: [^false].
        handle := DLD linkFile: path.
        handle isNil ifTrue: [^false].
        address := DLD library: handle getFunc: 'st_waker_after'.
        address isNil ifTrue: [^false].
        DLD defineCFunc: 'st_waker_after' as: address.
        ^waker := true
    ]

    PolycallTestSupport class >> wake: aHandle after: ms what: what [
        <cCall: 'st_waker_after' returning: #int args: #(#int #uInt #int)>
    ]
]

TestCase subclass: PolycallTestCase [
    <category: 'Polycall-Tests'>

    expect: aStatus in: aBlock [
        "Assert aBlock signals PolycallError with aStatus (and the core's name
         for it); answer the error."
        | error |
        error := nil.
        aBlock on: PolycallError do: [:e | error := e. e return: nil].
        self assert: error notNil.
        error isNil ifTrue: [^nil].
        (error status = aStatus) ifFalse: [
            Transcript showCr: 'expected status ', aStatus printString, ', got ', error messageText].
        self assert: error status = aStatus.
        self assert: error statusName = (Polycall statusName: aStatus).
        self assert: error detail notNil.
        ^error
    ]

    support [ ^PolycallTestSupport ]
]

PolycallTestCase subclass: PolycallLibraryTest [
    <category: 'Polycall-Tests'>

    testLoadedAndAbiVersion [
        Polycall ensureLoaded.
        self assert: Polycall isLoaded.
        self assert: Polycall abiVersion = 1.
        self assert: Polycall requiredAbiVersion = 1.
        self assert: Polycall checkAbi.
        self assert: ((Polycall libraryPath indexOfSubCollection: 'polycall') > 0)
    ]

    testLibraryVersion [
        self assert: Polycall version = '1.1.0'
    ]

    testStatusNames [
        0 to: -18 by: -1 do: [:s | self assert: ((Polycall statusName: s) startsWith: 'POLYCALL_')].
        self assert: ((Polycall statusName: -4) startsWith: 'POLYCALL_E_TIMEOUT').
        self assert: (((Polycall statusName: -999) indexOfSubCollection: 'UNKNOWN') > 0)
    ]

    testErrorCarriesStatusNameAndDetail [
        | e |
        e := self expect: -7 in: [Polycall runConfig: '/nonexistent-dir/smalltalk-polycallrc'].
        self assert: (e statusName startsWith: 'POLYCALL_E_NOT_FOUND').
        self assert: e detail notEmpty.
        self assert: ((e messageText indexOfSubCollection: 'POLYCALL_E_NOT_FOUND') > 0).
        self assert: ((e messageText indexOfSubCollection: e detail) > 0).
        self assert: Polycall lastErrorDetail notEmpty
    ]

    testOriginalErrorConstructorKept [
        | e |
        e := PolycallError status: 37.
        self assert: e status = 37.
        self assert: ((e messageText indexOfSubCollection: '37') > 0)
    ]

    testNulRefusedNotTruncated [
        | path e |
        path := 'smalltalk-polycallrc', (String with: (Character value: 0)), 'x'.
        e := self expect: -1 in: [Polycall runConfig: path].
        self assert: ((e detail indexOfSubCollection: 'NUL') > 0)
    ]

    testTimeoutRangeChecked [
        | peer |
        peer := PolycallPeer open: 'range' bind: nil token: nil.
        [self expect: -1 in: [peer recv: -1].
         self expect: -1 in: [peer recv: 4294967296].
         self expect: -1 in: [peer recv: 'soon']]
            ensure: [peer close]
    ]
]

PolycallTestCase subclass: PolycallConfigTest [
    | dir |
    <category: 'Polycall-Tests'>

    setUp [ dir := self support newTempDir ]

    file: aName contents: aString [
        | path |
        path := dir, '/', aName.
        self support write: aString to: path.
        ^path
    ]

    testShippedConfigsStrict [
        self assert: (Polycall runConfigStatus: 'smalltalk-polycallrc') = 0.
        self assert: (Polycall runConfig: 'smalltalk-polycallrc') = 0.
        self assert: (Polycall runConfig: 'examples/smalltalk-polycallrc' strict: true) = 0.
        self assert: (Polycall runConfig: 'smalltalk-polycallrc' strict: false) = 0
    ]

    testMissingFile [
        self assert: (Polycall runConfigStatus: dir, '/missing-polycallrc') = -7.
        self expect: -7 in: [Polycall runConfig: dir, '/missing-polycallrc']
    ]

    testEmptyPath [
        self expect: -1 in: [Polycall runConfig: '']
    ]

    testNonStringPathIsAnError [
        self should: [Polycall runConfigStatus: 42] raise: Error
    ]

    testInvalidValue [
        | p e |
        p := self file: 'bad-polycallrc' contents: 'max_connections=lots
'.
        e := self expect: -13 in: [Polycall runConfig: p strict: false].
        self assert: ((e detail indexOfSubCollection: 'max_connections') > 0)
    ]

    testUnknownKeyLenientVersusStrict [
        | p |
        p := self file: 'unknown-polycallrc' contents: 'log_level=info
mystery_key=1
'.
        self assert: (Polycall runConfig: p strict: false) = 0.
        self expect: -13 in: [Polycall runConfig: p strict: true].
        self assert: (Polycall runConfigStatus: p) = -13
    ]

    testTlsUnsupportedWhenStrict [
        | p |
        p := self file: 'tls-polycallrc' contents: 'tls_enabled=true
cert_file=/x/c.pem
key_file=/x/k.pem
'.
        self assert: (Polycall runConfig: p strict: false) = 0.
        self expect: -15 in: [Polycall runConfig: p strict: true]
    ]

    testNonAsciiPath [
        | p |
        p := self file: 'Ünicødé-日本-polycallrc' contents: 'log_level=info
max_connections=10
'.
        self assert: (Polycall runConfig: p) = 0.
        self assert: (((Polycall describe: p) indexOfSubCollection: 'max_connections') > 0)
    ]

    testDescribePolycallfile [
        | p json |
        p := self file: 'Polycallfile' contents: 'server node 8080:8084
network start
workspace_root=/opt/x
log_directory=/var/log/x
daemon_endpoint=127.0.0.1:0
auth_token_env=POLYCALL_DEV_TOKEN
peer_node_id=alpha
peer beta 127.0.0.1:9002
'.
        self assert: (Polycall runConfig: p) = 0.
        json := Polycall describe: p.
        self assert: ((json indexOfSubCollection: '"beta":"127.0.0.1:9002"') > 0).
        self assert: ((json indexOfSubCollection: '"layer":"project"') > 0)
    ]

    testDescribeMissingFile [
        self expect: -7 in: [Polycall describe: dir, '/nope']
    ]
]

TestResource subclass: PolycallDaemonResource [
    | dir endpoint |
    <category: 'Polycall-Tests'>

    setUp [
        | rc |
        dir := PolycallTestSupport newTempDir.
        PolycallTestSupport write: 'log_level=info
' to: dir, '/Polycallfile'.
        rc := PolycallTestSupport shell: PolycallTestSupport cliCommand,
            ' daemon start --endpoint 127.0.0.1:0 --state-dir ', dir, '/state ', dir,
            '/Polycallfile > ', dir, '/start.out 2>&1'.
        rc = 0 ifTrue: [
            endpoint := PolycallTestSupport json: (PolycallTestSupport read: dir, '/state/daemon.json')
                at: 'endpoint']
    ]

    tearDown [
        PolycallTestSupport shell: PolycallTestSupport cliCommand, ' daemon stop --state-dir ',
            dir, '/state ', dir, '/Polycallfile > /dev/null 2>&1'
    ]

    endpoint [ ^endpoint ]
    isAvailable [ ^endpoint notNil ]
]

PolycallTestCase subclass: PolycallCallTest [
    <category: 'Polycall-Tests'>

    PolycallCallTest class >> resources [ ^Array with: PolycallDaemonResource ]

    endpoint [
        | ep |
        ep := PolycallDaemonResource current endpoint.
        self assert: ep notNil.
        ^ep
    ]

    testEchoSuccess [
        | out |
        out := Polycall call: self endpoint service: 'debug' operation: 'echo'
            input: '{"a":1,"s":"héllo"}' timeout: 5000.
        self assert: ((out indexOfSubCollection: '"a":1') > 0).
        self assert: ((out indexOfSubCollection: '"echo"') > 0)
    ]

    testNilInputIsNull [
        | out |
        out := Polycall call: self endpoint service: 'debug' operation: 'echo' input: nil timeout: 5000.
        self assert: (out reject: [:c | c = $ ]) = '{"echo":null}'
    ]

    testInventory [
        | out |
        out := Polycall call: self endpoint service: 'inventory' operation: 'get'
            input: '{"item_id":"widget-a"}' timeout: 5000.
        self assert: ((out indexOfSubCollection: '"quantity":42') > 0)
    ]

    testUnknownOperation [
        | e |
        e := self expect: -7 in: [Polycall call: self endpoint service: 'debug' operation: 'nope'
            input: nil timeout: 5000].
        self assert: ((e output indexOfSubCollection: 'operation.unknown') > 0)
    ]

    testRemoteOperationError [
        | e |
        e := nil.
        [Polycall call: self endpoint service: 'inventory' operation: 'get'
            input: '{"item_id":"nope"}' timeout: 5000]
                on: PolycallError do: [:err | e := err. err return: nil].
        self assert: e notNil.
        self assert: (#(-9 -7) includes: e status).
        self assert: ((e output indexOfSubCollection: 'item.unknown') > 0)
    ]

    testDeadline [
        | start |
        start := Time millisecondClock.
        self expect: -4 in: [Polycall call: self endpoint service: 'debug' operation: 'sleep'
            input: '{"ms":3000}' timeout: 300].
        self assert: Time millisecondClock - start < 2500
    ]

    testInvalidInputJson [
        self expect: -1 in: [Polycall call: self endpoint service: 'debug' operation: 'echo'
            input: '{not json' timeout: 5000]
    ]

    testNoRuntime [
        self expect: -5 in: [Polycall call: '127.0.0.1:1' service: 'debug' operation: 'echo'
            input: nil timeout: 2000]
    ]

    testTimeoutBounds [
        | ep r |
        ep := self endpoint.
        self expect: -1 in: [Polycall call: ep service: 'debug' operation: 'echo' input: nil timeout: 0].
        self expect: -1 in: [Polycall call: ep service: 'debug' operation: 'echo' input: nil timeout: 600001].
        r := [Polycall call: ep service: 'debug' operation: 'echo' input: nil timeout: 1]
            on: PolycallError do: [:e | e return: e status].
        self assert: (r isString or: [r = -4]).
        self assert: (Polycall call: ep service: 'debug' operation: 'echo' input: nil timeout: 600000) notEmpty
    ]

    testTooSmallOutputBuffer [
        | e need out |
        e := self expect: -10 in: [Polycall call: self endpoint service: 'debug' operation: 'echo'
            input: '{"k":"0123456789"}' timeout: 5000 outputCapacity: 4].
        need := e requiredSize.
        self assert: need > 4.
        out := Polycall call: self endpoint service: 'debug' operation: 'echo'
            input: '{"k":"0123456789"}' timeout: 5000 outputCapacity: need + 1.
        self assert: out size = need
    ]

    testCallsFromSeveralSmalltalkProcesses [
        "Smalltalk processes are green threads: their call-outs are serialized
         by the VM, but each must still get its own correct result."
        | done results ep |
        ep := self endpoint.
        done := Semaphore new.
        results := Array new: 8.
        1 to: 8 do: [:i |
            [results at: i put: (Polycall call: ep service: 'debug' operation: 'echo'
                input: '{"n":', i printString, '}' timeout: 5000).
             done signal] fork].
        8 timesRepeat: [done wait].
        1 to: 8 do: [:i |
            self assert: ((results at: i) reject: [:c | c = $ ]) = ('{"echo":{"n":', i printString, '}}')]
    ]
]

PolycallTestCase subclass: PolycallPeerTest [
    | alpha beta alphaEp betaEp |
    <category: 'Polycall-Tests'>

    setUp [
        alpha := PolycallPeer open: 'alpha' bind: '127.0.0.1:0' token: self support token.
        beta := PolycallPeer open: 'beta' bind: '127.0.0.1:0' token: self support token.
        alphaEp := alpha endpoint.
        betaEp := beta endpoint.
        alpha register: 'beta' endpoint: betaEp.
        beta register: 'alpha' endpoint: alphaEp
    ]

    tearDown [
        alpha isClosed ifFalse: [alpha close].
        beta isClosed ifFalse: [beta close]
    ]

    expectMessage: aPeer from: aSender id: anId payload: aByteArray [
        | m |
        m := aPeer recv: 5000.
        self assert: m sender = aSender.
        self assert: m messageId = anId.
        self assert: m payload = aByteArray.
        ^m
    ]

    testOpenValidation [
        self expect: -1 in: [PolycallPeer open: '' bind: '127.0.0.1:0' token: nil].
        self expect: -1 in: [PolycallPeer open: 'bad id' bind: '127.0.0.1:0' token: nil].
        self expect: -1 in: [PolycallPeer open: (String new: 64 withAll: $a) bind: nil token: nil].
        (PolycallPeer open: (String new: 63 withAll: $a) bind: nil token: nil) close.
        self expect: -1 in: [PolycallPeer open: 'x' bind: 'nohostport' token: nil].
        self expect: -13 in: [PolycallPeer open: 'x' bind: '0.0.0.0:0' token: nil]
    ]

    testEndpointsHandlesAndSendOnlyNode [
        | sendOnly |
        self assert: (alphaEp startsWith: '127.0.0.1:').
        self assert: (alphaEp copyFrom: 11 to: alphaEp size) asNumber > 0.
        self assert: alpha handle > 0.
        self assert: alpha handle ~= beta handle.
        self assert: beta nodeId = 'beta'.
        sendOnly := PolycallPeer open: 'sender-only' bind: nil token: self support token.
        [self assert: sendOnly endpoint = ''.
         sendOnly send: 'from a send-only node' to: betaEp id: 'so-1' timeout: 2000.
         self expectMessage: beta from: 'sender-only' id: 'so-1'
            payload: (self support bytes: 'from a send-only node')]
            ensure: [sendOnly close]
    ]

    testAddressInUse [
        self expect: -14 in: [PolycallPeer open: 'dup' bind: alphaEp token: nil]
    ]

    testRegistryOwnership [
        | gamma |
        gamma := PolycallPeer open: 'gamma' bind: '127.0.0.1:0' token: self support token.
        [self assert: gamma listJson = '{}'.
         self assert: alpha listJson = ('{"beta":"', betaEp, '"}').
         alpha send: 'hi' to: gamma endpoint id: 'own-1' timeout: 2000.
         gamma recv: 3000.
         self assert: gamma listJson = '{}'.
         self assert: beta listJson = ('{"alpha":"', alphaEp, '"}').
         alpha unregister: 'beta'.
         self expect: -7 in: [alpha unregister: 'beta'].
         self expect: -1 in: [alpha register: 'bad id' endpoint: betaEp].
         self expect: -1 in: [alpha register: 'x' endpoint: '127.0.0.1:0']]
            ensure: [gamma close]
    ]

    testPingAndIdentity [
        self assert: (alpha ping: 'beta' timeout: 2000) = 0.
        self assert: (alpha ping: betaEp timeout: 2000) = 0.
        alpha register: 'impostor' endpoint: betaEp.
        self expect: -6 in: [alpha ping: 'impostor' timeout: 2000].
        alpha unregister: 'impostor'.
        self expect: -7 in: [alpha ping: 'nobody' timeout: 500].
        self expect: -5 in: [alpha ping: '127.0.0.1:1' timeout: 1000]
    ]

    testHealth [
        | json |
        json := beta healthJson.
        self assert: (self support json: json at: 'node_id') = 'beta'.
        self assert: (self support json: json at: 'status') = 'ok'
    ]

    testPayloadsBothDirections [
        alpha send: 'hello beta' to: 'beta' id: 'a2b-1' timeout: 2000.
        self expectMessage: beta from: 'alpha' id: 'a2b-1' payload: (self support bytes: 'hello beta').
        beta send: 'hello alpha' to: 'alpha' id: 'b2a-1' timeout: 2000.
        self expectMessage: alpha from: 'beta' id: 'b2a-1' payload: (self support bytes: 'hello alpha')
    ]

    testEmptyUtf8AndBinaryPayloads [
        | utf8 binary m |
        alpha send: ByteArray new to: 'beta' id: 'empty-1' timeout: 2000.
        self expectMessage: beta from: 'alpha' id: 'empty-1' payload: ByteArray new.
        utf8 := 'héllo — 世界 🌍'.
        alpha send: utf8 to: 'beta' id: 'utf8-1' timeout: 2000.
        m := self expectMessage: beta from: 'alpha' id: 'utf8-1' payload: utf8 asByteArray.
        self assert: m text = utf8.
        binary := (ByteArray new: 260).
        0 to: 255 do: [:i | binary at: i + 1 put: i].
        binary at: 259 put: 255.
        alpha send: binary to: 'beta' id: 'bin-1' timeout: 2000.
        self expectMessage: beta from: 'alpha' id: 'bin-1' payload: binary
    ]

    testMaximumPayloadAndOneByteOver [
        | max over |
        max := ByteArray new: Polycall maxPayload.
        1 to: max size do: [:i | max at: i put: (i * 31 + 7) \\ 256].
        alpha send: max to: 'beta' id: 'max-1' timeout: 15000.
        self expectMessage: beta from: 'alpha' id: 'max-1' payload: max.
        over := max copyWith: 1.
        self expect: -10 in: [alpha send: over to: 'beta' id: 'over-1' timeout: 2000].
        self expect: -4 in: [beta recv: 300]
    ]

    testTooSmallBufferKeepsMessageQueued [
        | e |
        alpha send: '0123456789' to: 'beta' id: 'size-1' timeout: 2000.
        e := self expect: -10 in: [beta recv: 2000 capacity: 4].
        self assert: e requiredSize = 10.
        self expect: -10 in: [beta recv: 2000 capacity: 0].
        self expectMessage: beta from: 'alpha' id: 'size-1' payload: (self support bytes: '0123456789')
    ]

    testReceiveTimeoutAndPoll [
        | start elapsed |
        start := Time millisecondClock.
        self expect: -4 in: [beta recv: 150].
        elapsed := Time millisecondClock - start.
        self assert: elapsed >= 100.
        self assert: elapsed < 3000.
        self expect: -4 in: [beta recv: 0]
    ]

    testDuplicateMessageIdDeliveredOnce [
        alpha send: 'once' to: 'beta' id: 'dup-1' timeout: 2000.
        alpha send: 'once' to: 'beta' id: 'dup-1' timeout: 2000.
        self expectMessage: beta from: 'alpha' id: 'dup-1' payload: (self support bytes: 'once').
        self expect: -4 in: [beta recv: 300]
    ]

    testGeneratedMessageId [
        | m |
        alpha send: 'auto' to: 'beta' id: nil timeout: 2000.
        m := beta recv: 2000.
        self assert: m messageId notEmpty.
        self assert: m text = 'auto'
    ]

    testInvalidMessageId [
        self expect: -1 in: [alpha send: 'x' to: 'beta' id: 'bad id!' timeout: 2000]
    ]

    testSendToDeadPeer [
        | doomed ep |
        doomed := PolycallPeer open: 'doomed' bind: '127.0.0.1:0' token: self support token.
        ep := doomed endpoint.
        doomed close.
        self expect: -5 in: [alpha send: 'into the void' to: ep id: nil timeout: 2000].
        self expect: -5 in: [alpha send: 'x' to: '127.0.0.1:1' id: nil timeout: 1000]
    ]

    testSendToUnregisteredId [
        self expect: -7 in: [alpha send: 'x' to: 'unknown-peer' id: nil timeout: 1000]
    ]

    testAuthFailures [
        | carol mallory |
        carol := PolycallPeer open: 'carol' bind: nil token: nil.
        mallory := PolycallPeer open: 'mallory' bind: nil token: 'not-the-token'.
        [self expect: -8 in: [carol send: 'x' to: betaEp id: nil timeout: 2000].
         self expect: -8 in: [mallory send: 'x' to: betaEp id: nil timeout: 2000].
         self expect: -4 in: [beta recv: 200]]
            ensure: [carol close. mallory close]
    ]

    testBackpressure [
        | accepted busy |
        accepted := 0.
        busy := nil.
        1 to: 300 do: [:i |
            busy isNil ifTrue: [
                [alpha send: 'f' to: 'beta' id: 'flood-', i printString timeout: 2000.
                 accepted := accepted + 1]
                    on: PolycallError do: [:e | busy := e status. e return: nil]]].
        self assert: accepted = 256.
        self assert: busy = -11.
        accepted timesRepeat: [beta recv: 2000].
        alpha send: 'after' to: 'beta' id: 'after-drain' timeout: 2000.
        self expectMessage: beta from: 'alpha' id: 'after-drain' payload: (self support bytes: 'after')
    ]

    testDoubleCloseAndCallsAfterClose [
        | node |
        node := PolycallPeer open: 'short-lived' bind: '127.0.0.1:0' token: self support token.
        self assert: node close = 0.
        self assert: node isClosed.
        self expect: -3 in: [node close].
        self expect: -3 in: [node endpoint].
        self expect: -3 in: [node nodeId].
        self expect: -3 in: [node send: 'x' to: betaEp id: nil timeout: 1000].
        self expect: -3 in: [node recv: 0].
        self expect: -3 in: [node register: 'p' endpoint: betaEp].
        self expect: -3 in: [node listJson].
        self expect: -3 in: [node healthJson].
        self expect: -3 in: [node cancel].
        self expect: -3 in: [node ping: betaEp timeout: 1000]
    ]

    testInvalidHandleValues [
        #(0 -1 2147483647) do: [:raw | | fake |
            fake := PolycallPeer unownedHandle: raw.
            self expect: -3 in: [fake endpoint].
            self expect: -3 in: [fake close]]
    ]

    testCancelWithoutWaiterThenReceiveWaitsNormally [
        self assert: beta cancel = 0.
        self expect: -4 in: [beta recv: 150]
    ]

    testCancelWakesBlockedReceiveFromNativeThread [
        "No Smalltalk process can run while the VM is blocked in recv, so the
         waker is a native thread (tests/fixtures/st_waker.c)."
        | start e |
        self assert: self support loadWaker.
        self assert: (self support wake: beta handle after: 300 what: 0) = 0.
        start := Time millisecondClock.
        e := self expect: -12 in: [beta recv: Polycall waitForever].
        self assert: Time millisecondClock - start >= 200.
        self assert: Time millisecondClock - start < 5000.
        self expect: -4 in: [beta recv: 100]
    ]

    testCloseWakesBlockedReceiveFromNativeThread [
        | start |
        self assert: self support loadWaker.
        self assert: (self support wake: beta handle after: 300 what: 1) = 0.
        start := Time millisecondClock.
        self expect: -17 in: [beta recv: Polycall waitForever].
        self assert: Time millisecondClock - start < 5000.
        "the native thread closed the handle: closing it here is a double close"
        self expect: -3 in: [beta close]
    ]

    testSendersInSeveralSmalltalkProcesses [
        "Green-thread senders: serialized by the VM at each call-out, each
         message must still arrive exactly once with its own id."
        | done failures seen |
        done := Semaphore new.
        failures := 0.
        1 to: 8 do: [:t |
            [1 to: 30 do: [:i |
                [alpha send: 'payload ', t printString, '/', i printString to: 'beta'
                    id: 't', t printString, '-m', i printString timeout: 5000]
                        on: PolycallError do: [:e | failures := failures + 1. e return: nil]].
             done signal] fork].
        8 timesRepeat: [done wait].
        self assert: failures = 0.
        seen := Dictionary new.
        240 timesRepeat: [ | m | m := beta recv: 5000. seen at: m messageId put: m text].
        self assert: seen size = 240.
        1 to: 8 do: [:t | 1 to: 30 do: [:i |
            self assert: (seen at: 't', t printString, '-m', i printString)
                = ('payload ', t printString, '/', i printString)]].
        self expect: -4 in: [beta recv: 200]
    ]
]

PolycallTestCase subclass: PolycallInteropTest [
    | dir serveNode cEp |
    <category: 'Polycall-Tests'>

    setUp [
        dir := self support newTempDir.
        self support shell: self support cliCommand, ' peer serve --node-id cnode --endpoint 127.0.0.1:0',
            ' --endpoint-file ', dir, '/cnode.ep > ', dir, '/cnode.log 2>&1 & echo $! > ', dir, '/cnode.pid'.
        cEp := self support waitForFile: dir, '/cnode.ep'.
        serveNode := PolycallPeer open: 'stnode' bind: '127.0.0.1:0' token: self support token
    ]

    tearDown [
        serveNode isClosed ifFalse: [serveNode close].
        self support shell: 'kill $(cat ', dir, '/cnode.pid) 2>/dev/null'
    ]

    testSmalltalkAndCCliPeersExchangeBothDirections [
        | toC out rc toSt m |
        self assert: cEp notNil.
        serveNode register: 'cnode' endpoint: cEp.
        self assert: (serveNode ping: 'cnode' timeout: 2000) = 0.
        "Smalltalk -> C: UTF-8 bytes plus embedded NULs, verified by `polycall peer recv`"
        toC := 'héllo from smalltalk 🌍' asByteArray, #[0 1 2 0 255].
        serveNode send: toC to: 'cnode' id: 's2c-1' timeout: 3000.
        rc := self support shell: self support cliCommand, ' peer recv --to ', cEp, ' -t 3000 > ',
            dir, '/recv.out 2>&1'.
        out := self support read: dir, '/recv.out'.
        self assert: rc = 0.
        self assert: (self support json: out at: 'from') = 'stnode'.
        self assert: (self support json: out at: 'id') = 's2c-1'.
        self assert: (self support base64Decode: (self support json: out at: 'payload_b64')) = toC.
        "C -> Smalltalk: binary file through `polycall peer send`"
        toSt := ByteArray new: 300.
        1 to: 300 do: [:i | toSt at: i put: (i - 1) \\ 256].
        self support write: toSt asString to: dir, '/c2s.bin'.
        rc := self support shell: self support cliCommand, ' peer send --from cnode --to ',
            serveNode endpoint, ' --id c2s-1 --payload-file ', dir, '/c2s.bin > /dev/null 2>&1'.
        self assert: rc = 0.
        m := serveNode recv: 3000.
        self assert: m sender = 'cnode'.
        self assert: m messageId = 'c2s-1'.
        self assert: m payload = toSt.
        "C -> Smalltalk UTF-8 text"
        rc := self support shell: self support cliCommand, ' peer send --from cnode --to ',
            serveNode endpoint, ' --id c2s-2 --payload ''世界 from C'' > /dev/null 2>&1'.
        self assert: rc = 0.
        m := serveNode recv: 3000.
        self assert: m text = '世界 from C'.
        self assert: m messageId = 'c2s-2'.
        "a CLI sender with the wrong token is rejected (exit 7) and nothing is queued"
        rc := self support shell: (self support cliWithToken: 'wrong-token'), ' peer send --from mallory --to ',
            serveNode endpoint, ' --payload x > /dev/null 2>&1'.
        self assert: rc = 7.
        self expect: -4 in: [serveNode recv: 200]
    ]

    testConcurrentCliSendersToSmalltalkPeer [
        "12 concurrent `polycall peer send` processes; the core's listener
         threads store them while the VM waits for the shell."
        | rc got |
        rc := self support shell: 'for i in 0 1 2 3 4 5 6 7 8 9 10 11; do ', self support cliCommand,
            ' peer send --from csender$i --to ', serveNode endpoint,
            ' --id cc-$i --payload n$i > /dev/null 2>&1 & done; wait'.
        self assert: rc = 0.
        got := Dictionary new.
        12 timesRepeat: [ | m | m := serveNode recv: 5000. got at: m messageId put: m sender, ':', m text].
        0 to: 11 do: [:i |
            self assert: (got at: 'cc-', i printString) = ('csender', i printString, ':n', i printString)]
    ]
]
