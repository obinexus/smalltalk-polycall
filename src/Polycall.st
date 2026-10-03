"smalltalk-polycall -- GNU Smalltalk binding of the Polycall binding ABI v1.

 Every call goes straight to the C function of the same name in libpolycall
 through GNU Smalltalk C call-outs declared with the exact signatures of
 polycall.h (int -> #int, uint32_t -> #uInt, size_t -> #uLong on LP64,
 caller-owned buffers -> #byteArrayOut). Nothing here parses configuration or
 talks to the network itself.

 Loading (Polycall class >> load): $POLYCALL_LIBRARY first, then the platform
 name (libpolycall.so.1, libpolycall.1.dylib, polycall.dll / libpolycall.dll).
 Every symbol is resolved up front and bound to the exact address in that
 library; a missing library, a missing symbol (a 1.0 library) or
 polycall_ffi_abi_version() ~= 1 signals PolycallLoadError -- never a crash.

 GNU Smalltalk runs all Smalltalk processes on one OS thread and a C call-out
 blocks the whole VM until it returns. A receive therefore blocks every
 Smalltalk process for up to its timeout; prefer short timeouts or polling
 (timeout 0). cancel/close can only wake a blocked receive from another OS
 thread (e.g. a native thread), not from another Smalltalk process."

Error subclass: PolycallError [
    | status statusName detail output requiredSize |

    <category: 'Polycall-Errors'>
    <comment: 'A failed libpolycall call: status (negative POLYCALL_E_*), statusName
(polycall_strerror), detail (polycall_last_error), output (remote error object of
a failed call) and requiredSize (after POLYCALL_E_TOO_LARGE).'>

    PolycallError class >> status: anInteger [
        "Kept from the original API."
        ^self status: anInteger statusName: (Polycall statusNameIfLoaded: anInteger) detail: ''
    ]

    PolycallError class >> status: anInteger statusName: aName detail: aDetail [
        ^self new
            setStatus: anInteger statusName: aName detail: aDetail;
            yourself
    ]

    setStatus: anInteger statusName: aName detail: aDetail [
        status := anInteger.
        statusName := aName.
        detail := aDetail
    ]

    status [ ^status ]
    status: anInteger [ status := anInteger ]
    statusName [ ^statusName ]
    detail [ ^detail ]
    output [ ^output ]
    output: aString [ output := aString ]
    requiredSize [ ^requiredSize ]
    requiredSize: anInteger [ requiredSize := anInteger ]

    messageText [
        | text |
        text := statusName isNil
            ifTrue: ['libpolycall failed with status ', status printString]
            ifFalse: [statusName, ' [', status printString, ']'].
        (detail notNil and: [detail notEmpty]) ifTrue: [text := text, ': ', detail].
        (output notNil and: [output notEmpty]) ifTrue: [text := text, ' -- ', output].
        ^text
    ]
]

Error subclass: PolycallLoadError [
    | library |

    <category: 'Polycall-Errors'>
    <comment: 'The Polycall library could not be used: missing, without the binding
ABI v1 symbols, or reporting another binding ABI.'>

    library [ ^library ]
    library: aString [ library := aString ]
]

Object subclass: PolycallMessage [
    | sender messageId payload |

    <category: 'Polycall-Core'>
    <comment: 'One message taken from a peer node''s inbox.'>

    PolycallMessage class >> sender: aString messageId: anId payload: aByteArray [
        ^self new setSender: aString messageId: anId payload: aByteArray
    ]

    setSender: aString messageId: anId payload: aByteArray [
        sender := aString.
        messageId := anId.
        payload := aByteArray
    ]

    sender [ ^sender ]
    messageId [ ^messageId ]
    payload [ "exact bytes (ByteArray, may contain NULs)" ^payload ]
    text [ "the payload bytes as a String (UTF-8 bytes stay UTF-8 bytes)" ^payload asString ]

    printOn: aStream [
        aStream nextPutAll: 'a PolycallMessage from '; print: sender;
            nextPutAll: ' id '; print: messageId;
            nextPutAll: ' ('; print: payload size; nextPutAll: ' bytes)'
    ]
]

Object subclass: Polycall [
    <category: 'Polycall-Core'>
    <comment: 'Library-level entry points of the Polycall binding ABI v1.'>

    Polycall class [ | libraryPath loaded | ]

    Polycall class >> requiredAbiVersion [ ^1 ]
    Polycall class >> maxPayload [ "POLYCALL_PEER_MAX_PAYLOAD" ^1048576 ]
    Polycall class >> maxCallOutput [ "POLYCALL_CALL_MAX_OUTPUT" ^1048576 ]
    Polycall class >> waitForever [ "UINT32_MAX" ^4294967295 ]

    Polycall class >> abiSymbols [
        "Every libpolycall function this binding calls."
        ^#('polycall_ffi_abi_version' 'polycall_ffi_version' 'polycall_strerror'
           'polycall_last_error' 'polycall_ffi_run_config' 'polycall_ffi_describe'
           'polycall_call' 'polycall_peer_open' 'polycall_peer_close'
           'polycall_peer_endpoint' 'polycall_peer_node_id' 'polycall_peer_register'
           'polycall_peer_unregister' 'polycall_peer_list' 'polycall_peer_ping'
           'polycall_peer_send' 'polycall_peer_recv' 'polycall_peer_cancel'
           'polycall_peer_health')
    ]

    Polycall class >> defaultLibraryNames [
        "Platform library names, from the GNU target triple of this VM.
         (String>>includesSubstring: does not exist in GNU Smalltalk 3.2.)"
        | host has |
        host := Smalltalk hostSystem asLowercase.
        has := [:part | (host indexOfSubCollection: part) > 0].
        ((has value: 'mingw') or: [(has value: 'cygwin') or: [has value: 'windows']])
            ifTrue: [^#('polycall.dll' 'libpolycall.dll')].
        ((has value: 'darwin') or: [has value: 'apple'])
            ifTrue: [^#('libpolycall.1.dylib')].
        ^#('libpolycall.so.1')
    ]

    Polycall class >> load [
        "Load libpolycall: $POLYCALL_LIBRARY, else the platform name. Answer its path."
        | explicit problems |
        explicit := Smalltalk getenv: 'POLYCALL_LIBRARY'.
        (explicit notNil and: [explicit notEmpty]) ifTrue: [^self loadLibrary: explicit].
        problems := WriteStream on: String new.
        self defaultLibraryNames do: [:each |
            [^self loadLibrary: each]
                on: PolycallLoadError
                do: [:e | problems nextPutAll: e messageText; nextPutAll: '; '. e return: nil]].
        ^PolycallLoadError new library: self defaultLibraryNames first;
            signal: problems contents, 'set POLYCALL_LIBRARY to the libpolycall path'
    ]

    Polycall class >> loadLibrary: aPath [
        "Load aPath (libpolycall, or a library linked against it such as the
         smalltalk_polycall shim), resolve every ABI v1 symbol in it, check
         polycall_ffi_abi_version() = 1, then bind the call-outs to exactly
         those addresses. Signals PolycallLoadError on any problem."
        | handle addresses missing abi |
        loaded := false.
        handle := DLD linkFile: aPath.
        handle isNil ifTrue: [
            ^PolycallLoadError new library: aPath;
                signal: 'cannot load the Polycall library ', aPath printString,
                    ' (not found or not loadable; set POLYCALL_LIBRARY)'].
        addresses := LookupTable new.
        missing := OrderedCollection new.
        self abiSymbols do: [:symbol | | address |
            address := DLD library: handle getFunc: symbol.
            address isNil
                ifTrue: [missing add: symbol]
                ifFalse: [addresses at: symbol put: address]].
        missing isEmpty ifFalse: [
            ^PolycallLoadError new library: aPath;
                signal: aPath printString, ' lacks binding ABI v1 symbols ',
                    (missing inject: '' into: [:acc :each |
                        acc isEmpty ifTrue: [each] ifFalse: [acc, ', ', each]]),
                    ' (a Polycall 1.0 library? smalltalk-polycall needs polycall >= 1.1.0)'].
        DLD defineCFunc: 'polycall_ffi_abi_version' as: (addresses at: 'polycall_ffi_abi_version').
        abi := self primAbiVersion.
        abi = self requiredAbiVersion ifFalse: [
            ^PolycallLoadError new library: aPath;
                signal: 'binding ABI mismatch: ', aPath printString, ' implements binding ABI ',
                    abi printString, '; smalltalk-polycall requires binding ABI ',
                    self requiredAbiVersion printString].
        addresses keysAndValuesDo: [:symbol :address | DLD defineCFunc: symbol as: address].
        libraryPath := aPath.
        loaded := true.
        ^aPath
    ]

    Polycall class >> isLoaded [ ^loaded == true ]
    Polycall class >> libraryPath [ ^libraryPath ]
    Polycall class >> ensureLoaded [ self isLoaded ifFalse: [self load] ]

    "---- call-outs (exact polycall.h signatures) ----"

    Polycall class >> primAbiVersion [ <cCall: 'polycall_ffi_abi_version' returning: #int args: #()> ]
    Polycall class >> primVersion: buf len: len [ <cCall: 'polycall_ffi_version' returning: #int args: #(#byteArrayOut #int)> ]
    Polycall class >> primStrerror: status [ <cCall: 'polycall_strerror' returning: #string args: #(#int)> ]
    Polycall class >> primLastError: buf cap: cap [ <cCall: 'polycall_last_error' returning: #int args: #(#byteArrayOut #uLong)> ]
    Polycall class >> primRunConfig: path run: run [ <cCall: 'polycall_ffi_run_config' returning: #int args: #(#string #int)> ]
    Polycall class >> primDescribe: path buf: buf len: len [ <cCall: 'polycall_ffi_describe' returning: #int args: #(#string #byteArrayOut #int)> ]
    Polycall class >> primCall: endpoint service: service operation: operation input: input timeout: ms out: out cap: cap len: lenBuf [
        <cCall: 'polycall_call' returning: #int args: #(#string #string #string #string #uInt #byteArrayOut #uLong #byteArrayOut)>
    ]
    Polycall class >> primPeerOpen: nodeId bind: bind token: token out: handleBuf [ <cCall: 'polycall_peer_open' returning: #int args: #(#string #string #string #byteArrayOut)> ]
    Polycall class >> primPeerClose: h [ <cCall: 'polycall_peer_close' returning: #int args: #(#int)> ]
    Polycall class >> primPeerEndpoint: h buf: buf cap: cap [ <cCall: 'polycall_peer_endpoint' returning: #int args: #(#int #byteArrayOut #uLong)> ]
    Polycall class >> primPeerNodeId: h buf: buf cap: cap [ <cCall: 'polycall_peer_node_id' returning: #int args: #(#int #byteArrayOut #uLong)> ]
    Polycall class >> primPeerRegister: h id: peerId endpoint: endpoint [ <cCall: 'polycall_peer_register' returning: #int args: #(#int #string #string)> ]
    Polycall class >> primPeerUnregister: h id: peerId [ <cCall: 'polycall_peer_unregister' returning: #int args: #(#int #string)> ]
    Polycall class >> primPeerList: h buf: buf cap: cap len: lenBuf [ <cCall: 'polycall_peer_list' returning: #int args: #(#int #byteArrayOut #uLong #byteArrayOut)> ]
    Polycall class >> primPeerPing: h peer: peer timeout: ms [ <cCall: 'polycall_peer_ping' returning: #int args: #(#int #string #uInt)> ]
    Polycall class >> primPeerSend: h peer: peer payload: bytes len: len id: messageId timeout: ms [
        <cCall: 'polycall_peer_send' returning: #int args: #(#int #string #byteArray #uLong #string #uInt)>
    ]
    Polycall class >> primPeerRecv: h timeout: ms sender: sender cap: senderCap id: messageId cap: idCap payload: payload cap: payloadCap len: lenBuf [
        <cCall: 'polycall_peer_recv' returning: #int args: #(#int #uInt #byteArrayOut #uLong #byteArrayOut #uLong #byteArrayOut #uLong #byteArrayOut)>
    ]
    Polycall class >> primPeerCancel: h [ <cCall: 'polycall_peer_cancel' returning: #int args: #(#int)> ]
    Polycall class >> primPeerHealth: h buf: buf cap: cap len: lenBuf [ <cCall: 'polycall_peer_health' returning: #int args: #(#int #byteArrayOut #uLong #byteArrayOut)> ]

    "---- helpers ----"

    Polycall class >> string: aByteArray [
        "The NUL-terminated text a call wrote into aByteArray."
        | end |
        end := aByteArray indexOf: 0.
        end = 0 ifTrue: [end := aByteArray size + 1].
        ^(aByteArray copyFrom: 1 to: end - 1) asString
    ]

    Polycall class >> argument: aString named: what [
        "A String the C ABI can carry unchanged (no NUL)."
        aString isString ifFalse: [
            ^self signalBinding: -1 detail: what, ' must be a String'].
        (aString includes: (Character value: 0)) ifTrue: [
            ^self signalBinding: -1 detail: what, ' contains a NUL character'].
        ^aString
    ]

    Polycall class >> optionalArgument: aString named: what [
        aString isNil ifTrue: [^nil].
        ^self argument: aString named: what
    ]

    Polycall class >> timeout: anInteger [
        (anInteger isInteger and: [anInteger between: 0 and: 4294967295]) ifFalse: [
            ^self signalBinding: -1 detail: 'timeout must be an integer 0..4294967295 (ms)'].
        ^anInteger
    ]

    Polycall class >> signalBinding: status detail: aString [
        ^(PolycallError status: status statusName: (self statusName: status) detail: aString) signal
    ]

    Polycall class >> errorFor: status [
        "Call right after the failing call-out (same OS thread, no preemption)."
        ^PolycallError status: status statusName: (self statusName: status) detail: self lastErrorDetail
    ]

    Polycall class >> run: aBlock [
        "Evaluate aBlock (answering a status) and capture the error detail
         without letting another Smalltalk process run in between: the detail
         is per OS thread, and all Smalltalk processes share one."
        | status error |
        [status := aBlock value.
         status = 0 ifFalse: [error := self errorFor: status]] valueWithoutPreemption.
        error isNil ifFalse: [^error signal].
        ^status
    ]

    "---- library ----"

    Polycall class >> abiVersion [ self ensureLoaded. ^self primAbiVersion ]

    Polycall class >> version [
        | buf n |
        self ensureLoaded.
        buf := ByteArray new: 64.
        n := self primVersion: buf len: 64.
        n >= 64 ifTrue: [buf := ByteArray new: n + 1. self primVersion: buf len: n + 1].
        ^self string: buf
    ]

    Polycall class >> checkAbi [
        "Signal PolycallLoadError unless the loaded library implements binding ABI 1."
        self ensureLoaded.
        ^true
    ]

    Polycall class >> statusName: anInteger [ self ensureLoaded. ^self primStrerror: anInteger ]

    Polycall class >> statusNameIfLoaded: anInteger [
        ^self isLoaded ifTrue: [self primStrerror: anInteger] ifFalse: [nil]
    ]

    Polycall class >> lastErrorDetail [
        | buf n |
        self ensureLoaded.
        buf := ByteArray new: 512.
        n := self primLastError: buf cap: 512.
        n >= 512 ifTrue: [buf := ByteArray new: n + 1. self primLastError: buf cap: n + 1].
        ^self string: buf
    ]

    "---- configuration ----"

    Polycall class >> runConfigStatus: configPath [
        "The documented entry point: the exact status of polycall_ffi_run_config(path, 1)."
        ^self runConfigStatus: configPath strict: true
    ]

    Polycall class >> runConfigStatus: configPath strict: aBoolean [
        configPath isString ifFalse: [^self error: 'configPath must be a String'].
        self ensureLoaded.
        self argument: configPath named: 'configPath'.
        ^self primRunConfig: configPath run: (aBoolean ifTrue: [1] ifFalse: [0])
    ]

    Polycall class >> runConfig: configPath [
        "Signal PolycallError (status, name, detail) unless the file is valid for
         running with this build (strict); answer 0."
        ^self runConfig: configPath strict: true
    ]

    Polycall class >> runConfig: configPath strict: aBoolean [
        "Lenient (strict false) validation reports unknown keys as warnings;
         strict validation rejects them and settings this build cannot honour
         (tls_enabled=true -> POLYCALL_E_UNSUPPORTED)."
        configPath isString ifFalse: [^self error: 'configPath must be a String'].
        self ensureLoaded.
        self argument: configPath named: 'configPath'.
        ^self run: [self primRunConfig: configPath run: (aBoolean ifTrue: [1] ifFalse: [0])]
    ]

    Polycall class >> describe: configPath [
        "polycall_ffi_describe: JSON description of a configuration file."
        | cap buf n error |
        self ensureLoaded.
        self argument: configPath named: 'configPath'.
        cap := 4096.
        4 timesRepeat: [
            buf := ByteArray new: cap.
            [n := self primDescribe: configPath buf: buf len: cap.
             n < 0 ifTrue: [error := self errorFor: n]] valueWithoutPreemption.
            error isNil ifFalse: [^error signal].
            n < cap ifTrue: [^self string: buf].
            cap := n + 1].
        ^self signalBinding: -18 detail: 'describe output kept growing'
    ]

    "---- RPC ----"

    Polycall class >> call: endpoint service: service operation: operation input: inputJson timeout: ms [
        ^self call: endpoint service: service operation: operation input: inputJson
            timeout: ms outputCapacity: self maxCallOutput + 1
    ]

    Polycall class >> call: endpoint service: service operation: operation input: inputJson timeout: ms outputCapacity: cap [
        "One polycall_rpc v1 round trip (polycall_call), executed once, never
         retried; answer the output JSON. inputJson nil sends null; ms must be
         1..600000. A failure signals PolycallError whose output is the remote
         error object (when the core supplied one) and whose requiredSize is set
         after POLYCALL_E_TOO_LARGE."
        | out lenBuf status error text |
        self ensureLoaded.
        self argument: endpoint named: 'endpoint'.
        self argument: service named: 'service'.
        self argument: operation named: 'operation'.
        self optionalArgument: inputJson named: 'input JSON'.
        self timeout: ms.
        out := ByteArray new: (cap max: 1).
        lenBuf := ByteArray new: 8.
        [status := self primCall: endpoint service: service operation: operation input: inputJson
                       timeout: ms out: out cap: cap len: lenBuf.
         status = 0 ifFalse: [error := self errorFor: status]] valueWithoutPreemption.
        error isNil ifTrue: [^self string: out].
        text := self string: out.
        (cap > 0 and: [text notEmpty]) ifTrue: [error output: text].
        status = -10 ifTrue: [error requiredSize: (lenBuf ulongAt: 1)].
        ^error signal
    ]
]

Object subclass: PolycallPeer [
    | handle closedByOwner |

    <category: 'Polycall-Core'>
    <comment: 'A Polycall peer node (polycall_peer_*, protocol polycall-peer/1). Its
registry and inbox belong to this node only. #close stops the listener, wakes
blocked receives (POLYCALL_E_CLOSED) and releases the handle; a second #close or
any call after it signals the core''s POLYCALL_E_INVALID_HANDLE. A node that was
never closed is closed exactly once when it is finalized.'>

    PolycallPeer class >> open: nodeId bind: bindEndpoint token: authToken [
        "bindEndpoint '127.0.0.1:0' = ephemeral port, nil = send-only node;
         authToken nil or '' = no authentication."
        | handleBuf |
        Polycall ensureLoaded.
        Polycall argument: nodeId named: 'node id'.
        Polycall optionalArgument: bindEndpoint named: 'bind endpoint'.
        Polycall optionalArgument: authToken named: 'auth token'.
        handleBuf := ByteArray new: 4.
        Polycall run: [Polycall primPeerOpen: nodeId bind: bindEndpoint token: authToken out: handleBuf].
        ^self new setHandle: (handleBuf intAt: 1)
    ]

    PolycallPeer class >> unownedHandle: anInteger [
        "Wrap a raw handle value WITHOUT owning it (never closed by finalization);
         for tests of the core's handle validation."
        ^self new setUnownedHandle: anInteger
    ]

    setHandle: anInteger [
        handle := anInteger.
        closedByOwner := false.
        self addToBeFinalized
    ]

    setUnownedHandle: anInteger [
        handle := anInteger.
        closedByOwner := true
    ]

    finalize [
        closedByOwner ifFalse: [
            closedByOwner := true.
            Polycall primPeerClose: handle]
    ]

    handle [ ^handle ]
    isClosed [ ^closedByOwner ]

    close [
        "polycall_peer_close; a second close signals POLYCALL_E_INVALID_HANDLE."
        closedByOwner ifFalse: [self removeToBeFinalized].
        closedByOwner := true.
        ^Polycall run: [Polycall primPeerClose: handle]
    ]

    endpoint [
        "Bound 'host:port' ('' for a send-only node)."
        | buf |
        buf := ByteArray new: 128.
        Polycall run: [Polycall primPeerEndpoint: handle buf: buf cap: 128].
        ^Polycall string: buf
    ]

    nodeId [
        | buf |
        buf := ByteArray new: 64.
        Polycall run: [Polycall primPeerNodeId: handle buf: buf cap: 64].
        ^Polycall string: buf
    ]

    register: peerId endpoint: anEndpoint [
        "Add or replace peerId -> anEndpoint in THIS node's registry."
        Polycall argument: peerId named: 'peer id'.
        Polycall argument: anEndpoint named: 'endpoint'.
        ^Polycall run: [Polycall primPeerRegister: handle id: peerId endpoint: anEndpoint]
    ]

    unregister: peerId [
        Polycall argument: peerId named: 'peer id'.
        ^Polycall run: [Polycall primPeerUnregister: handle id: peerId]
    ]

    fetchText: aBlock [
        "Outputs with an out_len (list, health): grow on POLYCALL_E_TOO_LARGE."
        | cap buf lenBuf status error |
        cap := 4096.
        6 timesRepeat: [
            buf := ByteArray new: cap.
            lenBuf := ByteArray new: 8.
            error := nil.
            [status := aBlock value: buf value: cap value: lenBuf.
             (status = 0 or: [status = -10]) ifFalse: [error := Polycall errorFor: status]]
                valueWithoutPreemption.
            error isNil ifFalse: [^error signal].
            status = 0 ifTrue: [^Polycall string: buf].
            cap := (cap * 2) max: (lenBuf ulongAt: 1) + 1].
        ^Polycall signalBinding: -18 detail: 'output kept growing'
    ]

    listJson [
        "THIS node's registry as the core's JSON object text."
        ^self fetchText: [:buf :cap :lenBuf | Polycall primPeerList: handle buf: buf cap: cap len: lenBuf]
    ]

    healthJson [
        ^self fetchText: [:buf :cap :lenBuf | Polycall primPeerHealth: handle buf: buf cap: cap len: lenBuf]
    ]

    ping: peer timeout: ms [
        "GET /health of peer (registered id or 'host:port')."
        Polycall argument: peer named: 'peer'.
        Polycall timeout: ms.
        ^Polycall run: [Polycall primPeerPing: handle peer: peer timeout: ms]
    ]

    send: aPayload to: peer id: messageId timeout: ms [
        "Exactly one delivery attempt of aPayload (ByteArray or String bytes,
         at most 1 MiB). 0 means the receiver stored and acknowledged it; on
         POLYCALL_E_TIMEOUT retry with the SAME messageId. messageId nil lets
         the core generate one."
        | bytes |
        bytes := aPayload isString ifTrue: [aPayload asByteArray] ifFalse: [aPayload].
        (bytes isKindOf: ByteArray) ifFalse: [
            ^Polycall signalBinding: -1 detail: 'payload must be a ByteArray or a String'].
        Polycall argument: peer named: 'peer'.
        Polycall optionalArgument: messageId named: 'message id'.
        Polycall timeout: ms.
        ^Polycall run: [Polycall primPeerSend: handle peer: peer payload: bytes len: bytes size
                            id: messageId timeout: ms]
    ]

    recv: ms [
        "Take the oldest message, blocking (the whole VM -- see the class
         comment) for at most ms milliseconds; 0 polls."
        ^self recv: ms capacity: Polycall maxPayload
    ]

    recv: ms capacity: cap [
        "As #recv:, with an explicit payload buffer: a larger next payload
         signals POLYCALL_E_TOO_LARGE (requiredSize set) and stays queued."
        | sender messageId payload lenBuf status error length |
        Polycall timeout: ms.
        sender := ByteArray new: 64.
        messageId := ByteArray new: 64.
        payload := ByteArray new: (cap max: 1).
        lenBuf := ByteArray new: 8.
        [status := Polycall primPeerRecv: handle timeout: ms sender: sender cap: 64
                       id: messageId cap: 64 payload: payload cap: cap len: lenBuf.
         status = 0 ifFalse: [error := Polycall errorFor: status]] valueWithoutPreemption.
        length := lenBuf ulongAt: 1.
        error isNil ifFalse: [
            status = -10 ifTrue: [error requiredSize: length].
            ^error signal].
        ^PolycallMessage
            sender: (Polycall string: sender)
            messageId: (Polycall string: messageId)
            payload: (payload copyFrom: 1 to: length)
    ]

    cancel [
        "Wake every receive currently blocked on this node (POLYCALL_E_CANCELLED)."
        ^Polycall run: [Polycall primPeerCancel: handle]
    ]
]
