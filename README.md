# FORTH-32
32-bit extended memory, still running 16-bit DOS

Stepping stone between 16-bit running under DOS with segmented conventional memory, and full 32-bit Forth requiring a new OS.
Code is still nominally 16-bit but 32-bit FLAT addressing is used together with a proprietory memory manager for most Forth code. However, DOS interface code uses conventional 16-bit real mode segmented data.

