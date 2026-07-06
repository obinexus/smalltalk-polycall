"Load src/Polycall.st first, then run this file from the project root."

Polycall loadLibrary: 'dist/smalltalk_polycall'.
Transcript
    show: 'libpolycall status: ';
    show: (Polycall runConfigStatus: 'smalltalk-polycallrc') printString;
    nl.
