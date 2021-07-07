{ GDlib IFF (LBM, BBM) file load/save support.
  Gered King, 2019 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDIFF;

interface

uses GDGfx;

const IFF_DEFAULT = 0;
const IFF_UNCOMPRESSED = 1;
const IFF_INTERLEAVED = 2;

type
  IFFResult = (IFFNotFound, IFFIOError, IFFBadFile, IFFOk);

function LoadIFFTo(const filename: string; pal: PPalette; dest: pointer; destPitch: word) : IFFResult;
function LoadIFFToBitmap(const filename: string; pal: PPalette; bmp: PBitmap) : IFFResult;
function LoadIFF(const filename: string; pal: PPalette) : IFFResult;
function SaveIFFFrom(const filename: string; pal: PPalette; src: pointer; srcWidth, srcHeight: word; format: byte) : IFFResult;
function SaveIFFFromBitmap(const filename: string; pal: PPalette; const bmp: PBitmap; format: byte) : IFFResult;
function SaveIFF(const filename: string; pal: PPalette; format: byte) : IFFResult;

implementation

uses Toolbox;

const FORM_ID = (ord('F')) or (ord('O') shl 8) or (ord('R') shl 16) or (ord('M') shl 24);
const ILBM_ID = (ord('I')) or (ord('L') shl 8) or (ord('B') shl 16) or (ord('M') shl 24);
const PBM_ID = (ord('P')) or (ord('B') shl 8) or (ord('M') shl 16) or (ord(' ') shl 24);
const BMHD_ID = (ord('B')) or (ord('M') shl 8) or (ord('H') shl 16) or (ord('D') shl 24);
const CMAP_ID = (ord('C')) or (ord('M') shl 8) or (ord('A') shl 16) or (ord('P') shl 24);
const BODY_ID = (ord('B')) or (ord('O') shl 8) or (ord('D') shl 16) or (ord('Y') shl 24);

type
  IFFID = record
    case Integer of
      0: (id: longint);
      1: (ch: array[0..3] of char);
  end;

  FormChunkHeader = record
    ChunkID : IFFID;
    Size    : longint;
    TypeID  : IFFID;
  end;

  SubChunkHeader = record
    ChunkID : IFFID;
    Size    : longint;
  end;

  BMHDChunk = record
    Width        : word;
    Height       : word;
    Left         : word;
    Top          : word;
    Bitplanes    : byte;
    Masking      : byte;
    Compress     : byte;
    Padding      : byte;
    Transparency : word;
    XAspectRatio : byte;
    YAspectRatio : byte;
    PageWidth    : word;
    PageHeight   : word;
  end;

procedure MergeBitplane(plane: integer;
                        src, dest: pointer;
                        rowSize: integer);
{ takes planar pixel data (for the specified plane only) from the source
  pointer and merges into into existing "chunky" pixel data in the
  destination pointer }
var
  data, bitMask       : byte;
  srcArray, destArray : PByteArray;
  x, i                : integer;
begin
  bitMask   := (1 shl plane);
  srcArray  := PByteArray(src);
  destArray := PByteArray(dest);

  for x := 0 to (rowSize-1) do begin
    data := srcArray^[x];
    if (data and 128) > 0 then begin
      i := x * 8;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 64) > 0 then begin
      i := x * 8 + 1;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 32) > 0 then begin
      i := x * 8 + 2;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 16) > 0 then begin
      i := x * 8 + 3;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 8) > 0 then begin
      i := x * 8 + 4;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 4) > 0 then begin
      i := x * 8 + 5;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 2) > 0 then begin
      i := x * 8 + 6;
      destArray^[i] := destArray^[i] or bitMask;
    end;
    if (data and 1) > 0 then begin
      i := x * 8 + 7;
      destArray^[i] := destArray^[i] or bitMask;
    end;
  end;
end;

procedure ExtractBitplane(plane: integer;
                          src, dest: pointer;
                          rowSize: integer);
{ takes "chunky" pixel data from the source pointer, and extracts planar
  pixel data from it, from the specified plane only, storing it at the
  destination pointer }
var
  data, bitMask       : byte;
  srcArray, destArray : PByteArray;
  x, i                : integer;
begin
  bitMask   := (1 shl plane);
  srcArray  := PByteArray(src);
  destArray := PByteArray(dest);

  i := 0;
  for x := 0 to (rowSize-1) do begin
    data := 0;
    if (srcArray^[i] and bitMask) <> 0 then
      data := (data or 128);
    if (srcArray^[i+1] and bitMask) <> 0 then
      data := (data or 64);
    if (srcArray^[i+2] and bitMask) <> 0 then
      data := (data or 32);
    if (srcArray^[i+3] and bitMask) <> 0 then
      data := (data or 16);
    if (srcArray^[i+4] and bitMask) <> 0 then
      data := (data or 8);
    if (srcArray^[i+5] and bitMask) <> 0 then
      data := (data or 4);
    if (srcArray^[i+6] and bitMask) <> 0 then
      data := (data or 2);
    if (srcArray^[i+7] and bitMask) <> 0 then
      data := (data or 1);

    inc(i, 8);
    destArray^[x] := data;
  end;
end;

function LoadBODYPlanar(var f: file;
                        const bmhd: BMHDChunk;
                        dest: pointer;
                        destPitch: word) : boolean;
{ loads an interleaved (planar) ILBM-format BODY chunk. automatically
  handles compressed or uncompressed formats. }
var
  p        : ^byte;
  rowBytes : word;
  i, y     : integer;
  plane    : integer;
  buffer   : array[0..(((SCREEN_WIDTH + 15) shr 4) shl 1)-1] of byte;
label ioError;
begin
  p := dest;
  rowBytes := ((bmhd.Width + 15) shr 4) shl 1;

  for y := 0 to (bmhd.Height-1) do begin
    { planar data is stored for each bitplane in sequence for the scanline.
      that is, ALL of bitplane1, followed by ALL of bitplane2, etc, NOT
      alternating after each pixel. if compression is enabled, it does NOT
      cross bitplane boundaries. each bitplane is compressed individually.
      bitplanes also do NOT cross the scanline boundary. basically, each
      scanline of pixel data, and within that, each of the bitplanes of
      pixel data found in each scanline can all be treated as they are all
      their own self-contained bit of data as far as this loading process
      is concerned (well, except that we merge all of the scanline's
      bitplanes together at the end of each line) }

    { read all the bitplane rows per scanline }
    for plane := 0 to (bmhd.Bitplanes-1) do begin
      if bmhd.Compress = 1 then begin
        { decompress packed line for this bitplane only }
        if (not UnpackBytes(f, @buffer, rowBytes)) then
          goto ioError;

      { or, if not compressed }
      end else begin
        { TODO: check this. maybe rowBytes is wrong. i don't think DP2 or
                GRAFX2 ever output uncompressed interleaved files anyway. }
        { just read all this bitplane's line data in as-is }
        BlockRead(f, buffer[0], rowBytes);
        if IOResult <> 0 then goto ioError;

      end;

      { merge this bitplane data into the final destination. after all of
        the bitplanes have been loaded and merged in this way for this
        scanline, the destination pointer will contain VGA-friendly
        "chunky pixel"-format pixel data. }
      MergeBitplane(plane, @buffer, p, rowBytes);
    end;

    inc(p, destPitch);
  end;

  LoadBODYPlanar := true;
  exit;

ioError:
  LoadBODYPlanar := false;
end;

function LoadBODYChunky(var f: file;
                        const bmhd: BMHDChunk;
                        dest: pointer;
                        destPitch: word) : boolean;
{ loads a PBM-format BODY chunk. reads it in compressed or uncompressed
  format depending on the BMHD chunk provided }
var
  p         : ^byte;
  data      : byte;
  n, x, y   : integer;
  count     : integer;
  rawBuffer : array[0..SCREEN_RIGHT] of byte;
label ioError;
begin
  p := dest;
  for y := 0 to (bmhd.Height-1) do begin
    if bmhd.Compress = 1 then begin
      { for compression-enabled, read row of pixels using PackBits }
      if (not UnpackBytes(f, p, bmhd.Width)) then
        goto ioError;
      inc(p, bmhd.Width + (destPitch - bmhd.Width));

    end else begin
      { for uncompressed, read row of pixels literally }
      x := 0;
      while x < bmhd.Width do begin
        { continously load buffer-size (or less) pixel chunks from this
          scanline and copy to destination as-is }
        count := bmhd.Width - x;
        if count > sizeof(rawBuffer) then
          count := sizeof(rawBuffer);

        BlockRead(f, rawBuffer, count);
        if IOResult <> 0 then goto ioError;

        MemCopy(p, @rawBuffer, count);
        inc(p, count);
        inc(x, count);
      end;
      inc(p, (destPitch - bmhd.Width));
    end;

  end;

  LoadBODYChunky := true;
  exit;

ioError:
  LoadBODYChunky := false;
end;

function LoadIFFTo(const filename: string;
                   pal: PPalette;
                   dest: pointer;
                   destPitch: word) : IFFResult;
{ loads an IFF file, storing the loaded pixel data at the pointer given.
  both compressed and uncompressed files using either planar/interleaved
  (ILBM) or chunky (PBM) pixel formats are supported. if a palette is
  provided, the palette data from the IFF file will also be loaded.
  returns IFFOk if successful. }
var
  f              : file;
  form           : FormChunkHeader;
  header         : SubChunkHeader;
  bmhd           : BMHDChunk;
  i, n           : integer;
  chunkDataPos   : longint;
  result, chunky : boolean;
label ioError;
begin
  Assign(f, filename);

  Reset(f, 1);
  if IOResult <> 0 then begin
    Close(f);
    n := IOResult;  { clear i/o error flag }
    LoadIFFTo := IFFNotFound;
    exit;
  end;

  { read "FORM" chunk header }
  BlockRead(f, form, SizeOf(FormChunkHeader));
  if IOResult <> 0 then goto ioError;
  form.Size := ByteFlipDWord(form.Size);

  { only supporting "ILBM" and "PBM" types }
  if (form.ChunkID.id <> FORM_ID)
      or ((form.TypeID.id <> ILBM_ID)
          and (form.TypeID.id <> PBM_ID)) then begin
    Close(f);
    LoadIFFTo := IFFBadFile;
    exit;
  end;

  chunky := (form.TypeID.id = PBM_ID);

  { chunks can apparently appear in any order, so loop until we've read
    everything that we need.
    the one exception (maybe??) is that "BODY" chunks should normally occur
    before the only other chunks we care about. }
  while (not eof(f)) do begin
    { read next subchunk header }
    BlockRead(f, header, SizeOf(SubChunkHeader));
    if IOResult <> 0 then goto ioError;

    header.Size := ByteFlipDWord(header.Size);
    if (header.Size and 1) = 1 then
      inc(header.Size); { account for padding byte }

    chunkDataPos := FilePos(f);

    { bitmap header chunk }
    if header.ChunkID.id = BMHD_ID then begin
      BlockRead(f, bmhd, SizeOf(BMHDChunk));
      if IOResult <> 0 then goto ioError;

      bmhd.Width        := ByteFlipWord(bmhd.Width);
      bmhd.Height       := ByteFlipWord(bmhd.Height);
      bmhd.Left         := ByteFlipWord(bmhd.Left);
      bmhd.Top          := ByteFlipWord(bmhd.Top);
      bmhd.Transparency := ByteFlipWord(bmhd.Transparency);
      bmhd.PageWidth    := ByteFlipWord(bmhd.PageWidth);
      bmhd.PageHeight   := ByteFlipWord(bmhd.PageHeight);

      { only supporting 8-bit without masking }
      if (bmhd.Bitplanes <> 8)
         or (bmhd.Masking = 1) then begin
        Close(f);
        LoadIFFTo := IFFBadFile;
        exit;
      end;

    { color map (aka palette) chunk }
    end else if header.ChunkID.id = CMAP_ID then begin
      if pal <> nil then begin
        { we're only supporting 256 color palettes }
        if header.Size <> 768 then begin
          Close(f);
          LoadIFFTo := IFFBadFile;
          exit;
        end;

        BlockRead(f, pal^, SizeOf(Palette));
        if IOResult <> 0 then goto ioError;

        { convert from 0-255 RGB to VGA RGB format (0-63) }
        for i := 0 to 255 do begin
          pal^[i, 0] := pal^[i, 0] shr 2;
          pal^[i, 1] := pal^[i, 1] shr 2;
          pal^[i, 2] := pal^[i, 2] shr 2;
        end;
      end;

    { body chunk, where all the magic happens }
    end else if header.ChunkID.id = BODY_ID then begin
      if not chunky then
        result := LoadBODYPlanar(f, bmhd, dest, destPitch)
      else
        result := LoadBODYChunky(f, bmhd, dest, destPitch);

      if not result then goto ioError;
    end;

    { move to start of next chunk }
    Seek(f, chunkDataPos + header.Size);
  end;

  Close(f);
  n := IOResult;  { clear i/o error flag (just in case) }
  LoadIFFTo := IFFOk;
  exit;

ioError:
  Close(f);
  n := IOResult;  { clear i/o error flag }
  LoadIFFTo := IFFIOError;
end;

function LoadIFFToBitmap(const filename: string;
                         pal: PPalette;
                         bmp: PBitmap) : IFFResult;
{ loads an IFF file onto the given bitmap. both compressed and uncompressed
  files using either planar/interleaved (ILBM) or chunky (PBM) pixel formats
  are supported. the destination bitmap should be pre-allocated to a size
  sufficient to hold the IFF file being loaded. if a palette is provided,
  the palette data from the IFF file will also be loaded. returns IFFOk if
  successful. }
var
  dest : pointer;
begin
  dest := @bmp^.Pixels;
  LoadIFFToBitmap := LoadIFFTo(filename, pal, dest, bmp^.Width);
end;

function LoadIFF(const filename: string;
                 pal: PPalette) : IFFResult;
{ loads an IFF file onto the currently bound layer. both compressed and
  uncompressed files using either planar/interleaved (ILBM) or chunky (PBM)
  pixel formats are supported. the IFF file being loaded should not contain
  an image larger then 320x200. if a palette is provided, the palette data
  from the IFF file will also be loaded. returns IFFOk if successful. }
var
  dest : pointer;
begin
  dest := ptr(GetBoundLayerSegment, GetBoundLayerOffset);
  LoadIFF := LoadIFFTo(filename, pal, dest, SCREEN_WIDTH);
end;

function WriteBODYPlanar(var f: file;
                         const bmhd: BMHDChunk;
                         src: pointer;
                         srcPitch: word) : boolean;
{ writes a compressed interleaved (planar) ILBM-format BODY chunk }
var
  p             : ^byte;
  width, height : integer;
  y, plane      : integer;
  rowBytes      : word;
  buffer        : array[0..(((SCREEN_WIDTH + 15) shr 4) shl 1)-1] of byte;
label ioError;
begin
  p        := src;
  width    := ByteFlipWord(bmhd.Width);
  height   := ByteFlipWord(bmhd.Height);
  rowBytes := ((width + 15) shr 4) shl 1;

  for y := 0 to (height-1) do begin
    for plane := 0 to (bmhd.Bitplanes-1) do begin
      ExtractBitplane(plane, p, @buffer, rowBytes);

      if bmhd.Compress = 1 then begin
        { for compression-enabled, write this plane's pixels using PackBits }
        if (not PackBytes(@buffer, f, rowBytes)) then
          goto ioError;
      end else begin
        { TODO: check this. maybe rowBytes is wrong. i don't think DP2 or
                GRAFX2 ever output uncompressed interleaved files anyway. }
        { for uncompressed, write this plane's pixels literally }
        MemCopy(@buffer, p, rowBytes);
        BlockWrite(f, buffer, rowBytes);
        if IOResult <> 0 then goto ioError;
      end;
    end;

    inc(p, width + (srcPitch - width));
  end;

  WriteBODYPlanar := true;
  exit;

ioError:
  WriteBODYPlanar := false;
end;

function WriteBODYChunky(var f: file;
                         const bmhd: BMHDChunk;
                         src: pointer;
                         srcPitch: word) : boolean;
{ writes a PBM-format BODY chunk. writes it in compressed or uncompressed
  format depending on the BMHD chunk provided }
var
  p                : ^byte;
  y, width, height : integer;
  buffer           : array[0..SCREEN_RIGHT] of byte;
label ioError;
begin
  p      := src;
  width  := ByteFlipWord(bmhd.Width);
  height := ByteFlipWord(bmhd.Height);

  for y := 0 to (height-1) do begin
    if bmhd.Compress = 1 then begin
      { for compression-enabled, write row of pixels using PackBits }
      if (not PackBytes(p, f, width)) then
        goto ioError;

    end else begin
      { for uncompressed, write out the row of pixels literally }
      MemCopy(@buffer, p, width);
      BlockWrite(f, buffer, width);
      if IOResult <> 0 then goto ioError;
    end;

    inc(p, width + (srcPitch - width));
  end;

  WriteBODYChunky := true;
  exit;

ioError:
  WriteBODYChunky := false;
end;

function SaveIFFFrom(const filename: string;
                     pal: PPalette;
                     src: pointer;
                     srcWidth, srcHeight: word;
                     format: byte) : IFFResult;
{ saves the pixel data located at the given pointer (with the given
  dimensions) to an IFF file. if a palette is provided, that palette is saved
  to the file, otherwise the current VGA palette is saved instead. returns
  IFFOk if successful. }
var
  f                        : file;
  form                     : FormChunkHeader;
  header                   : SubChunkHeader;
  bmhd                     : BMHDChunk;
  i, n                     : integer;
  b                        : byte;
  fileSizePos              : longint;
  bodySizePos              : longint;
  eofPos                   : longint;
  sizeBuffer               : longint;
  rgb                      : array[0..2] of Color;
  result, compress, chunky : boolean;
label ioError;
begin
  if format = IFF_DEFAULT then begin
    chunky   := true;
    compress := true;
  end else begin
    chunky   := (format and IFF_INTERLEAVED) = 0;
    compress := (format and IFF_UNCOMPRESSED) = 0;
  end;

  Assign(f, filename);

  Rewrite(f, 1);
  if IOResult <> 0 then goto ioError;

  { write IFF "FORM" chunk header }
  form.ChunkID.id := FORM_ID;
  form.Size       := 0;    { will fill this in at the end }
  if chunky then
    form.TypeID.id := PBM_ID
  else
    form.TypeID.id := ILBM_ID;

  { this is the position we need to come back to at the very end, and write
    the final file size to }
  fileSizePos := 4;

  BlockWrite(f, form, SizeOf(FormChunkHeader));
  if IOResult <> 0 then goto ioError;

  { write "BMHD" chunk }
  header.ChunkID.id := BMHD_ID;
  header.Size       := ByteFlipDWord(SizeOf(BMHDChunk));
  BlockWrite(f, header, SizeOf(SubChunkHeader));
  if IOResult <> 0 then goto ioError;

  bmhd.Width        := ByteFlipWord(srcWidth);
  bmhd.Height       := ByteFlipWord(srcHeight);
  bmhd.Left         := 0;
  bmhd.Top          := 0;
  bmhd.Bitplanes    := 8;
  bmhd.Masking      := 0;
  if compress then bmhd.Compress := 1 else bmhd.Compress := 0;
  bmhd.Padding      := 0;
  bmhd.Transparency := 0;
  bmhd.XAspectRatio := 5; { this is what DP2 writes for 320x200. meh. }
  bmhd.YAspectRatio := 6;
  bmhd.PageWidth    := ByteFlipWord(320);
  bmhd.PageHeight   := ByteFlipWord(200);
  BlockWrite(f, bmhd, SizeOf(BMHDChunk));
  if IOResult <> 0 then goto ioError;

  { write "CMAP" chunk }
  header.ChunkID.id := CMAP_ID;
  header.Size       := ByteFlipDWord(768);
  BlockWrite(f, header, SizeOf(SubChunkHeader));
  if IOResult <> 0 then goto ioError;

  { write out provided palette, or the current VGA palette }
  if pal <> nil then begin
    for i := 0 to 255 do begin
      rgb[0] := pal^[i, 0] shl 2;
      rgb[1] := pal^[i, 1] shl 2;
      rgb[2] := pal^[i, 2] shl 2;
      BlockWrite(f, rgb, 3);
      if IOResult <> 0 then goto ioError;
    end;

  end else begin
    for i := 0 to 255 do begin
      GetColor(i, rgb[0], rgb[1], rgb[2]);

      rgb[0] := rgb[0] shl 2;
      rgb[1] := rgb[1] shl 2;
      rgb[2] := rgb[2] shl 2;

      BlockWrite(f, rgb, 3);
      if IOResult <> 0 then goto ioError;
    end;
  end;

  { write "BODY" chunk }
  header.ChunkID.id := BODY_ID;
  header.Size       := 0;   { will come back and write this at the end }

  { save the position we need to come back to, to write the "BODY" chunk
    size at }
  bodySizePos := FilePos(f) + SizeOf(IFFID);

  BlockWrite(f, header, SizeOf(SubChunkHeader));
  if IOResult <> 0 then goto ioError;

  if chunky then
    result := WriteBODYChunky(f, bmhd, src, SCREEN_WIDTH)
  else
    result := WriteBODYPlanar(f, bmhd, src, SCREEN_WIDTH);
  if not result then goto ioError;

  eofPos := FilePos(f);
  { write a chunk body padding byte if needed }
  if (eofPos and 1) = 1 then begin
    b := 0;
    BlockWrite(f, b, 1);
    if IOResult <> 0 then goto ioError;

    inc(eofPos);
  end;

  { "BODY" chunk header size }
  Seek(f, bodySizePos);
  sizeBuffer := ByteFlipDWord((eofPos - bodySizePos - 4));
  BlockWrite(f, sizeBuffer, 4);
  if IOResult <> 0 then goto ioError;

  { IFF "FORM" chunk header size }
  Seek(f, fileSizePos);
  sizeBuffer := ByteFlipDWord(eofPos - 8);
  BlockWrite(f, sizeBuffer, 4);
  if IOResult <> 0 then goto ioError;

  Close(f);
  n := IOResult;  { clear i/o error flag (just in case) }
  SaveIFFFrom := IFFOk;
  exit;

ioError:
  Close(f);
  n := IOResult;  { clear i/o error flag }
  SaveIFFFrom := IFFIOError;
end;

function SaveIFFFromBitmap(const filename: string;
                           pal: PPalette;
                           const bmp: PBitmap;
                           format: byte) : IFFResult;
{ saves the specified bitmap to an IFF file. if a palette is provided, that
  palette is saved to the file, otherwise the current VGA palette is saved
  instead. returns IFFOk if successful. }
var
  src : pointer;
begin
  src := @bmp^.Pixels;
  SaveIFFFromBitmap := SaveIFFFrom(filename,
                                   pal,
                                   src,
                                   bmp^.Width,
                                   bmp^.Height,
                                   format);
end;

function SaveIFF(const filename: string;
                 pal: PPalette;
                 format: byte) : IFFResult;
{ saves the currently bound layer to an IFF file. if a palette is provided,
  that palette is saved to the file, otherwise the current VGA palette is
  saved instead. returns IFFOk if successful. }
var
  src : pointer;
begin
  src := ptr(GetBoundLayerSegment, GetBoundLayerOffset);
  SaveIFF := SaveIFFFrom(filename,
                         pal,
                         src,
                         SCREEN_WIDTH,
                         SCREEN_HEIGHT,
                         format);
end;

end.
