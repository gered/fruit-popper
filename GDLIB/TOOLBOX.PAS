{ Miscellaneous helpers and utilities.
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Toolbox;

interface

uses FixedP;

const
  Bit0              = $0001;
  Bit1              = $0002;
  Bit2              = $0004;
  Bit3              = $0008;
  Bit4              = $0010;
  Bit5              = $0020;
  Bit6              = $0040;
  Bit7              = $0080;
  Bit8              = $0100;
  Bit9              = $0200;
  Bit10             = $0400;
  Bit11             = $0800;
  Bit12             = $1000;
  Bit13             = $2000;
  Bit14             = $4000;
  Bit15             = $8000;

  BiosTicksPerSec   = 1000.0 / 55.0;
  BiosTicksPerSecFP = trunc((1000.0 / 55.0) * FP_FLOAT_SHIFT);

type
  { convenience for accessing a byte pointer as an array (cast to this) }
  ByteArray  = array[0..63999] of byte;
  PByteArray = ^ByteArray;
  WordArray  = array[0..31999] of byte;
  PWordArray = ^WordArray;

  { convenient way to go from pointer <-> segment/offset automatically }
  PointerEx = record
    case Integer of
      0: (ptr: Pointer);
      1: (ofs, seg: Word);
  end;

var
  BiosTicks: word absolute $0040:$006c;

function ByteFlipWord(x : word) : word;
function ByteFlipDWord(x : longint) : longint;
function SignInt(x: integer) : integer;
procedure SwapInts(var a, b: integer);
function Max(a, b: integer) : integer;
function Min(a, b: integer) : integer;
function Fequ(a, b: single) : boolean;
function FequX(a, b, tolerance: single) : boolean;
function ClampInt(value, low, high: integer) : integer;
function ClampFloat(value, low, high: single) : single;
function ClampFixed(value, low, high: fixed) : fixed;
function ScaleRange(value, oldMin, oldMax, newMin, newMax: single) : single;
function ScaleRangeFixed(value, oldMin, oldMax, newMin, newMax: fixed) : fixed;
function BiosTimeSeconds : single;
function BiosTimeSecondsFP : fixed;
function PtrSeg(const p: pointer) : word;
function PtrOfs(const p: pointer) : word;
procedure MemCopy(const dest, src: pointer; bytes: word);
procedure MemCopy16(const dest, src: pointer; bytes: word);
procedure MemFill(const dest: pointer; value: byte; bytes: word);
function HashString(const s: string) : word;
function PackBytes(const src: pointer; var dest: file; srcLength: word) : boolean;
function UnpackBytes(var src: file; const dest: pointer; unpackedSize: integer) : boolean;

implementation

function ByteFlipWord(x : word) : word;
{ returns the value with its bytes flipped, changing its endianess }
assembler;
asm
  mov ax, x
  xchg al, ah
end;

function ByteFlipDWord(x : longint) : longint;
{ returns the value with its bytes flipped, changing its endianess }
assembler;
asm
  mov dx, word(x);
  mov ax, word(x+2);
  xchg al, ah
  xchg dl, dh
end;

function SignInt(x: integer) : integer;
{ return 1 if x is positive, -1 if x is negative, or 0 if x is zero. }
assembler;
asm
  mov bx, x

  xor ax, ax
  test bx, bx
  jz @done         { if x == 0, then return 0 }

  mov ax, 1        { assume x is positive (return 1) }
  and bx, 8000h    { check sign bit }
  jz @done         { if sign bit == 0, return 1 (x is positive) }
  mov ax, -1       { x is negative, return -1 }
@done:
end;

procedure SwapInts(var a, b: integer);
{ swaps the values of a and b }
var
  temp: integer;
begin
  temp := a;
  a    := b;
  b    := temp;
end;

function Max(a, b: integer) : integer;
{ returns the highest of the two given integers }
begin
  if b > a then Max := b else Max := a;
end;

function Min(a, b: integer) : integer;
{ returns the lowest of the two given integers }
begin
  if b < a then Min := b else Min := a;
end;

function Fequ(a, b: single) : boolean;
begin
  Fequ := (abs(a - b) <= 0.00005);
end;

function FequX(a, b, tolerance: single) : boolean;
begin
  FequX := (abs(a - b) <= tolerance);
end;

function ClampInt(value, low, high: integer) : integer;
{ returns the given value, clamped to fall within the low-high range. }
begin
  if value < low then
    ClampInt := low
  else if value > high then
    ClampInt := high
  else
    ClampInt := value;
end;

function ClampFloat(value, low, high: single) : single;
{ returns the given value, clamped to fall within the low-high range. }
begin
  if value < low then
    ClampFloat := low
  else if value > high then
    ClampFloat := high
  else
    ClampFloat := value;
end;

function ClampFixed(value, low, high: fixed) : fixed;
{ returns the given value, clamped to fall within the low-high range. }
begin
  if value < low then
    ClampFixed := low
  else if value > high then
    ClampFixed := high
  else
    ClampFixed := value;
end;

function ScaleRange(value, oldMin, oldMax, newMin, newMax: single) : single;
{ takes a value that should be between oldMin and oldMax, and scales it so
  that it is within newMin and newMax at the same relative position within
  the new min/max range }
begin
  ScaleRange := (newMax - newMin) *
                (value - oldMin) /
                (oldMax - oldMin) + newMin;
end;

function ScaleRangeFixed(value, oldMin, oldMax, newMin, newMax: fixed) : fixed;
{ takes a value that should be between oldMin and oldMax, and scales it so
  that it is within newMin and newMax at the same relative position within
  the new min/max range }
begin
  ScaleRangeFixed := FixDiv(
                       FixMul((newMax - newMin), (value - oldMin)),
                       (oldMax - oldMin) + newMin
                     );
end;

function BiosTimeSeconds : single;
{ returns the current bios tick count in seconds (time since midnight) }
begin
  BiosTimeSeconds := BiosTicks / BiosTicksPerSec;
end;

function BiosTimeSecondsFP : fixed;
{ returns the current bios tick count in seconds (time since midnight) }
begin
  BiosTimeSecondsFP := FixDiv(IntToFix(BiosTicks), BiosTicksPerSecFP);
end;

{ TODO: is there some better built-in way to do what the below two functions,
        PtrSeg and PtrOfs, do? ... }

function PtrSeg(const p: pointer) : word;
{ returns the segment portion of the memory address in the given pointer }
assembler;
asm
  mov ax, word [p+2]
end;

function PtrOfs(const p: pointer) : word;
{ returns the offset portion of the memory address in the given pointer }
assembler;
asm
  mov ax, word [p]
end;

procedure MemCopy(const dest, src: pointer;
                  bytes: word);
{ copy specified number of bytes from src to dest. uses a 32-bit copy
  via 'rep movsd' }
assembler;
asm
  push ds

  db $66,$33,$c9   { xor ecx, ecx }
  mov cx, bytes
  les di, dest
  lds si, src

  mov bx, cx
  shr cx, 2        { cx = number of dwords to copy }
  and bx, 3        { bx = number of remainder bytes to copy }

  db $f3,$66,$a5   { rep movsd }
  mov cx, bx
  rep movsb

@done:
  pop ds
end;

procedure MemCopy16(const dest, src: pointer;
                    bytes: word);
{ copy specified number of bytes from src to dest. uses 16-bit copy
  via 'rep movsw' }
assembler;
asm
  push ds

  xor cx, cx
  mov cx, bytes
  les di, dest
  lds si, src

  mov bx, cx
  shr cx, 1        { cx = number of words to copy }
  and bx, 1        { bx = number of remainder bytes to copy }

  rep movsw
  mov cx, bx
  rep movsb

@done:
  pop ds
end;

procedure MemFill(const dest: pointer;
                  value: byte;
                  bytes: word);
{ fill the specified length of memory starting at dest with the given value }
assembler;
asm
  db $66,$33,$c9   { xor ecx, ecx }
  mov cx, bytes
  mov al, value
  les di, dest

  mov ah, al       { set all bytes of eax with value to fill with }
  db $66           { shl ax => shl eax }
  shl ax, 8
  mov al, ah
  db $66           { shl ax => shl eax }
  shl ax, 8
  mov al, ah

  mov bx, cx
  shr cx, 2        { cx = number of dwords to set }
  and bx, 3        { bx = number of remainder bytes to set }

  db $f3,$66,$ab   { rep stosd }
  mov cx, bx
  rep stosb
end;

function HashString(const s: string) : word;
{ computes the hash of a string, using the djb2 algorithm }
var
  hash      : word;
  i, c, len : integer;
begin
  len := length(s);
  for i := 1 to len do begin
    c    := ord(s[i]);
    hash := ((hash shl 5) + hash) + c;
  end;
  HashString := hash;
end;

function PackBytes(const src: pointer;
                   var dest: file;
                   srcLength: word) : boolean;
{ packs the bytes located at the given pointer using the PackBits algorithm.
  the packed output is written to the destination file as it is being
  packed. srcLength is the size of the unpacked (original) data. packing
  (and writing to the file) will stop once that many bytes have been read
  from the source pointer. returns true on success, or false if there was
  an IO error. assumes that the record size for the file being written is
  set to 1.
  this routine is based on PACKBITS.C from the Animator-Pro sources. }
const
  MIN_RUN    = 3;
  MAX_RUN    = 128;
  MAX_BUFFER = 128;
type
  PackMode = (PackDump, PackRun);
var
  srcBytes    : ^byte;
  b, lastb    : byte;
  n, runStart : integer;
  buffer      : array[0..((MAX_RUN*2)-1)] of byte;
  mode        : PackMode;
  fdata       : byte;
label ioError;
begin
  srcBytes   := src;

  mode       := PackDump;
  runStart   := 0;

  { read initial source byte to start things off }
  lastb      := srcBytes^;
  buffer[0]  := lastb;
  inc(srcBytes);
  n          := 1;
  dec(srcLength);

  while srcLength > 0 do begin
    { read next byte, add it to the temp buffer }
    b := srcBytes^;
    inc(srcBytes);
    buffer[n] := b;
    inc(n);

    if mode = PackDump then begin
      { check if we need to flush the temp buffer to the file }
      if n > MAX_BUFFER then begin
        fdata := n - 2;
        BlockWrite(dest, fdata, 1);
        if IOResult <> 0 then goto ioError;
        BlockWrite(dest, buffer, n-1);
        if IOResult <> 0 then goto ioError;

        buffer[0] := b;
        n := 1;
        runStart := 0;

      { detect the start of a run of identical bytes }
      end else if b = lastb then begin
        if (n - runStart) >= MIN_RUN then begin
          if runStart > 0 then begin
            { we've found a run, flush the buffer we have currently and then
              switch to "run" mode }
            fdata := runStart - 1;
            BlockWrite(dest, fdata, 1);
            if IOResult <> 0 then goto ioError;
            BlockWrite(dest, buffer, runStart);
            if IOResult <> 0 then goto ioError;
          end;
          mode := PackRun;
        end else if runStart = 0 then begin
          mode := PackRun;
        end;
      end else begin
        runStart := n-1;
      end;

    end else begin
      { detect the end of a run of identical bytes }
      if (b <> lastb) or ((n - runStart) > MAX_RUN) then begin
        { the identical byte run has ended, write it to the file
          (just two bytes, the count and the actual byte) }
        fdata := -(n - runStart - 2);
        BlockWrite(dest, fdata, 1);
        if IOResult <> 0 then goto ioError;
        fdata := lastb;
        BlockWrite(dest, fdata, 1);
        if IOResult <> 0 then goto ioError;

        { clear the temp buffer for our switch back to "dump" mode }
        buffer[0] := b;
        n := 1;
        runStart := 0;
        mode := PackDump;
      end;
    end;
    lastb := b;

    dec(srcLength);
  end;

  { the source bytes have all been read, but we still might have to
    flush our temp buffer or finish writing out a run of identical bytes }
  if mode = PackDump then begin
    fdata := n - 1;
    BlockWrite(dest, fdata, 1);
    if IOResult <> 0 then goto ioError;
    BlockWrite(dest, buffer, n);
    if IOResult <> 0 then goto ioError;
  end else begin
    fdata := -(n - runStart - 1);
    BlockWrite(dest, fdata, 1);
    if IOResult <> 0 then goto ioError;
    fdata := lastb;
    BlockWrite(dest, fdata, 1);
    if IOResult <> 0 then goto ioError;
  end;

  n := IOResult;  { clear i/o error flag }
  PackBytes := true;
  exit;

ioError:
  n := IOResult;  { clear i/o error flag }
  PackBytes := false;
end;

function UnpackBytes(var src: file;
                     const dest: pointer;
                     unpackedSize: integer) : boolean;
{ unpacks a stream of bytes from a file into the destination buffer using
  the PackBits algorithm. unpackedSize is the expected size of the
  unpacked data, reading/unpacking will stop once this many bytes have been
  written to the destination buffer. this function assumes that the file
  will contain this much data and will not reach EOF before then. returns
  true on success, or false if there was an IO error.
  assumes that the record size for the file being read is 1.
  this routine is based on PACKBITS.C from the Animator-Pro sources. }
var
  destBytes        : ^byte;
  size, n          : integer;
  fdata, runLength : byte;
label ioError;
begin
  destBytes  := dest;
  size := 0;

  while size < unpackedSize do begin
    { read next "code" byte (run-length byte) that determines how to process
      the subsequent bytes }
    BlockRead(src, runLength, 1);
    if IOResult <> 0 then goto ioError;

    { 129-255 = repeat next byte in file 257-n times }
    if runLength > 128 then begin
      runLength := 257 - runLength;

      { read the next byte and repeat it }
      BlockRead(src, fdata, 1);
      if IOResult <> 0 then goto ioError;
      MemFill(destBytes, fdata, runLength);

      inc(destBytes, runLength);
      inc(size, runLength);

    { 0-128 = copy next n-1 bytes in file as-is }
    end else if runLength < 128 then begin
      inc(runLength);

      { read next set of bytes directly into destination buffer }
      BlockRead(src, destBytes^, runLength);
      if IOResult <> 0 then goto ioError;

      inc(destBytes, runLength);
      inc(size, runLength);
    end;

    { 128 = no-op (does this even ever appear in any files??) }
  end;

  n := IOResult;  { clear i/o error flag }
  UnpackBytes := true;
  exit;

ioError:
  n := IOResult;  { clear i/o error flag }
  UnpackBytes := false;
end;

begin
  if Test8086 < 2 then begin
    writeln('Toolbox unit requires a 386 cpu or higher!');
    halt;
  end;
end.
