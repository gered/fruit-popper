{ GDlib Core VGA mode 13h Graphics routines
  Gered King, 2018-2021 }

{
  TODO list:
  - palette loading/saving to binary .pal files
  - custom font support, including variable-width fonts
  - allowing usage of EMS memory to have extra gfx layers located in EMS
  - clip-region stack, with push/pop type api
  - blit sprite routine that allows blitting all non-transparent colours
    using a single specified solid colour (e.g. for sprite flashing effect)
  - translucent/blending colour table mapping and drawing routines
  - scaled/rotated blit routines ... ?
}

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDGfx;

interface

const
  MAX_LAYERS                 = 5;
  MAX_EXTRA_LAYERS           = 5;
  SCREEN_LAYER               = 0;

  SCREEN_LEFT                = 0;
  SCREEN_TOP                 = 0;
  SCREEN_RIGHT               = 319;
  SCREEN_BOTTOM              = 199;
  SCREEN_WIDTH               = 320;
  SCREEN_HEIGHT              = 200;

  CHAR_WIDTH                 = 8;
  CHAR_HEIGHT                = 8;

  LAYERFLAG_ALIASEDMEM       = $1;

  ClipRegionLeft             : integer = SCREEN_LEFT;
  ClipRegionTop              : integer = SCREEN_TOP;
  ClipRegionRight            : integer = SCREEN_RIGHT;
  ClipRegionBottom           : integer = SCREEN_BOTTOM;
  ClipRegionWidth            : integer = SCREEN_WIDTH;
  ClipRegionHeight           : integer = SCREEN_HEIGHT;

type
  Color                      = byte;
  PColor                     = ^Color;

  PalResult = (PalNotFound, PalIOError, PalBadFile, PalBadArgs, PalOk);

  Palette                    = array[0..255,0..2] of byte;
  PaletteEntry               = array[0..2] of byte;
  PPalette                   = ^Palette;
  PPaletteEntry              = ^PaletteEntry;

  Pixelbuffer                = array[0..63999] of Color;
  PPixelbuffer               = ^Pixelbuffer;

  BiosFontTable              = array[0..255,0..7] of byte;
  BiosFontChar               = array[0..7] of byte;
  BiosFontCharWidths         = array[0..255] of byte;
  PBiosFontChar              = ^BiosFontChar;

  FontResult = (FontNotFound, FontIOError, FontBadFile, FontBadArgs, FontOk);

  Font = record
    chars  : BiosFontTable;
    widths : BiosFontCharWidths;
    height : byte;
  end;
  PFont                      = ^Font;

  Bitmap = record
    Width, Height : word;
    Pixels        : byte;    { take pointer of this to get full pixels mem }
  end;
  PBitmap                    = ^Bitmap;

var
  VgaFramebuffer             : Pixelbuffer absolute $a000:$0000;

procedure InitGraphics(layers: integer);
procedure CloseGraphics;
function IsGraphicsInitialized: boolean;
procedure UseLayer(layer: integer);
procedure Cls(color: Color);
procedure Flip(layer: integer);
procedure CopyLayer(layer: integer);
procedure WaitForVsync;
function GetBoundLayerIndex : integer;
function GetBoundLayerSegment : word;
function GetBoundLayerOffset : word;
function GetBoundLayerOffsetAt(x, y: integer) : word;
function GetBoundLayerPointerAt(x, y: integer) : pointer;
procedure SetClipRegion(x1, y1, x2, y2: integer);
procedure ResetClipRegion;
procedure Pset(x, y: integer; color: Color);
procedure Psetf(x, y: integer; color: Color);
function Pget(x, y: integer) : Color;
function Pgetf(x, y: integer) : Color;
procedure Line(x1, y1, x2, y2: integer; color: Color);
procedure Linef(x1, y1, x2, y2: integer; color: Color);
procedure HLine(x1, x2, y: integer; color: Color);
procedure HLinef(x1, x2, y: integer; color: Color);
procedure VLine(x, y1, y2: integer; color: Color);
procedure VLinef(x, y1, y2: integer; color: Color);
procedure Box(x1, y1, x2, y2: integer; color: Color);
procedure Boxf(x1, y1, x2, y2: integer; color: Color);
procedure FilledBox(x1, y1, x2, y2: integer; color: Color);
procedure FilledBoxf(x1, y1, x2, y2: integer; color: Color);
procedure UseFont(font : PFont);
procedure DrawSubString(x, y: integer; color: Color; const text: string; textStart, textEnd: integer);
procedure DrawString(x, y: integer; color: Color; const text: string);
procedure DrawStringf(x, y: integer; color: Color; const text: string);
procedure PrintAt(x, y: integer);
procedure PrintShortInt(value: shortint; color: Color);
procedure PrintInt(value: integer; color: Color);
procedure PrintLongInt(value: longint; color: Color);
procedure PrintByte(value: byte; color: Color);
procedure PrintWord(value: word; color: Color);
procedure PrintReal(value: real; color: Color);
procedure PrintRealFmt(value: real; decimals: integer; color: Color);
procedure PrintSingle(value: single; color: Color);
procedure PrintSingleFmt(value: single; decimals: integer; color: Color);
procedure PrintDouble(value: double; color: Color);
procedure PrintDoubleFmt(value: double; decimals: integer; color: Color);
procedure PrintString(const text: string; color: Color);
procedure AllocBitmap(width, height: word; var bmp: PBitmap);
procedure FreeBitmap(bmp: PBitmap);
procedure GrabBitmap(x, y: integer; width, height: word; bmp: PBitmap);
procedure BlitSubset(srcX, srcY, srcWidth, srcHeight, destX, destY: integer; const bmp: PBitmap);
procedure BlitSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY: integer; const bmp: PBitmap);
procedure Blit(x, y: integer; const bmp: PBitmap);
procedure Blitf(x, y: integer; const bmp: PBitmap);
procedure BlitSpriteSubset(srcX, srcY, srcWidth, srcHeight, destX, destY: integer; const bmp: PBitmap);
procedure BlitSpriteSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY: integer; const bmp: PBitmap);
procedure BlitSprite(x, y: integer; const bmp: PBitmap);
procedure BlitSpritef(x, y: integer; const bmp: PBitmap);
procedure SetColor(color, r, g, b: byte);
procedure GetColor(color: byte; var r, g, b: byte);
procedure SetPalette(const pal: PPalette);
procedure GetPalette(pal: PPalette);
function FadeColor(color, r, g, b: byte; step: integer) : boolean;
procedure FadeRangeToColor(colorStart, colorEnd, r, g, b: byte; step: integer);
procedure FadeRangeToPalette(colorStart, colorEnd: byte; const pal: PPalette; step: integer);
function LoadFont(const filename: string; font: PFont) : FontResult;
function LoadPalette(const filename: string; pal: PPalette) : FontResult;

implementation

uses GDClip, Toolbox;

type
  GraphicsLayer = record
    flags  : word;
    pixels : PPixelbuffer;
  end;

const
  _graphicsInitialized       : boolean = false;

var
  _layers                    : array[0..(MAX_LAYERS+1)] of GraphicsLayer;
  _boundLayerIndex           : integer;
  _boundLayerSeg             : word;
  _boundLayerOfs             : word;
  _biosFont                  : BiosFontTable absolute $ffa6:$000e;
  _boundFont                 : PFont;
  _valueString               : string[100];
  _currentTextX              : integer;
  _currentTextY              : integer;
  _currentTextStartX         : integer;

procedure InitGraphics(layers: integer);
{ initializes vga mode 13h graphics and allocates memory for any requested
  layers in addition to the vga framebuffer layer }
var
  i : integer;
begin
  if _graphicsInitialized then
    exit;
  if layers > MAX_LAYERS then
    RunError(255);

  _layers[SCREEN_LAYER].flags := LAYERFLAG_ALIASEDMEM;
  _layers[SCREEN_LAYER].pixels := Ptr($a000,$0);

  for i := 1 to layers do begin
    _layers[i].flags := 0;
    GetMem(_layers[i].pixels, SizeOf(Pixelbuffer));
    MemFill(_layers[i].pixels, 0, SizeOf(PixelBuffer));
  end;

  { zero out remaining layer info (if there is any leftovers) }
  if layers < MAX_LAYERS then begin
    for i := (layers+1) to MAX_LAYERS do begin
      _layers[i].flags  := 0;
      _layers[i].pixels := nil;
    end;
  end;

  ResetClipRegion;
  UseLayer(SCREEN_LAYER);
  Cls(0);

  asm
    mov ax, 13h
    int 10h
  end;

  _currentTextX        := 0;
  _currentTextY        := 0;
  _currentTextStartX   := 0;
  _boundFont           := nil;
  _graphicsInitialized := true;
end;

procedure CloseGraphics;
{ resets the screen mode back to text mode, and frees memory allocated for
  any allocated layers }
var
  i : integer;
begin
  if (not _graphicsInitialized) then
    exit;

  UseLayer(0);

  for i := 0 to MAX_LAYERS do begin
    if (_layers[i].flags and LAYERFLAG_ALIASEDMEM) = 0 then begin
      if _layers[i].pixels <> nil then
        FreeMem(_layers[i].pixels, SizeOf(Pixelbuffer));
    end;
    _layers[i].flags  := 0;
    _layers[i].pixels := nil;
  end;

  asm
    mov ax, 03h
    int 10h
  end;

  _graphicsInitialized := false;
end;

function IsGraphicsInitialized: boolean;
begin
  IsGraphicsInitialized := _graphicsInitialized;
end;

procedure UseLayer(layer: integer);
{ switches the active graphics layer }
var
  pixelsPtr : pointer;
begin
  pixelsPtr := _layers[layer].pixels;
  if pixelsPtr = nil then
    RunError(255);

  _boundLayerIndex := layer;
  _boundLayerSeg   := PtrSeg(pixelsPtr);
  _boundLayerOfs   := PtrOfs(pixelsPtr);
end;

procedure Cls(color: Color);
{ clears the current bound layer with the specified color }
begin
  MemFill(Ptr(_boundLayerSeg, _boundLayerOfs), color, 64000);
end;

procedure Flip(layer: integer);
{ 'flips' the specified layer onto the vga framebuffer }
var
  layerPixelsPtr : pointer;
begin
  if layer = SCREEN_LAYER then
    exit;

  layerPixelsPtr := _layers[layer].pixels;
  if layerPixelsPtr = nil then
    RunError(255);

  MemCopy(Ptr($a000, 0), layerPixelsPtr, 64000);
end;

procedure CopyLayer(layer: integer);
{ copies the entire contents of the specified layer onto the currently
  bound layer }
var
  layerPixelsPtr : pointer;
begin
  if layer = _boundLayerIndex then
    exit;

  layerPixelsPtr := _layers[layer].pixels;
  if layerPixelsPtr = nil then
    RunError(255);

  MemCopy(Ptr(_boundLayerSeg, _boundLayerOfs), layerPixelsPtr, 64000);
end;

procedure WaitForVsync;
{ blocks until the next v-sync occurs }
assembler;
asm
  mov dx, 3dah
@first:
  in al, dx
  and al, 8
  jnz @first
@second:
  in al, dx
  and al, 8
  jz @second
end;

function GetBoundLayerIndex : integer;
{ returns the number/index of the currently bound layer }
begin
  GetBoundLayerIndex := _boundLayerIndex;
end;

function GetBoundLayerSegment : word;
{ returns the address segment of the currently bound layer }
begin
  GetBoundLayerSegment := _boundLayerSeg;
end;

function GetBoundLayerOffset : word;
{ returns the offset of the currently bound layer (this will be the offset
  that corresponds with X=0,Y=0 on the layer). }
begin
  GetBoundLayerOffset := _boundLayerOfs;
end;

function GetBoundLayerOffsetAt(x, y: integer) : word;
{ returns the memory offset that the pixel at position x,y is located at
  within any of the screen layers }
assembler;
asm
  mov ax, y                  { ax = y * 320 }
  mov bx, ax
  shl ax, 6
  shl bx, 8
  add ax, bx

  add ax, x                  { ax = ax + x }
  add ax, _boundLayerOfs
end;

function GetBoundLayerPointerAt(x, y: integer) : pointer;
{ returns a pointer to the pixel at position x,y on the currently bound
  layer }
assembler;
asm
  mov ax, y                  { ax = y * 320 }
  mov bx, ax
  shl ax, 6
  shl bx, 8
  add ax, bx

  add ax, x                  { ax = ax + x }

  { return pointer in dx:ax (segment:offset) }
  add ax, _boundLayerOfs
  mov dx, _boundLayerSeg
end;

function GetBitmapOffsetAt(x, y: integer; const bmp: PBitmap) : word;
{ returns the memory offset that the pixel at position x,y is located at
  within the given bitmap }
begin
  GetBitmapOffsetAt := (y * bmp^.Width) + x + Ofs(bmp^.Pixels);
end;

procedure SetClipRegion(x1, y1, x2, y2: integer);
{ changes the current boundaries for all clipped drawing operations.
  affects all layers. }
begin
  if x1 < SCREEN_LEFT then
    ClipRegionLeft := SCREEN_LEFT
  else
    ClipRegionLeft := x1;

  if y1 < SCREEN_TOP then
    ClipRegionTop := SCREEN_TOP
  else
    ClipRegionTop := y1;

  if x2 > SCREEN_RIGHT then
    ClipRegionRight := SCREEN_RIGHT
  else
    ClipRegionRight := x2;

  if y2 > SCREEN_BOTTOM then
    ClipRegionBottom := SCREEN_BOTTOM
  else
    ClipRegionBottom := y2;

  ClipRegionWidth := ClipRegionRight - ClipRegionLeft + 1;
  ClipRegionHeight := ClipRegionBottom - ClipRegionTop + 1;
end;

procedure ResetClipRegion;
{ resets the current boundaries for all clipped drawing operations to
  match the full screen boundaries }
begin
  ClipRegionLeft   := SCREEN_LEFT;
  ClipRegionTop    := SCREEN_TOP;
  ClipRegionRight  := SCREEN_RIGHT;
  ClipRegionBottom := SCREEN_BOTTOM;
  ClipRegionWidth  := SCREEN_WIDTH;
  ClipRegionHeight := SCREEN_HEIGHT;
end;

procedure Pset(x, y: integer; color: Color);
{ draws a pixel on the current layer at x,y using the given color.
  nothing is drawn if x,y are out of bounds of the current clipping region }
assembler;
asm
  mov ax, x
  cmp ax, ClipRegionLeft     { off the left edge? }
  jl @done
  cmp ax, ClipRegionRight    { off the right edge? }
  jg @done

  mov di, y
  cmp di, ClipRegionTop      { off the top edge? }
  jl @done
  cmp di, ClipRegionBottom   { off the bottom edge? }
  jg @done

  mov bx, di                 { di = y * 320 + x }
  shl di, 6
  shl bx, 8
  add di, bx
  add di, ax
  add di, _boundLayerOfs

  mov al, color

  mov es, _boundLayerSeg     { write pixel to current layer }
  mov es:[di], al

@done:
end;

procedure Psetf(x, y: integer; color: Color);
{ draws a pixel on the current layer at x,y using the given color.
  does not perform any bounds checking. }
assembler;
asm
  mov ax, x
  mov di, y

  mov bx, di                 { di = y * 320 + x }
  shl di, 6
  shl bx, 8
  add di, bx
  add di, ax
  add di, _boundLayerOfs

  mov al, color

  mov es, _boundLayerSeg     { write pixel to current layer }
  mov es:[di], al
end;

function Pget(x, y: integer) : Color;
{ gets a pixel from the current layer at x,y, returning the color.
  returns zero if x,y are out of bounds of the current clipping region }
assembler;
asm
  xor ax, ax

  mov cx, x
  cmp cx, ClipRegionLeft     { off the left edge? }
  jl @done
  cmp cx, ClipRegionRight    { off the right edge? }
  jg @done

  mov si, y
  cmp si, ClipRegionTop      { off the top edge? }
  jl @done
  cmp si, ClipRegionBottom   { off the bottom edge? }
  jg @done

  mov bx, si                 { si = y * 320 + x }
  shl si, 6
  shl bx, 8
  add si, bx
  add si, cx
  add si, _boundLayerOfs

  push ds

  mov ds, _boundLayerSeg     { read pixel from current layer }
  mov al, ds:[si]

  pop ds

@done:
end;

function Pgetf(x, y: integer) : Color;
{ gets a pixel from the current layer at x,y, returning the color.
  does not perform any bounds checking. }
assembler;
asm
  xor ax, ax

  mov cx, x
  mov si, y

  mov bx, si                 { si = y * 320 + x }
  shl si, 6
  shl bx, 8
  add si, bx
  add si, cx
  add si, _boundLayerOfs

  push ds

  mov ds, _boundLayerSeg     { read pixel from current layer }
  mov al, ds:[si]

  pop ds
end;

procedure Line(x1, y1, x2, y2: integer; color: Color);
{ draws a line from x1,y1 to x2,y2. the line is clipped at the edges of the
  current clipping region if necessary. }
var
  deltaX, deltaY         : integer;
  deltaXabs, deltaYabs   : integer;
  deltaXsign, deltaYsign : integer;
  x, y, i, dx, dy, loops : integer;
  offset                 : integer;
  offsetXinc, offsetYinc : integer;
  dest                   : PColor;
begin
  dx         := x1;
  dy         := y1;
  deltaX     := x2 - x1;
  deltaY     := y2 - y1;
  deltaXabs  := Abs(deltaX);
  deltaYabs  := Abs(deltaY);
  deltaXsign := SignInt(deltaX);
  deltaYsign := SignInt(deltaY);
  x          := deltaYabs div 2;
  y          := deltaYabs div 2;
  offsetXinc := deltaXsign;
  offsetYinc := deltaYsign * SCREEN_WIDTH;
  dest       := GetBoundLayerPointerAt(x1, y1);

  if ((dx >= ClipRegionLeft)
      and (dy >= ClipRegionTop)
      and (dx <= ClipRegionRight)
      and (dy <= ClipRegionBottom)) then
    dest^ := color;

  if deltaXabs >= deltaYabs then begin
    loops := deltaXabs - 1;
    for i := 0 to loops do begin
      inc(y, deltaYabs);

      if y >= deltaXabs then begin
        dec(y, deltaXabs);
        inc(dy, deltaYsign);
        inc(dest, offsetYinc);
      end;

      inc(dx, deltaXsign);
      inc(dest, offsetXinc);

      if ((dx >= ClipRegionLeft)
          and (dy >= ClipRegionTop)
          and (dx <= ClipRegionRight)
          and (dy <= ClipRegionBottom)) then
        dest^ := color;
    end;

  end else begin
    loops := deltaYabs - 1;
    for i := 0 to loops do begin
      inc(x, deltaXabs);

      if x >= deltaYabs then begin
        dec(x, deltaYabs);
        inc(dx, deltaXsign);
        inc(dest, offsetXinc);
      end;

      inc(dy, deltaYsign);
      inc(dest, offsetYinc);

      if ((dx >= ClipRegionLeft)
          and (dy >= ClipRegionTop)
          and (dx <= ClipRegionRight)
          and (dy <= ClipRegionBottom)) then
        dest^ := color;
    end;
  end;
end;

procedure Linef(x1, y1, x2, y2: integer; color: Color);
{ draws a line from x1,y1 to x2,y2. no clipping is performed. }
var
  deltaX, deltaY         : integer;
  deltaXabs, deltaYabs   : integer;
  deltaXsign, deltaYsign : integer;
  x, y, i, loops         : integer;
  offsetXinc, offsetYinc : integer;
  dest                   : PColor;
begin
  deltaX     := x2 - x1;
  deltaY     := y2 - y1;
  deltaXabs  := Abs(deltaX);
  deltaYabs  := Abs(deltaY);
  deltaXsign := SignInt(deltaX);
  deltaYsign := SignInt(deltaY);
  x          := deltaYabs div 2;
  y          := deltaYabs div 2;
  offsetXinc := deltaXsign;
  offsetYinc := deltaYsign * SCREEN_WIDTH;
  dest       := GetBoundLayerPointerAt(x1, y1);

  dest^ := color;

  if deltaXabs >= deltaYabs then begin
    loops := deltaXabs - 1;
    for i := 0 to loops do begin
      inc(y, deltaYabs);

      if y >= deltaXabs then begin
        dec(y, deltaXabs);
        inc(dest, offsetYinc);
      end;

      inc(dest, offsetXinc);

      dest^ := color;
    end;

  end else begin
    loops := deltaYabs - 1;
    for i := 0 to loops do begin
      inc(x, deltaXabs);

      if x >= deltaYabs then begin
        dec(x, deltaYabs);
        inc(dest, offsetXinc);
      end;

      inc(dest, offsetYinc);

      dest^ := color;
    end;
  end;
end;

procedure HLine(x1, x2, y: integer; color: Color);
{ draws a horizontal line. automatically compensates for incorrect ordering
  of the x coordinates and also clips the line to the current clipping
  region. }
begin
  if x2 < x1 then
    SwapInts(x1, x2);
  if not ClampToClipRegion(x1, y, x2, y) then
    exit;

  HLinef(x1, x2, y, color);
end;

procedure HLinef(x1, x2, y: integer; color: Color);
{ draws a horizontal line. x1 must be less than x2. no clipping is
  performed. }
var
  dest   : pointer;
  length : integer;
begin
  dest   := GetBoundLayerPointerAt(x1, y);
  length := x2 - x1 + 1;
  MemFill(dest, color, length);
end;

procedure VLine(x, y1, y2: integer; color: Color);
{ draws a vertical line. automatically compensates for incorrect ordering
  of the y coordinates and also clips the line to the current clipping
  region. }
begin
  if y2 < y1 then
    SwapInts(y1, y2);
  if not ClampToClipRegion(x, y1, x, y2) then
    exit;

  VLinef(x, y1, y2, color);
end;

procedure VLinef(x, y1, y2: integer; color: Color);
{ draws a vertical line. y1 must be less than y2. no clipping is
  performed. }
var
  offs      : word;
  linesLeft : integer;
begin
  offs      := GetBoundLayerOffsetAt(x, y1);
  linesLeft := y2 - y1 + 1;

  asm
    mov cx, linesLeft
    test cx, cx              { make sure there are > 0 lines to draw }
    jz @done

    mov al, color
    mov es, _boundLayerSeg
    mov di, offs

@draw:
    mov es:[di], al
    add di, SCREEN_WIDTH
    dec cx
    jnz @draw

@done:
  end;
end;

procedure DrawTwoVerticalLines(leftOffs, rightOffs: word;
                               color: Color;
                               height: integer);
assembler;
asm
  mov es, _boundLayerSeg
  mov si, leftOffs
  mov di, rightOffs
  mov al, color
  mov cx, height

@draw:
  mov es:[si], al
  mov es:[di], al
  add si, SCREEN_WIDTH
  add di, SCREEN_WIDTH
  dec cx
  jnz @draw

@done:
end;

procedure DrawVerticalLine(offs: word;
                           color: Color;
                           height: integer);
assembler;
asm
  mov es, _boundLayerSeg
  mov di, offs
  mov al, color
  mov cx, height

@draw:
  mov es:[di], al
  add di, SCREEN_WIDTH
  dec cx
  jnz @draw

@done:
end;

procedure Box(x1, y1, x2, y2: integer; color: Color);
{ draws an empty box. automatically compensates if coordinate pairs are
  swapped so that x1 < x2 and y1 < y2. clips the box to the current clipping
  region boundaries. }
var
  clippedX1, clippedY1, clippedX2, clippedY2 : integer;
  clippedWidth, clippedHeight                : integer;
  offs, offs1, offs2                         : word;
begin
  if x2 < x1 then
    SwapInts(x1, x2);
  if y2 < y1 then
    SwapInts(y1, y2);

  clippedX1     := x1;
  clippedY1     := y1;
  clippedWidth  := x2 - x1 + 1;
  clippedHeight := y2 - y1 + 1;

  if not ClipToClipRegion(clippedX1, clippedY1,
                          clippedWidth, clippedHeight) then
    exit;

  clippedX2 := clippedX1 + clippedWidth - 1;
  clippedY2 := clippedY1 + clippedHeight - 1;

  { top line, only if y1 was within bounds }
  if y1 = clippedY1 then begin
    offs := GetBoundLayerOffsetAt(clippedX1, clippedY1);
    MemFill(Ptr(_boundLayerSeg, offs), color, clippedWidth);
  end;

  { bottom line, only if y2 was within bounds }
  if y2 = clippedY2 then begin
    offs := GetBoundLayerOffsetAt(clippedX1, clippedY2);
    MemFill(Ptr(_boundLayerSeg, offs), color, clippedWidth);
  end;

  { draw both left and right lines if neither x1 nor x2 were clipped }
  if (x1 = clippedX1) and (x2 = clippedX2) then begin
    offs1 := GetBoundLayerOffsetAt(clippedX1, clippedY1);
    offs2 := GetBoundLayerOffsetAt(clippedX2, clippedY1);
    DrawTwoVerticalLines(offs1, offs2, color, clippedHeight);

  { draw left line if x1 was not clipped }
  end else if x1 = clippedX1 then begin
    offs := GetBoundLayerOffsetAt(clippedX1, clippedY1);
    DrawVerticalLine(offs, color, clippedHeight);

  { draw right line if x2 was not clipped }
  end else if x2 = clippedX2 then begin
    offs := GetBoundLayerOffsetAt(clippedX2, clippedY1);
    DrawVerticalLine(offs, color, clippedHeight);

  end;
end;

procedure Boxf(x1, y1, x2, y2: integer; color: Color);
{ draws an empty box. x1 must be less than x2, and y1 must be less than y2.
  no clipping is performed. }
var
  offs, offsLeft, offsRight : word;
  width, linesLeft          : integer;
begin
  width     := x2 - x1 + 1;
  linesLeft := y2 - y1;
  offs      := GetBoundLayerOffsetAt(x1, y1);
  offsLeft  := offs;
  offsRight := offs + width - 1;

  asm
    mov al, color            { spread color byte over all of EAX so we can }
    mov ah, al               { draw 4 pixels at once horizontally. }
    db $66; shl ax, 8        { shl eax, 8 }
    mov al, ah
    db $66; shl ax, 8        { shl eax, 8 }
    mov al, ah

    db $66; xor cx, cx       { xor ecx, ecx }
    mov es, _boundLayerSeg
    mov dx, width
    mov cx, linesLeft
    mov di, offsLeft
    mov si, offsRight

    test cx, cx              { do we have any vertical height to draw? }
    jz @draw_horiz1          { if not, skip to horizontal drawing ... }

@draw_vert:
    { draw both vertical lines }
    mov es:[di], al
    mov es:[si], al
    add di, SCREEN_WIDTH
    add si, SCREEN_WIDTH
    dec cx
    jnz @draw_vert

@draw_horiz1:
    { di will be at (x1,y2) currently. this is the correct location to draw
      the bottom horizontal line }
    mov cx, dx               { cx = number of dwords to draw }
    mov bx, cx               { bx = remaining number of pixels to draw }
    shr cx, 2
    and bx, 3

    db $f3,$66,$ab           { rep stosd - draw dwords }
    mov cx, bx
    rep stosb                { draw remaining pixels }

@draw_horiz2:
    { now draw the top line. reposition to (x1,y1) }
    mov di, offsLeft
    mov cx, dx               { cx = number of dwords to draw }
    mov bx, cx               { bx = remaining number of pixels to draw }
    shr cx, 2
    and bx, 3

    db $f3,$66,$ab           { rep stosd - draw dwords }
    mov cx, bx
    rep stosb                { draw remaining pixels }

@done:
  end;
end;

procedure FilledBox(x1, y1, x2, y2: integer; color: Color);
{ draws a filled box. automatically compensates if coordinate pairs are
  swapped so that x1 < x2 and y1 < y2. clips the box to the current clipping
  region boundaries. }
begin
  if x2 < x1 then
    SwapInts(x1, x2);
  if y2 < y1 then
    SwapInts(y1, y2);

  if not ClampToClipRegion(x1, y1, x2, y2) then
    exit;

  FilledBoxf(x1, y1, x2, y2, color);
end;

procedure FilledBoxf(x1, y1, x2, y2: integer; color: Color);
{ draws a filled box. x1 must be less than x2, and y1 must be less than y2.
  no clipping is performed. }
var
  offs                        : word;
  width, linesLeft, remainder : integer;
begin
  width     := x2 - x1 + 1;
  linesLeft := y2 - y1 + 1;
  offs      := GetBoundLayerOffsetAt(x1, y1);

  asm
    mov si, linesLeft
    test si, si              { stop if there are 0 lines to draw }
    jz @nothing_to_draw

    mov al, color            { spread color byte over all of EAX so we can }
    mov ah, al               { draw 4 pixels at once horizontally. }
    db $66; shl ax, 8        { shl eax, 8 }
    mov al, ah
    db $66; shl ax, 8        { shl eax, 8 }
    mov al, ah

    mov bx, width
    mov di, offs
    mov es, _boundLayerSeg
    mov dx, SCREEN_WIDTH     { dx = y-inc to next line after drawing horiz }
    sub dx, bx

    { *** WARNING: no stack/vars access after this! *** }
    push bp
    mov bp, bx
    and bp, 3                { bp = remaining number of pixels to draw }
    shr bx, 2                { bx = number of dwords to draw }

    db $66; xor cx, cx       { xor ecx, ecx }

    test bp, bp
    jz @draw

@draw_with_remainder:
    mov cx, bx
    db $f3,$66,$ab           { rep stosd - draw dwords }
    mov cx, bp
    rep stosb                { draw remainder pixel }
    add di, dx               { move to start of next line }
    dec si                   { decrease line counter }
    jnz @draw_with_remainder { keep drawing if there are more lines }
    jmp @done

@draw:
    mov cx, bx
    db $f3,$66,$ab           { rep stosd - draw dwords }
    add di, dx               { move to start of next line }
    dec si                   { decrease line counter }
    jnz @draw                { keep drawing if there are more lines }
    jmp @done

@done:
    pop bp
@nothing_to_draw:
  end;
end;

procedure UseFont(font : PFont);
{ binds the specified font. all subsequent text/string drawing will be
  done using this font until this is called again with a different font.
  pass nil to revert back to using the standard VGA BIOS font. }
begin
  if font = nil then
    _boundFont := nil { means to use VGA BIOS font instead }
  else
    _boundFont := font;
end;

{ TODO: rewrite this function. it is poopy and sad. }
procedure DrawChar(x, y, drawX, drawY, width, height: integer;
                   color: Color;
                   ch: char);
var
  dest, fontSrc         : word;
  cx, cy                : integer;
  offsetX, offsetY      : integer;
  destWidth, destHeight : integer;
  fontCharMap           : PBiosFontChar;
  fontCharLine          : byte;
  pixel                 : byte;
begin
  dest        := GetBoundLayerOffsetAt(drawX, drawY);

  if _boundFont <> nil then
    fontCharMap := @_boundFont^.chars[Ord(ch), 0]
  else
    fontCharMap := @_biosFont[Ord(ch), 0];

  { get offset x,y to start drawing char from (will be in range 0-7) }
  offsetX     := drawX - x;
  offsetY     := drawY - y;
  destWidth   := width + offsetX - 1;
  destHeight  := height + offsetY - 1;

  { cx,cy are always in "char coordinate space" (that is, 0-7) }
  for cy := offsetY to destHeight do begin
    fontCharLine := fontCharMap^[cy];

    for cx := offsetX to destWidth do begin
      pixel := ((fontCharLine) and (1 shl ((CHAR_WIDTH - 1) - cx)));
      if pixel > 0 then
        mem[_boundLayerSeg:(dest + (cx - offsetX))] := color;
    end;

    inc(dest, SCREEN_WIDTH);
  end;
end;

procedure DrawSubString(x, y: integer;
                        color: Color;
                        const text: string;
                        textStart, textEnd: integer);
{ draws a sub-string starting from the top-left coordinate (x,y). handles
  multi-line strings automatically. the text is clipped to the current
  clipping region boundaries as needed. only part of the string is drawn,
  as specified by textStart and textEnd (non-inclusive end) }
var
  ch                          : char;
  i, currentX, currentY       : integer;
  width, height, length       : integer;
  spaceWidth                  : integer;
  clippedX, clippedY          : integer;
  clippedWidth, clippedHeight : integer;
begin
  currentX := x;
  currentY := y;
  width    := CHAR_WIDTH;

  if _boundFont <> nil then begin
    height     := _boundFont^.height;
    spaceWidth := _boundFont^.widths[Ord(' ')];
  end else begin
    height     := CHAR_HEIGHT;
    spaceWidth := CHAR_WIDTH;
  end;

  for i := textStart to textEnd do begin
    ch := text[i];
    case ch of
      { move to next line }
      #10: begin
          currentX := x;
          inc(currentY, height);
        end;
      #13: begin;
        end;
      { skip a character ahead, no need to "draw" a space char (empty) }
      ' ': inc(currentX, spaceWidth);
      else begin
          if _boundFont <> nil then
            width := _boundFont^.widths[Ord(ch)];

          clippedX      := currentX;
          clippedY      := currentY;
          clippedWidth  := width;
          clippedHeight := height;
          if ClipToClipRegion(clippedX, clippedY, clippedWidth, clippedHeight) then
            DrawChar(currentX, currentY, clippedX, clippedY, clippedWidth, clippedHeight, color, ch);

          inc(currentX, width);
      end;
    end;
  end;
end;

procedure DrawString(x, y: integer; color: Color; const text: string);
{ draws a string starting from the top-left coordinate (x,y). handles
  multi-line strings automatically. the text is clipped to the current
  clipping region boundaries as needed. }
begin
  DrawSubString(x, y, color, text, 1, length(text));
end;

procedure DrawStringf(x, y: integer; color: Color; const text: string);
{ draws a string starting from the top-left coordinate (x,y). handles
  multi-line strings automatically. no clipping is performed. }
var
  ch                    : char;
  i, currentX, currentY : integer;
  width, height, len    : integer;
  spaceWidth            : integer;
begin
  currentX := x;
  currentY := y;
  width    := CHAR_WIDTH;
  len      := length(text);

  if _boundFont <> nil then begin
    height     := _boundFont^.height;
    spaceWidth := _boundFont^.widths[Ord(' ')];
  end else begin
    height     := CHAR_HEIGHT;
    spaceWidth := CHAR_WIDTH;
  end;

  for i := 1 to len do begin
    ch := text[i];
    case ch of
      { move to next line }
      #10: begin
          currentX := x;
          inc(currentY, height);
        end;
      #13: begin;
      	end;
      { skip a character ahead, no need to "draw" a space char (empty) }
      ' ': inc(currentX, spaceWidth);
      else begin
          if _boundFont <> nil then
            width := _boundFont^.widths[Ord(ch)];

          DrawChar(currentX, currentY, currentX, currentY, width, height, color, ch);
          inc(currentX, width);
      end;
    end;
  end;
end;

procedure PrintAt(x, y: integer);
{ sets the text position for subsequent calls to any of the PrintXxx
  functions. }
begin
  if x > SCREEN_RIGHT then
    exit;
  if y > SCREEN_BOTTOM then
    exit;

  _currentTextX      := x;
  _currentTextY      := y;
  _currentTextStartX := x;
end;

procedure PrintShortInt(value: shortint; color: Color);
{ displays a short-integer value at the current text position. clipping is
  performed as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintInt(value: integer; color: Color);
{ displays an integer value at the current text position. clipping is
  performed as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintLongInt(value: longint; color: Color);
{ displays a long-integer value at the current text position. clipping is
  performed as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintByte(value: byte; color: Color);
{ displays a byte value at the current text position. clipping is performed
  as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintWord(value: word; color: Color);
{ displays a word value at the current text position. clipping is performed
  as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintReal(value: real; color: Color);
{ displays a real value at the current text position. clipping is performed
  as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintRealFmt(value: real; decimals: integer; color: Color);
{ displays a real value using a specific number of decimal points at the
  current text position. clipping is performed as necessary. }
begin
  Str(value:0:decimals, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintSingle(value: single; color: Color);
{ displays a single-precision value at the current text position. clipping
  is performed as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintSingleFmt(value: single; decimals: integer; color: Color);
{ displays a single-precision value using a specific number of decimal points
  at the current text position. clipping is performed as necessary. }
begin
  Str(value:0:decimals, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintDouble(value: double; color: Color);
{ displays a double-precision value at the current text position. clipping
  is performed as necessary. }
begin
  Str(value, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintDoubleFmt(value: double; decimals: integer; color: Color);
{ displays a double-precision value using a specific number of decimal points
  at the current text position. clipping is performed as necessary. }
begin
  Str(value:0:decimals, _valueString);
  DrawString(_currentTextX, _currentTextY, color, _valueString);
  inc(_currentTextX, length(_valueString) * CHAR_WIDTH);
end;

procedure PrintString(const text: string; color: Color);
{ displays a string at the current text position. handles multi-line strings
  automatically. clipping is performed as necessary. }
var
  ch                          : char;
  i, width, height, len       : integer;
  spaceWidth                  : integer;
  clippedX, clippedY          : integer;
  clippedWidth, clippedHeight : integer;
begin
  width  := CHAR_WIDTH;
  len    := length(text);

  if _boundFont <> nil then begin
    height     := _boundFont^.height;
    spaceWidth := _boundFont^.widths[Ord(' ')];
  end else begin
    height     := CHAR_HEIGHT;
    spaceWidth := CHAR_WIDTH;
  end;

  for i := 1 to len do begin
    ch := text[i];
    case ch of
      { move to next line }
      #10: begin
          _currentTextX := _currentTextStartX;
          inc(_currentTextY, height);
        end;
      #13: begin;
        end;
      { skip a character ahead, no need to "draw" a space char (empty) }
      ' ': inc(_currentTextX, spaceWidth);
      else begin
          if _boundFont <> nil then
            width := _boundFont^.widths[Ord(ch)];

          clippedX      := _currentTextX;
          clippedY      := _currentTextY;
          clippedWidth  := width;
          clippedHeight := height;
          if ClipToClipRegion(clippedX, clippedY, clippedWidth, clippedHeight) then
            DrawChar(_currentTextX, _currentTextY, clippedX, clippedY, clippedWidth, clippedHeight, color, ch);

          inc(_currentTextX, width);
      end;
    end;
  end;
end;

procedure AllocBitmap(width, height: word; var bmp: PBitmap);
{ allocates the memory necessary for a bitmap of the specified size }
begin
  GetMem(bmp, SizeOf(Bitmap) + (width * height) - 1);

  bmp^.Width  := width;
  bmp^.Height := height;
end;

procedure FreeBitmap(bmp: PBitmap);
{ frees previously allocated memory for the given bitmap. the bitmap should
  not be used again after this unless re-allocated via AllocBitmap }
begin
  if bmp = nil then exit;
  FreeMem(bmp, SizeOf(Bitmap) + (bmp^.width * bmp^.height) - 1);
end;

procedure GrabBitmap(x, y: integer; width, height: word; bmp: PBitmap);
{ copies a region of pixels from the current layer onto the specified bitmap.
  the bitmap must have already been allocated, and be large enough to hold
  pixel data of the provided dimensions. }
var
  line      : word;
  src, dest : ^byte;
begin
  src  := GetBoundLayerPointerAt(x, y);
  dest := @bmp^.Pixels;

  { TODO: re-write this in inline-assembly }
  for line := 0 to (height - 1) do begin
    MemCopy(dest, src, width);
    inc(src, SCREEN_WIDTH);
    inc(dest, width);
  end;
end;



{ "Low-Level" Solid Blit routines. These are only really intended to be
  called by the main "BlitXXX" functions, but possibly could be used directly
  by applications when the utmost speed is required ...
  These functions DO NOT perform any argument validation or clipping, etc! }

procedure LLBlit4(width, height, destYinc, srcYinc: integer;
                  destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination. assumes the source
  pixels have an exact dword-sized width. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  db $66; xor cx, cx         { xor ecx, ecx }
  mov ax, width
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

  shr ax, 2                  { ax = number of dwords to draw per line }

@draw_line:
  mov cx, ax
  db $f3,$66,$a5             { rep movsd - draw dwords }

  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlit4r(width, height, destYinc, srcYinc: integer;
                   destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination. assumes the source
  pixels have a width composed of some dword-sized portion PLUS a remainder
  of 1-3 pixels at the end. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  db $66; xor cx, cx         { xor ecx, ecx }
  mov ax, width
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

  mov bx, ax
  shr ax, 2                  { ax = number of dwords to draw per line }
  and bx, 3                  { bx = remaining number of pixels }

@draw_line:
  mov cx, ax
  db $f3,$66,$a5             { rep movsd - draw dwords }
  mov cx, bx
  rep movsb                  { draw remainder pixels }

  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlitRemainder(width, height, destYinc, srcYinc: integer;
                          destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination. will just use a simple
  rep movsb for each line. intended only for blits whose width is <= 3. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax
  rep movsb                  { draw pixels }

  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

{ End of Low-Level Solid Blit functions ^^^ }



procedure BlitSubset(srcX, srcY, srcWidth, srcHeight, destX, destY: integer;
                     const bmp: PBitmap);
{ draws the specified subset/region of the bitmap onto the current layer. the
  bitmap is clipped to the current clipping region boundaries. }
begin
  if not ClipBlitToClipRegion(srcX, srcY, srcWidth, srcHeight, destX, destY) then
    exit;

  BlitSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY, bmp);
end;

procedure BlitSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY: integer;
                      const bmp: PBitmap);
{ draws the specified subset/region of the bitmap onto the current layer. no
  clipping is performed. }
var
  srcSeg, srcOffs, destOffs : word;
  srcYinc, destYinc         : integer;
  width4, widthRemainder    : integer;
begin
  srcSeg         := Seg(bmp^.Pixels);
  srcOffs        := GetBitmapOffsetAt(srcX, srcY, bmp);
  destOffs       := GetBoundLayerOffsetAt(destX, destY);

  srcYinc        := bmp^.Width - srcWidth;
  destYinc       := SCREEN_WIDTH - srcWidth;

  width4         := srcWidth div 4;
  widthRemainder := srcWidth and 3;

  if ((width4 > 0) and (widthRemainder = 0)) then begin
    LLBlit4(srcWidth, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
  end else if ((width4 > 0) and (widthRemainder > 0)) then begin
    LLBlit4r(srcWidth, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
  end else begin
    LLBlitRemainder(srcWidth, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
  end
end;

procedure Blit(x, y: integer; const bmp: PBitmap);
{ draws the given bitmap onto the current layer. the bitmap is clipped to
  the current clipping region boundaries. }
var
  srcX, srcY          : integer;
  srcWidth, srcHeight : integer;
begin
  srcX      := 0;
  srcY      := 0;
  srcWidth  := bmp^.Width;
  srcHeight := bmp^.Height;

  if not ClipBlitToClipRegion(srcX, srcY, srcWidth, srcHeight, x, y) then
    exit;

  BlitSubsetf(srcX, srcY, srcWidth, srcHeight, x, y, bmp);
end;

procedure Blitf(x, y: integer; const bmp: PBitmap);
{ draws the given bitmap onto the current layer. no clipping is performed. }
begin
  BlitSubsetf(0, 0, bmp^.Width, bmp^.Height, x, y, bmp);
end;



{ "Low-Level" Transparent Blit routines. These are only really intended to be
  called by the main "BlitXXX" functions, but possibly could be used directly
  by applications when the utmost speed is required ...
  These functions DO NOT perform any argument validation or clipping, etc! }

procedure LLBlitSprite8(width8, height, destYinc, srcYinc: integer;
                        destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination, treating colour 0 as the
  transparent pixel which will be skipped over. assumes the source pixels
  have an exact double-dword-sized width (that is, an exact multiple of 8). }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width8
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax                 { cx = number of 8-pixel runs left to draw }

@draw_px_0:
  mov bx, ds:[si+0]          { load two pixels }
  test bl, bl
  jz @draw_px_1              { if it is color 0, skip it }
  mov es:[di+0], bl          { otherwise, draw it }
@draw_px_1:
  test bh, bh                { bh has the second loaded pixel }
  jz @draw_px_2
  mov es:[di+1], bh
@draw_px_2:
  mov bx, ds:[si+2]
  test bl, bl
  jz @draw_px_3
  mov es:[di+2], bl
@draw_px_3:
  test bh, bh
  jz @draw_px_4
  mov es:[di+3], bh
@draw_px_4:
  mov bx, ds:[si+4]
  test bl, bl
  jz @draw_px_5
  mov es:[di+4], bl
@draw_px_5:
  test bh, bh
  jz @draw_px_6
  mov es:[di+5], bh
@draw_px_6:
  mov bx, ds:[si+6]
  test bl, bl
  jz @draw_px_7
  mov es:[di+6], bl
@draw_px_7:
  test bh, bh
  jz @end_run
  mov es:[di+7], bh

@end_run:
  add si, 8                  { mov src and dest up 8 pixels }
  add di, 8
  dec cx                     { decrease 8-pixel run loop counter }
  jnz @draw_px_0             { if there are still more runs, draw them }

@end_line:
  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlitSprite4(width4, height, destYinc, srcYinc: integer;
                        destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination, treating colour 0 as the
  transparent pixel which will be skipped over. assumes the source pixels
  have an exact dword-sized width (that is, an exact multiple of 4). }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width4
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax                 { cx = number of 4-pixel runs left to draw }

@draw_px_0:
  mov bx, ds:[si+0]          { load two pixels }
  test bl, bl
  jz @draw_px_1              { if it is color 0, skip it }
  mov es:[di+0], bl          { otherwise, draw it }
@draw_px_1:
  test bh, bh                { bh has the second loaded pixel }
  jz @draw_px_2
  mov es:[di+1], bh
@draw_px_2:
  mov bx, ds:[si+2]
  test bl, bl
  jz @draw_px_3
  mov es:[di+2], bl
@draw_px_3:
  test bh, bh
  jz @end_run
  mov es:[di+3], bh

@end_run:
  add si, 4                  { mov src and dest up 4 pixels }
  add di, 4
  dec cx                     { decrease 4-pixel run loop counter }
  jnz @draw_px_0             { if there are still more runs, draw them }

@end_line:
  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlitSprite8r(width8, height, widthRemainder, destYinc, srcYinc: integer;
                         destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination, treating colour 0 as the
  transparent pixel which will be skipped over. assumes the source pixels
  have a width that is composed of a double-dword-sized section (that is,
  some segment that is a multiple of 8) plus some remainder bit that is
  <= 7 pixels long. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width8
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax                 { cx = number of 8-pixel runs left to draw }

@draw_px_0:
  mov bx, ds:[si+0]          { load two pixels }
  test bl, bl
  jz @draw_px_1              { if it is color 0, skip it }
  mov es:[di+0], bl          { otherwise, draw it }
@draw_px_1:
  test bh, bh                { bh has the second loaded pixel }
  jz @draw_px_2
  mov es:[di+1], bh
@draw_px_2:
  mov bx, ds:[si+2]
  test bl, bl
  jz @draw_px_3
  mov es:[di+2], bl
@draw_px_3:
  test bh, bh
  jz @draw_px_4
  mov es:[di+3], bh
@draw_px_4:
  mov bx, ds:[si+4]
  test bl, bl
  jz @draw_px_5
  mov es:[di+4], bl
@draw_px_5:
  test bh, bh
  jz @draw_px_6
  mov es:[di+5], bh
@draw_px_6:
  mov bx, ds:[si+6]
  test bl, bl
  jz @draw_px_7
  mov es:[di+6], bl
@draw_px_7:
  test bh, bh
  jz @end_run
  mov es:[di+7], bh

@end_run:
  add si, 8                  { mov src and dest up 8 pixels }
  add di, 8
  dec cx                     { decrease 8-pixel run loop counter }
  jnz @draw_px_0             { if there are still more runs, draw them }

@start_remainder_run:        { now draw remaining pixels ( <= 7 pixels ) }
  mov cx, widthRemainder

@draw_pixel:
  mov bl, ds:[si]            { load pixel }
  inc si
  test bl, bl                { if zero, skip to next pixel }
  jz @end_pixel
  mov es:[di], bl            { else, draw the pixel }
@end_pixel:
  inc di
  dec cx
  jnz @draw_pixel

@end_line:
  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlitSprite4r(width4, height, widthRemainder, destYinc, srcYinc: integer;
                         destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination, treating colour 0 as the
  transparent pixel which will be skipped over. assumes the source pixels
  have a width that is composed of a dword-sized section (that is, some
  segment that is a multiple of 4) plus some remainder bit that is
  <= 3 pixels long. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width4
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax                 { cx = number of 4-pixel runs left to draw }

@draw_px_0:
  mov bx, ds:[si+0]          { load two pixels }
  test bl, bl
  jz @draw_px_1              { if it is color 0, skip it }
  mov es:[di+0], bl          { otherwise, draw it }
@draw_px_1:
  test bh, bh                { bh has the second loaded pixel }
  jz @draw_px_2
  mov es:[di+1], bh
@draw_px_2:
  mov bx, ds:[si+2]
  test bl, bl
  jz @draw_px_3
  mov es:[di+2], bl
@draw_px_3:
  test bh, bh
  jz @end_run
  mov es:[di+3], bh

@end_run:
  add si, 4                  { mov src and dest up 4 pixels }
  add di, 4
  dec cx                     { decrease 4-pixel run loop counter }
  jnz @draw_px_0             { if there are still more runs, draw them }

@start_remainder_run:        { now draw remaining pixels ( <= 3 pixels ) }
  mov cx, widthRemainder

@draw_pixel:
  mov bl, ds:[si]            { load pixel }
  inc si
  test bl, bl                { if zero, skip to next pixel }
  jz @end_pixel
  mov es:[di], bl            { else, draw the pixel }
@end_pixel:
  inc di
  dec cx
  jnz @draw_pixel

@end_line:
  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

procedure LLBlitSpriteRemainder(width, height, destYinc, srcYinc: integer;
                                destOffs, srcSeg, srcOffs: word);
{ blit a block of memory to the given destination, treating colour 0 as the
  transparent pixel which will be skipped over. this is the slowest of the
  transparent blit routines, that technically can draw at any width, but
  is really intended for widths <= 7 only. }
assembler;
asm
  push ds

  mov dx, height             { dx = line loop counter }
  test dx, dx                { stop now if there's zero lines to draw }
  jz @done

  mov ax, width
  mov di, destOffs
  mov si, srcOffs
  mov es, _boundLayerSeg
  mov ds, srcSeg

@draw_line:
  mov cx, ax                 { cx = number of pixels to draw }

@draw_pixel:
  mov bl, ds:[si]            { load pixel }
  inc si
  test bl, bl                { if zero, skip to next pixel }
  jz @end_pixel
  mov es:[di], bl            { else, draw the pixel }
@end_pixel:
  inc di
  dec cx
  jnz @draw_pixel            { loop while there's still pixels left }

@end_line:
  add si, srcYinc            { move to next line }
  add di, destYinc
  dec dx                     { decrease line loop counter }
  jnz @draw_line

@done:
  pop ds
end;

{ End of Low-Level Transparent Blit functions ^^^ }



procedure BlitSpriteSubset(srcX, srcY, srcWidth, srcHeight, destX, destY: integer;
                           const bmp: PBitmap);
{ draws the specified subset/region of the given bitmap onto the current
  layer, ignoring color 0 (treated as transparent). the bitmap is clipped to
  the current clipping region boundaries. }
begin
  if not ClipBlitToClipRegion(srcX, srcY, srcWidth, srcHeight, destX, destY) then
    exit;

  BlitSpriteSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY, bmp);
end;

procedure BlitSpriteSubsetf(srcX, srcY, srcWidth, srcHeight, destX, destY: integer;
                            const bmp: PBitmap);
{ draws the specified subset/region of the given bitmap onto the current
  layer, ignoring color 0 (treated as transparent). no clipping is
  performed. }
var
  srcSeg, srcOffs, destOffs : word;
  srcYinc, destYinc         : integer;
  width4, widthRemainder    : integer;
begin
  srcSeg         := Seg(bmp^.Pixels);
  srcOffs        := GetBitmapOffsetAt(srcX, srcY, bmp);
  destOffs       := GetBoundLayerOffsetAt(destX, destY);

  srcYinc        := bmp^.Width - srcWidth;
  destYinc       := SCREEN_WIDTH - srcWidth;

  width4         := srcWidth div 4;
  widthRemainder := srcWidth and 3;

  if (width4 > 0) and (widthRemainder = 0) then begin
    if ((width4 and 1) = 0) then begin
      { width is actually an even multiple of 8! }
      LLBlitSprite8(width4 div 2, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
    end else begin
      { width is a multiple of 4 (no remainder) }
      LLBlitSprite4(width4, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
    end;

  end else if (width4 > 0) and (widthRemainder > 0) then begin
    if ((width4 and 1) = 0) then begin
      { width is mostly made up of an even multiple of 8. but there is also
        a small remainder }
      LLBlitSprite8r(width4 div 2, srcHeight, widthRemainder, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
    end else begin
      { width is >= 4 with a remainder }
      LLBlitSprite4r(width4, srcHeight, widthRemainder, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
    end;

  end else begin
    { width is <= 3 }
    LLBlitSpriteRemainder(widthRemainder, srcHeight, destYinc, srcYinc, destOffs, srcSeg, srcOffs);
  end;
end;

procedure BlitSprite(x, y: integer; const bmp: PBitmap);
{ draws the given bitmap onto the current layer, ignoring color 0 (treated
  as transparent). the bitmap is clipped to the current clipping region
  boundaries. }
var
  srcX, srcY          : integer;
  srcWidth, srcHeight : integer;
begin
  srcX      := 0;
  srcY      := 0;
  srcWidth  := bmp^.Width;
  srcHeight := bmp^.Height;

  if not ClipBlitToClipRegion(srcX, srcY, srcWidth, srcHeight, x, y) then
    exit;

  BlitSpriteSubsetf(srcX, srcY, srcWidth, srcHeight, x, y, bmp);
end;

procedure BlitSpritef(x, y: integer; const bmp: PBitmap);
{ draws the given bitmap onto the current layer, ignoring color 0 (treated
  as transparent). no clipping is performed. }
begin
  BlitSpriteSubsetf(0, 0, bmp^.Width, bmp^.Height, x, y, bmp);
end;

procedure SetColor(color, r, g, b: byte);
{ changes the VGA color palette for the color specified }
begin
  port[$3c6] := $ff;
  port[$3c8] := color;
  port[$3c9] := r;
  port[$3c9] := g;
  port[$3c9] := b;
end;

procedure GetColor(color: byte; var r, g, b: byte);
{ reads the current VGA color palette RGB values for the color specified }
begin
  port[$3c6] := $ff;
  port[$3c7] := color;
  r := port[$3c9];
  g := port[$3c9];
  b := port[$3c9];
end;

procedure SetPalette(const pal: PPalette);
{ sets the current VGA color palette to the given one }
var
  i : integer;
begin
  for i := 0 to 255 do begin
    SetColor(i, pal^[i, 0], pal^[i, 1], pal^[i, 2]);
  end;
end;

procedure GetPalette(pal: PPalette);
{ reads the current VGA color palette, storing all RGB values in the
  provided Palette structure }
var
  i : integer;
begin
  for i := 0 to 255 do begin
    GetColor(i, pal^[i, 0], pal^[i, 1], pal^[i, 2]);
  end;
end;

function FadeColor(color, r, g, b: byte; step: integer) : boolean;
{ fades (in/out) the specified color towards the given RGB values by 'step'
  amount. returns true if the color's RGB values have reached the target
  RGB values, false otherwise. }
var
  red, green, blue    : byte;
  diffR, diffG, diffB : byte;
  modified            : boolean;
begin
  modified := false;

  GetColor(color, red, green, blue);

  if red <> r then begin
    modified := true;
    diffR    := Abs(red - r);
    if red > r then
      dec(red, Min(step, diffR))
    else
      inc(red, Min(step, diffR));
  end;

  if green <> g then begin
    modified := true;
    diffG    := Abs(green - g);
    if green > g then
      dec(green, Min(step, diffG))
    else
      inc(green, Min(step, diffG));
  end;

  if blue <> b then begin
    modified := true;
    diffB    := Abs(blue - b);
    if blue > b then
      dec(blue, Min(step, diffB))
    else
      inc(blue, Min(step, diffB));
  end;

  if modified then
    SetColor(color, red, green, blue);

  FadeColor := ((red = r) and (green = g) and (blue = b));
end;

procedure FadeRangeToColor(colorStart, colorEnd, r, g, b: byte;
                           step: integer);
{ fades a range of colors in the current VGA color palette towards the
  given RGB values. blocks, looping until the fade is complete. }
var
  i    : integer;
  done : boolean;
begin
  done := false;
  step := Abs(step);

  while not done do begin
    done := true;
    WaitForVsync;
    for i := colorStart to colorEnd do begin
      if not FadeColor(i, r, g, b, step) then
        done := false;
    end;
  end;
end;

procedure FadeRangeToPalette(colorStart, colorEnd: byte;
                             const pal: PPalette;
                             step: integer);
{ fades a range of colors in the current VGA color palette towards the
  given color palette. blocks, looping until the fade is complete. }
var
  i    : integer;
  done : boolean;
begin
  done := false;
  step := Abs(step);

  while not done do begin
    done := true;
    WaitForVsync;
    for i := colorStart to colorEnd do begin
      if not FadeColor(i, pal^[i, 0], pal^[i, 1], pal^[i, 2], step) then
        done := false;
    end;
  end;
end;

function LoadFont(const filename: string; font: PFont) : FontResult;
{ loads a font from the given file, storing it in the Font instance
  provided. returns FontOk on success. }
var
  f : file;
  x : integer;
label ioError;
begin
  if font = nil then begin
    LoadFont := FontBadArgs;
    exit;
  end;

  Assign(f, filename);

  Reset(f, 1);
  if IOResult <> 0 then begin
    Close(f);
    x := IOResult;  { clear i/o error flag }
    LoadFont := FontNotFound;
    exit;
  end;

  { this font format is the same as the one DirectQB uses. it is a simple
    format that i think works pretty well, so why not re-use it here ... }

  with font^ do begin
    { standard BIOS-like format list of full ASCII 0-255 characters.
      8-bytes per character }
    BlockRead(f, chars, SizeOf(BiosFontTable));
    if IOResult <> 0 then goto ioError;

    { 255 bytes, each byte representing the width of each ASCII character }
    BlockRead(f, widths, SizeOf(BiosFontCharWidths));
    if IOResult <> 0 then goto ioError;

    { single byte, the global character height. that is, this is the max
      height of any of the 256 ASCII characters in this font. will be <= 8 }
    BlockRead(f, height, 1);
    if IOResult <> 0 then goto ioError;
  end;

  Close(f);
  x := IOResult;  { clear i/o error flag (just in case) }
  LoadFont := FontOk;
  exit;

ioError:
  Close(f);
  x := IOResult;  { clear i/o error flag }
  LoadFont := FontIOError;
end;

function LoadPalette(const filename: string; pal: PPalette) : FontResult;
begin
end;

begin
  if Test8086 < 2 then begin
    writeln('The GDGFX unit requires a 386 cpu or higher!');
    halt;
  end;
end.
