{ GDlib Coordinate/Region/Screen Clipping Utilities
  Gered King, 2018 }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit GDClip;

interface

function IsPointInScreen(x, y: integer) : boolean;
function IsPointInClipRegion(x, y: integer) : boolean;
function IsRegionInScreen(x1, y1, x2, y2: integer) : boolean;
function IsRegionInClipRegion(x1, y1, x2, y2: integer) : boolean;
function ClampToScreen(var x1, y1, x2, y2: integer) : boolean;
function ClampToClipRegion(var x1, y1, x2, y2: integer) : boolean;
function ClipToScreen(var x, y, width, height: integer) : boolean;
function ClipToClipRegion(var x, y, width, height: integer) : boolean;
function ClipBlitToScreen(var srcX, srcY, srcWidth, srcHeight, destX, destY: integer) : boolean;
function ClipBlitToClipRegion(var srcX, srcY, srcWidth, srcHeight, destX, destY: integer) : boolean;

implementation

uses GDGfx;

function IsPointInScreen(x, y: integer) : boolean;
{ returns true if the given point is within the screen boundaries }
begin
  IsPointInScreen := ((x < SCREEN_LEFT)
                      or (y < SCREEN_TOP)
                      or (x > SCREEN_RIGHT)
                      or (y > SCREEN_BOTTOM));
end;

function IsPointInClipRegion(x, y: integer) : boolean;
{ returns true if the given point is within the current clipping region }
begin
  IsPointInClipRegion := ((x < ClipRegionLeft)
                          or (y < ClipRegionTop)
                          or (x > ClipRegionRight)
                          or (y > ClipRegionBottom));
end;

function IsRegionInScreen(x1, y1, x2, y2: integer) : boolean;
{ returns true if the given region is partially or completely within the
  screen boundaries }
begin
  IsRegionInScreen := false;

  if (y1 < SCREEN_TOP) and (y2 < SCREEN_TOP) then
    exit;
  if (y1 > SCREEN_BOTTOM) and (y2 > SCREEN_BOTTOM) then
    exit;
  if (x1 < SCREEN_LEFT) and (x2 < SCREEN_LEFT) then
    exit;
  if (x1 > SCREEN_RIGHT) and (x2 > SCREEN_RIGHT) then
    exit;

  IsRegionInScreen := true;
end;

function IsRegionInClipRegion(x1, y1, x2, y2: integer) : boolean;
{ returns true if the given region is partially or completely within the
  current clipping region }
begin
  IsRegionInClipRegion := false;

  if (y1 < ClipRegionTop) and (y2 < ClipRegionTop) then
    exit;
  if (y1 > ClipRegionBottom) and (y2 > ClipRegionBottom) then
    exit;
  if (x1 < ClipRegionLeft) and (x2 < ClipRegionLeft) then
    exit;
  if (x1 > ClipRegionRight) and (x2 > ClipRegionRight) then
    exit;

  IsRegionInClipRegion := true;
end;

function ClampToScreen(var x1, y1, x2, y2: integer) : boolean;
{ if the given region is visible on screen (either partially or completely)
  the coordinates are checked individually against each edge of the screen
  and adjusted if need-be to keep them within bounds. if the region is not
  visible at all, then nothing is changed and false is returned. }
begin
  ClampToScreen := false;

  if (not IsRegionInScreen(x1, y1, x2, y2)) then
    exit;

  { we now know the given region is at least partially visible }
  ClampToScreen := true;

  if (y1 < SCREEN_TOP) then
    y1 := SCREEN_TOP;
  if (y1 > SCREEN_BOTTOM) then
    y1 := SCREEN_BOTTOM;
  if (y2 < SCREEN_TOP) then
    y2 := SCREEN_TOP;
  if (y2 > SCREEN_BOTTOM) then
    y2 := SCREEN_BOTTOM;
  if (x1 < SCREEN_LEFT) then
    x1 := SCREEN_LEFT;
  if (x1 > SCREEN_RIGHT) then
    x1 := SCREEN_RIGHT;
  if (x2 < SCREEN_LEFT) then
    x2 := SCREEN_LEFT;
  if (x2 > SCREEN_RIGHT) then
    x2 := SCREEN_RIGHT;
end;

function ClampToClipRegion(var x1, y1, x2, y2: integer) : boolean;
{ if the given region is within the current clipping region (either
  partially or completely) the coordinates are checked individually
  against each edge of the clipping region and adjusted if need-be to keep
  them within bounds. if the region is not visible at all, then nothing is
  changed and false is returned. }
begin
  ClampToClipRegion := false;

  if (not IsRegionInClipRegion(x1, y1, x2, y2)) then
    exit;

  { we now know the given region is at least partially visible }
  ClampToClipRegion := true;

  if (y1 < ClipRegionTop) then
    y1 := ClipRegionTop;
  if (y1 > ClipRegionBottom) then
    y1 := ClipRegionBottom;
  if (y2 < ClipRegionTop) then
    y2 := ClipRegionTop;
  if (y2 > ClipRegionBottom) then
    y2 := ClipRegionBottom;
  if (x1 < ClipRegionLeft) then
    x1 := ClipRegionLeft;
  if (x1 > ClipRegionRight) then
    x1 := ClipRegionRight;
  if (x2 < ClipRegionLeft) then
    x2 := ClipRegionLeft;
  if (x2 > ClipRegionRight) then
    x2 := ClipRegionRight;
end;

function ClipToScreen(var x, y, width, height: integer) : boolean;
{ clips a region to the screen by adjusting the top-left x,y coordinate
  and/or the width/height of the region as appropriate. returns false if a
  "completely out of bounds" scenario was encountered. returns true if the
  region was completely in bounds (no clipping/clamping needed) or if the
  region was clipped to the screen and is still partially in bounds. }
var
  right, bottom, offset : integer;
begin
  ClipToScreen := false;

  right  := x + width - 1;
  bottom := y + height - 1;

  { off the left edge? }
  if x < SCREEN_LEFT then begin
    { completely off the left edge? }
    if right < SCREEN_LEFT then
      exit;

    offset := SCREEN_LEFT - x;
    inc(x, offset);
    dec(width, offset);
  end;

  { off the right edge? }
  if x > (SCREEN_WIDTH - width) then begin
    { completely off the right edge? }
    if x > SCREEN_RIGHT then
      exit;

    offset := x + width - SCREEN_WIDTH;
    dec(width, offset);
  end;

  { off the top edge? }
  if y < SCREEN_TOP then begin
    { completely off the top edge? }
    if bottom < SCREEN_TOP then
      exit;

    offset := SCREEN_TOP - y;
    inc(y, offset);
    dec(height, offset);
  end;

  { off the bottom edge? }
  if y > (SCREEN_HEIGHT - height) then begin
    { completely off the bottom edge? }
    if y > SCREEN_BOTTOM then
      exit;

    offset := y + height - SCREEN_HEIGHT;
    dec(height, offset);
  end;

  ClipToScreen := true;
end;

function ClipToClipRegion(var x, y, width, height: integer) : boolean;
{ clips a region to the current clipping region by adjusting the top-left
  x,y coordinate and/or the width/height of the region as appropriate.
  returns false if a "completely out of bounds" scenario was encountered.
  returns true if the region was completely in bounds (no clipping/clamping
  needed) or if the region was clipped to the clipping region and is still
  partially in bounds. }
var
  right, bottom, offset : integer;
begin
  ClipToClipRegion := false;

  right  := x + width - 1;
  bottom := y + height - 1;

  { off the left edge? }
  if x < ClipRegionLeft then begin
    { completely off the left edge? }
    if right < ClipRegionLeft then
      exit;

    offset := ClipRegionLeft - x;
    inc(x, offset);
    dec(width, offset);
  end;

  { off the right edge? }
  if (x - ClipRegionLeft) > (ClipRegionWidth - width) then begin
    { completely off the right edge? }
    if x > ClipRegionRight then
      exit;

    offset := (x - ClipRegionLeft) + (width - ClipRegionWidth);
    dec(width, offset);
  end;

  { off the top edge? }
  if y < ClipRegionTop then begin
    { completely off the top edge? }
    if bottom < ClipRegionTop then
      exit;

    offset := ClipRegionTop - y;
    inc(y, offset);
    dec(height, offset);
  end;

  { off the bottom edge? }
  if (y - ClipRegionTop) > (ClipRegionHeight - height) then begin
    { completely off the bottom edge? }
    if y > ClipRegionBottom then
      exit;

    offset := (y - ClipRegionTop) + (height - ClipRegionHeight);
    dec(height, offset);
  end;

  ClipToClipRegion := true;
end;

function ClipBlitToScreen(var srcX, srcY: integer;
                          var srcWidth, srcHeight: integer;
                          var destX, destY: integer) : boolean;
{ clips a source bitmap blit region to the screen by adjusting the source
  blit region and the destination x,y coordinate as appropriate.
  returns false if a "completely out of bounds" scenario was encountered.
  returns true if the region was either completely in bounds (no
  clipping/clamping needed), or if the region was clipped to the screen
  and is still partially in bounds. }
var
  right, bottom, offset : integer;
begin
  ClipBlitToScreen := false;

  right  := srcX + srcWidth - 1;
  bottom := srcY + srcHeight - 1;

  { off the left edge? }
  if destX < SCREEN_LEFT then begin
    { completely off the left edge? }
    if (destX + srcWidth - 1) < SCREEN_LEFT then
      exit;

    offset := srcX - destX;
    destX  := SCREEN_LEFT;
    inc(srcX, offset);
    dec(srcWidth, offset);
  end;

  { off the right edge? }
  if destX > (SCREEN_WIDTH - srcWidth) then begin
    { completely off the right edge? }
    if destX > SCREEN_RIGHT then
      exit;

    offset := destX + srcWidth - SCREEN_WIDTH;
    dec(srcWidth, offset);
  end;

  { off the top edge? }
  if destY < SCREEN_TOP then begin
    { completely off the top edge? }
    if (destY + srcHeight - 1) < SCREEN_TOP then
      exit;

    offset := srcY - destY;
    destY  := SCREEN_TOP;
    inc(srcY, offset);
    dec(srcHeight, offset);
  end;

  { off the bottom edge? }
  if destY > (SCREEN_HEIGHT - srcHeight) then begin
    { completely off the bottom edge? }
    if destY > SCREEN_BOTTOM then
      exit;

    offset := destY + srcHeight - SCREEN_HEIGHT;
    dec(srcHeight, offset);
  end;

  ClipBlitToScreen := true;
end;

function ClipBlitToClipRegion(var srcX, srcY: integer;
                              var srcWidth, srcHeight: integer;
                              var destX, destY: integer) : boolean;
{ clips a source bitmap blit region to the current clipping region by
  adjusting the source blit region and the destination x,y coordinate as
  appropriate.
  returns false if a "completely out of bounds" scenario was encountered.
  returns true if the region was either completely in bounds (no
  clipping/clamping needed), or if the region was clipped to the clipping
  region and is still partially in bounds. }
var
  right, bottom, offset : integer;
begin
  ClipBlitToClipRegion := false;

  right  := srcX + srcWidth - 1;
  bottom := srcY + srcHeight - 1;

  { off the left edge? }
  if destX < ClipRegionLeft then begin
    { completely off the left edge? }
    if (destX + srcWidth - 1) < ClipRegionLeft then
      exit;

    offset := srcX - destX;
    destX  := ClipRegionLeft;
    inc(srcX, offset);
    dec(srcWidth, offset);
  end;

  { off the right edge? }
  if destX > (ClipRegionWidth - srcWidth) then begin
    { completely off the right edge? }
    if destX > ClipRegionRight then
      exit;

    offset := destX + srcWidth - ClipRegionWidth;
    dec(srcWidth, offset);
  end;

  { off the top edge? }
  if destY < ClipRegionTop then begin
    { completely off the top edge? }
    if (destY + srcHeight - 1) < ClipRegionTop then
      exit;

    offset := srcY - destY;
    destY  := ClipRegionTop;
    inc(srcY, offset);
    dec(srcHeight, offset);
  end;

  { off the bottom edge? }
  if destY > (ClipRegionHeight - srcHeight) then begin
    { completely off the bottom edge? }
    if destY > ClipRegionBottom then
      exit;

    offset := destY + srcHeight - ClipRegionHeight;
    dec(srcHeight, offset);
  end;

  ClipBlitToClipRegion := true;
end;

end.
