{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Assets;

interface

uses GDGfx, GDIFF, Maps, Shared;

type
  UIFrameBitmaps   = array[0..9] of PBitmap;

var
  pal              : Palette;
  fnt              : Font;
  chunkyFnt        : Font;
  tiles            : array[0..99] of PBitmap;
  sprites          : array[0..99] of PBitmap;

  titleMain        : PBitmap;
  titleSelectLevel : PBitmap;
  titleChooseFruit : PBitmap;
  titleHelp        : PBitmap;
  titleResults     : PBitmap;
  titlePause       : PBitmap;

  uiTomatoFrame    : UIFrameBitmaps;
  uiGrapesFrame    : UIFrameBitmaps;
  uiGeneralFrame   : UIFrameBitmaps;

function LoadTilesAndSprites(filename : string) : boolean;
function LoadImages(filename : string) : boolean;
function LoadMap(filename : string) : boolean;

implementation

uses Toolbox;

function LoadTilesAndSprites(filename : string) : boolean;
var
  i, x, y, offset : integer;
  puiFrame        : ^UIFrameBitmaps;
label return;
begin
  LoadTilesAndSprites := false;

  UseLayer(BACKBUFFER_LAYER);
  if LoadIFF(filename, @pal) <> IFFOk then goto return;

  { environment tiles are on the left }
  offset := 0;
  i      := 0;
  for y := 0 to 9 do begin
    for x := 0 to 9 do begin
      AllocBitmap(16, 16, tiles[i]);
      GrabBitmap((x*16)+offset, y*16, 16, 16, tiles[i]);
      inc(i);
    end;
  end;

  { sprites are on the right }
  offset := 160;
  i      := 0;
  for y := 0 to 9 do begin
    for x := 0 to 9 do begin
      AllocBitmap(16, 16, sprites[i]);
      GrabBitmap((x*16)+offset, y*16, 16, 16, sprites[i]);
      inc(i);
    end;
  end;

  { other things that are not in a uniform 16x16 grid }
  for i := 0 to 2 do begin
    case i of
      0: puiFrame := @uiTomatoFrame;
      1: puiFrame := @uiGrapesFrame;
      2: puiFrame := @uiGeneralFrame;
    end;

    x := i * 48;

    AllocBitmap(16, 16, puiFrame^[0]);
    AllocBitmap(8,  8,  puiFrame^[1]);
    AllocBitmap(16, 16, puiFrame^[2]);
    AllocBitmap(8,  8,  puiFrame^[3]);
    AllocBitmap(8,  8,  puiFrame^[4]);
    AllocBitmap(8,  8,  puiFrame^[5]);
    AllocBitmap(16, 16, puiFrame^[6]);
    AllocBitmap(8,  8,  puiFrame^[7]);
    AllocBitmap(16, 16, puiFrame^[8]);

    GrabBitmap(x+0,  176, 16, 16, puiFrame^[0]);
    GrabBitmap(x+16, 176, 8,  8,  puiFrame^[1]);
    GrabBitmap(x+32, 176, 16, 16, puiFrame^[2]);
    GrabBitmap(x+0,  184, 8,  8,  puiFrame^[3]);
    GrabBitmap(x+8,  184, 8,  8,  puiFrame^[4]);
    GrabBitmap(x+40, 184, 8,  8,  puiFrame^[5]);
    GrabBitmap(x+0,  184, 16, 16, puiFrame^[6]);
    GrabBitmap(x+16, 192, 8,  8,  puiFrame^[7]);
    GrabBitmap(x+32, 184, 16, 16, puiFrame^[8]);
  end;

  LoadTilesAndSprites := true;

return:
  UseLayer(SCREEN_LAYER);
end;

function LoadImages(filename : string) : boolean;
label return;
begin
  LoadImages := false;

  UseLayer(BACKBUFFER_LAYER);
  if LoadIFF(filename, nil) <> IFFOk then goto return;

  AllocBitmap(98, 38, titlePause);
  GrabBitmap(3, 2, 98, 38, titlePause);

  AllocBitmap(124, 39, titleResults);
  GrabBitmap(121, 2, 124, 39, titleResults);

  AllocBitmap(164, 37, titleSelectLevel);
  GrabBitmap(2, 42, 164, 37, titleSelectLevel);

  AllocBitmap(262, 35, titleChooseFruit);
  GrabBitmap(2, 79, 262, 35, titleChooseFruit);

  AllocBitmap(196, 40, titleHelp);
  GrabBitmap(2, 112, 196, 40, titleHelp);

  AllocBitmap(272, 48, titleMain);
  GrabBitmap(2, 150, 272, 48, titleMain);

  LoadImages := true;

return:
  UseLayer(SCREEN_LAYER);
end;

function LoadMap(filename : string) : boolean;
var
  f      : file;
  n      : integer;
  header : array[0..2] of char;
label ioError;
begin
  LoadMap := false;

  Assign(f, filename);

  Reset(f, 1);
  if IOResult <> 0 then begin
    Close(f);
    n := IOResult;  { clear i/o error flag }
    exit;
  end;

  { validate file type by checking for expected header }
  BlockRead(f, header, SizeOf(header));
  if (header[0] <> 'M') or (header[1] <> 'A') or (header[2] <> 'P') then
    goto ioError;

  MemFill(@map, 0, SizeOf(map));
  BlockRead(f, map, SizeOf(map), n);
  if n <> SizeOf(map) then goto ioError;

  isMapDirty := true;
  LoadMap := true;
  Close(f);
  n := IOResult;  { clear i/o error flag }
  exit;

ioError:
  LoadMap := false;
  Close(f);
  n := IOResult;  { clear i/o error flag }
end;


end.
