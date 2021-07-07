{ GDlib PCX file load/save support
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDPCX;

interface

uses GDGfx;

type
  PCXResult = (PCXNotFound, PCXIOError, PCXBadFile, PCXOk);

function LoadPCXTo(const filename: string; pal: PPalette; dest: pointer; bytesPerLine: word) : PCXResult;
function LoadPCXToBitmap(const filename: string; pal: PPalette; bmp: PBitmap) : PCXResult;
function LoadPCX(const filename: string; pal: PPalette) : PCXResult;
function SavePCXFrom(const filename: string; pal: PPalette; src: pointer; srcWidth, srcHeight: word) : PCXResult;
function SavePCXFromBitmap(const filename: string; pal: PPalette; const bmp: PBitmap) : PCXResult;
function SavePCX(const filename: string; pal: PPalette) : PCXResult;

implementation

uses Toolbox;

type
  PCXHeader = record
    Manufacturer    : byte;
    Version         : byte;
    Encoding        : byte;
    Bpp             : byte;
    X, Y            : word;
    Width, Height   : word;
    HorizontalDpi   : word;
    VerticalDpi     : word;
    EgaPalette      : array[0..47] of byte;
    Reserved        : byte;
    NumColorPlanes  : byte;
    BytesPerLine    : word;
    PaletteType     : word;
    HorizontalSize  : word;
    VerticalSize    : word;
    Padding         : array[0..53] of byte;
  end;

function LoadPCXTo(const filename: string;
                   pal: PPalette;
                   dest: pointer;
                   bytesPerLine: word) : PCXResult;
{ loads a PCX file, storing the loaded pixel data at the pointer given. if
  a palette is provided, the palette data from the PCX file will also be
  loaded. returns PCXOk if successful. }
var
  p              : ^byte;
  linePtrInc     : word;
  f              : file;
  header         : PCXHeader;
  i, count, x, y : integer;
  pcxWidth       : integer;
  pcxHeight      : integer;
  data           : byte;
label ioError;
begin
  Assign(f, filename);

  Reset(f, 1);
  if IOResult <> 0 then begin
    Close(f);
    x := IOResult;  { clear i/o error flag }
    LoadPCXTo := PCXNotFound;
    exit;
  end;

  { read PCX header }
  BlockRead(f, header, SizeOf(PCXHeader));
  if IOResult <> 0 then goto ioError;

  { validate header. we only support about 256 color PCX files }
  if (header.Manufacturer <> 10)
      or (header.Version <> 5)
      or (header.Encoding <> 1)
      or (header.Bpp <> 8) then begin
    Close(f);
    LoadPCXTo := PCXBadFile;
    exit;
  end;

  pcxWidth   := header.Width;
  pcxHeight  := header.Height;
  p          := dest;
  linePtrInc := (bytesPerLine - pcxWidth - 1);

  for y := 0 to pcxHeight do begin
    { write pixels out per-scanline }
    x := 0;
    while x < header.BytesPerLine do begin
      { read pixel (or RLE count ...) }
      BlockRead(f, data, 1);
      if IOResult <> 0 then goto ioError;

      if (data and $c0) = $c0 then begin
        { it was an RLE count, actual pixel is the next byte ... }
        count := data and $3f;
        BlockRead(f, data, 1);
        if IOResult <> 0 then goto ioError;
      end else begin
        count := 1;
      end;

      { store this pixel color the specified number of times }
      while count > 0 do begin
        if x <= pcxWidth then
          p^ := data;

        inc(p);
        inc(x);
        dec(count);
      end;
    end;

    inc(p, linePtrInc);
  end;

  { read palette, if needed }
  if pal <> nil then begin
    Seek(f, FileSize(f) - 768);

    BlockRead(f, pal^, SizeOf(Palette));
    if IOResult <> 0 then goto ioError;

    { convert PCX palette format to VGA RGB format }
    for i := 0 to 255 do begin
      pal^[i, 0] := pal^[i, 0] shr 2;
      pal^[i, 1] := pal^[i, 1] shr 2;
      pal^[i, 2] := pal^[i, 2] shr 2;
    end;
  end;

  Close(f);
  x := IOResult;  { clear i/o error flag (just in case) }
  LoadPCXTo := PCXOk;
  exit;

ioError:
  Close(f);
  x := IOResult;  { clear i/o error flag }
  LoadPCXTo := PCXIOError;
end;

function LoadPCXToBitmap(const filename: string;
                         pal: PPalette;
                         bmp: PBitmap) : PCXResult;
{ loads a PCX file onto the given bitmap. the destination bitmap should be
  pre-allocated to a size sufficient to hold the PCX file being loaded. if a
  palette is provided, the palette data from the PCX file will also be
  loaded. returns PCXOk if successful. }
var
  dest : pointer;
begin
  dest := @bmp^.Pixels;
  LoadPCXToBitmap := LoadPCXTo(filename, pal, dest, bmp^.Width);
end;

function LoadPCX(const filename: string;
                 pal: PPalette) : PCXResult;
{ loads a PCX file onto the currently bound layer. the PCX file being loaded
  should not contain an image larger then 320x200. if a palette is provided,
  the palette data from the PCX file will also be loaded. returns PCXOk if
  successful. }
var
  dest : pointer;
begin
  dest := ptr(GetBoundLayerSegment, GetBoundLayerOffset);
  LoadPCX := LoadPCXTo(filename, pal, dest, SCREEN_WIDTH);
end;

function WritePCXData(var f: file;
                      const runCount: integer;
                      pixel: byte) : boolean;
var
  data : byte;
begin
  WritePCXData := true;

  if (runCount > 1) or ((pixel and $c0) = $c0) then begin
    data := $c0 or runCount;
    BlockWrite(f, data, 1);
    if IOResult <> 0 then begin
      WritePCXData := false;
      exit;
    end;
  end;

  BlockWrite(f, pixel, 1);
  if IOResult <> 0 then begin
    WritePCXData := false;
    exit;
  end;
end;

function SavePCXFrom(const filename: string;
                     pal: PPalette;
                     src: pointer;
                     srcWidth, srcHeight: word) : PCXResult;
{ saves the pixel data located at the given pointer (with the given
  dimensions) to a PCX file. if a palette is provided, that palette is saved
  to the file, otherwise the current VGA palette is saved instead. returns
  PCXOk if successful. }
var
  p                 : ^byte;
  linePtrInc        : word;
  f                 : file;
  x, y, runCount, i : integer;
  pixel, runPixel   : byte;
  rgb               : array[0..2] of byte;
  header            : PCXHeader;
  srcRight          : word;
  srcBottom         : word;
label ioError;
begin
  Assign(f, filename);

  Rewrite(f, 1);
  if IOResult <> 0 then goto ioError;

  srcRight := srcWidth - 1;
  srcBottom := srcHeight - 1;

  MemFill(@header, 0, SizeOf(PCXHeader));
  header.Manufacturer   := 10;
  header.Version        := 5;
  header.Encoding       := 1;
  header.Bpp            := 8;
  header.X              := 0;
  header.Y              := 0;
  header.Width          := srcRight;
  header.Height         := srcBottom;
  header.HorizontalDpi  := 0;
  header.VerticalDpi    := 0;
  header.NumColorPlanes := 1;
  header.BytesPerLine   := srcWidth;
  header.PaletteType    := 1;
  header.HorizontalSize := 320;
  header.VerticalSize   := 200;

  BlockWrite(f, header, SizeOf(PCXHeader));
  if IOResult <> 0 then goto ioError;

  { write image data }
  p := src;
  i := 0;

  for y := 0 to srcBottom do begin
    { write one scanline at a time. breaking runs that could have continued
      across scanlines in the process, as per the pcx standard }
    runCount := 0;
    runPixel := 0;
    for x := 0 to srcRight do begin
      pixel := p^;
      inc(p);

      if runCount = 0 then begin
        runCount := 1;
        runPixel := pixel;

      end else begin
        if (pixel <> runPixel) or (runCount >= 63) then begin
          if (not WritePCXData(f, runCount, runPixel)) then goto ioError;

          runCount := 1;
          runPixel := pixel;

        end else begin
          inc(runCount);
        end;
      end;
    end;

    { end the scanline, writing out whatever run we might have had going }
    if (not WritePCXData(f, runCount, runPixel)) then
      goto ioError;
  end;

  pixel := 12;
  BlockWrite(f, pixel, 1);
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

  Close(f);
  x := IOResult;  { clear i/o error flag (just in case) }
  SavePCXFrom := PCXOk;
  exit;

ioError:
  Close(f);
  x := IOResult;  { clear i/o error flag }
  SavePCXFrom := PCXIOError;
end;

function SavePCXFromBitmap(const filename: string;
                           pal: PPalette;
                           const bmp: PBitmap) : PCXResult;
{ saves the specified bitmap to a PCX file. if a palette is provided, that
  palette is saved to the file, otherwise the current VGA palette is saved
  instead. returns PCXOk if successful. }
var
  src : pointer;
begin
  src := @bmp^.Pixels;
  SavePCXFromBitmap := SavePCXFrom(filename,
                                   pal,
                                   src,
                                   bmp^.Width,
                                   bmp^.Height);
end;

function SavePCX(const filename: string;
                 pal: PPalette) : PCXResult;
{ saves the currently bound layer to a PCX file. if a palette is provided,
  that palette is saved to the file, otherwise the current VGA palette is
  saved instead. returns PCXOk if successful. }
var
  src : pointer;
begin
  src := ptr(GetBoundLayerSegment, GetBoundLayerOffset);
  SavePCX := SavePCXFrom(filename,
                         pal,
                         src,
                         SCREEN_WIDTH,
                         SCREEN_HEIGHT);
end;

end.
