"Negative control: a 4-byte buffer passed with capacity 128 must be caught by ASan."
Eval [
  | p b |
  Polycall load.
  p := PolycallPeer open: 'ctl' bind: '127.0.0.1:0' token: nil.
  b := ByteArray new: 4.
  Polycall primPeerEndpoint: p handle buf: b cap: 128.
  'control: no ASan report' displayNl.
  p close
]
