{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Draw;

interface

uses GDGfx, Entities, Assets;

procedure DrawMap;
procedure DrawPlayer(const player : Player);
procedure DrawAllFruit;
procedure DrawAllParticles;
procedure DrawGameStatusBackdrop;
procedure DrawPlayerStatuses;
procedure DrawMatchStatus;
procedure DrawBackdrop;

procedure DrawUIFrame(x1, y1, width, height : integer;
                      const frameBitmaps : UIFrameBitmaps);

procedure FadeOut;
procedure FadeIn;
procedure FadeOutAndIn(delay : word);
procedure BlackOutPalette;

procedure BlitSpriteScaled(x, y: integer; xs, ys: word; const bmp: PBitmap);

implementation

uses GDTimer, FixedP, Toolbox, Maps, Shared;

const
  TOMATO_X                   = 0;
  GRAPES_X                   = 208;
  GENERAL_X                  = 112;
  STATUS_Y                   = 176;

procedure DrawMap;
var
  x, y           : word;
  currentMapTile : ^byte;
  oldLayer       : integer;
begin
  oldLayer := GetBoundLayerIndex;
  UseLayer(SCREEN_MAP_LAYER);

  currentMapTile := @map.map[0];
  for y := 0 to 10 do begin
    for x := 0 to 19 do begin
      Blitf(x*16, y*16, tiles[currentMapTile^]);
      inc(currentMapTile);
    end;
  end;

  UseLayer(oldLayer);
  isMapDirty := false;
end;

procedure DrawPlayer(const player : Player);
var
  playerIndex, thumbTackIndex : word;
  tx, ty  : integer;
  dir     : Direction;
  fruit   : FruitKind;
  skip    : boolean;
begin
  with player do begin
    dir   := entity.direction;
    fruit := fruitPref;

    skip  := ((stabbedDebuffTime > 0) or (splashedDebuffTime > 0)) and skipRenderFlag;

    { compute the current final sprite index from the player's
      current animation state and facing direction.
      note that this value still needs to be added to playerSpriteOffsets
      to get the real final sprite index for the correct player sprite set
      (based on the player's chosen fruit type). }
    playerIndex := GetAnimationFrame(
      entity.animation,
      playerAnimations[ord(state)],
      dir
    );

    { if the player is currently stabbing, then also get the thumbtack
      sprite index to use }
    if state = Stabbing then begin
      thumbTackIndex := ord(dir) + thumbTackSpriteOffsets[ord(fruit)];
    end;
  end;

  with player.entity.position do begin
    if player.state = Stabbing then begin
      { the player is currently stabbing with their thumb tack, so we
        need to render the thumb tack sprite too. the exact position
        of the thumb tack sprite varies depending on the player's
        facing direction (so as to position it in the player's hand) }
      GetThumbTackRenderCoords(player, tx, ty);

      if dir = North then begin
        { if we're facing north, the thumb tack sprite should be
          rendered first, so that it is layered underneath the player
          sprite }
        BlitSpritef(tx, ty, sprites[thumbTackIndex]);

        if not skip then
          BlitSpritef(
            FixToInt(x),
            FixToInt(y),
            sprites[playerIndex + playerSpriteOffsets[ord(fruit)]]
          );
      end else begin
        { but for every other direction, render the thumb tack sprite
          layered on top of the player sprite }
        if not skip then
          BlitSpritef(
            FixToInt(x),
            FixToInt(y),
            sprites[playerIndex + playerSpriteOffsets[ord(fruit)]]
          );

        BlitSpritef(tx, ty, sprites[thumbTackIndex]);
      end;
    end else begin
      { not stabbing, so just render the player sprite itself }
      if not skip then
        BlitSpritef(
          FixToInt(x),
          FixToInt(y),
          sprites[playerIndex + playerSpriteOffsets[ord(fruit)]]
        );
    end;
  end;
end;

procedure DrawAllFruit;
var
  i, index      : word;
  value, offset : integer;
begin
  for i := 0 to numDirtTiles-1 do begin
    with dirtTiles[i] do begin
      if not hasFruit then continue;

      { compute the final sprite index of the fruit based on its current
        animation. note that not all states of the fruit entity actually
        use real "animations" ... some are just an animation sequence of
        1 frame, and is just being abused to fit into this general
        framework ... :-) }
      with fruit do begin
        index := GetAnimationFrame(
          entity.animation,
          fruitAnimations[ord(state)],
          South
        );
      end;

      case fruit.state of
        Plant: begin
            { just a simple plant }
            with fruit.entity.position do begin
              BlitSpritef(FixToInt(x), FixToInt(y), sprites[index]);
            end;
          end;

        Growing: begin
            { render the fruit sprite, scaled. }
            if fruit.isGold then inc(index, GOLD_FRUIT_TILE_OFFSET);

            with fruit.entity.position do begin
              value  := fruit.value;  { the pixel width/height of the
                                        fruit sprite }
              offset := 8-(value div 2); { the x/y coordinate offset used
                                           to center the fruit sprite
                                           within the map tile it is on }

              BlitSpriteScaled(
                FixToInt(x) + offset,
                FixToInt(y) + offset,
                value,
                value,
                sprites[index + fruitSpriteOffsets[ord(fruit.kind)]]
              );
            end;
          end;

        Grown, Popped: begin
            { render the fruit sprite }
            if fruit.isGold then inc(index, GOLD_FRUIT_TILE_OFFSET);

            with fruit.entity.position do begin
              BlitSpritef(
                FixToInt(x),
                FixToInt(y),
                sprites[index + fruitSpriteOffsets[ord(fruit.kind)]]
              );
            end;
          end;
      end;
    end;
  end;
end;

procedure DrawAllParticles;
var
  i, index : word;
begin
  for i := 0 to MAX_PARTICLES-1 do begin
    with particles[i] do begin
      if not active then continue;

      if animation <> nil then begin
        { particle is a "sprite-animated" particle type. get its current
          "final" sprite index based on its animation state }
        index := GetAnimationFrame(
          entity.animation,
          animation^,
          entity.direction
        );

        with entity.position do begin
          BlitSpritef(FixToInt(x), FixToInt(y), sprites[index]);
        end;

      end else begin
        { TODO: "pixel" particle types ... }

      end;
    end;
  end;
end;

procedure DrawGameStatusBackdrop;
var
  i, oldLayer : integer;
begin
  oldLayer := GetBoundLayerIndex;
  UseLayer(SCREEN_MAP_LAYER);

  { tomato player status }
  DrawUIFrame(TOMATO_X, STATUS_Y, 112, 24, uiTomatoFrame);
  BlitSpritef(TOMATO_X+8, STATUS_Y+4, sprites[PLAYER_TOMATO_TILE_START]);
  BlitSpritef(TOMATO_X+28, STATUS_Y+4, sprites[FRUIT_TOMATO_TILE_START]);


  { grapes player status }
  DrawUIFrame(GRAPES_X, STATUS_Y, 112, 24, uiGrapesFrame);
  BlitSpritef((SCREEN_RIGHT-16)-8, STATUS_Y+4, sprites[PLAYER_GRAPES_TILE_START]);
  BlitSpritef((SCREEN_RIGHT-16)-28, STATUS_Y+4, sprites[FRUIT_GRAPES_TILE_START]);


  { general match info }
  DrawUIFrame(GENERAL_X, STATUS_Y, 96, 24, uiGeneralFrame);

  UseLayer(oldLayer);
  isStatusBackdropDirty := false;
end;

procedure DrawPlayerStatuses;
const
  TEXT_Y = STATUS_Y+13;
var
  x, value : integer;
  s        : string[3];
begin
  UseFont(@chunkyFnt);

  with tomatoPlayer^ do begin
    { number of popped tomatoes }
    Str(score:3, s);
    DrawStringf(TOMATO_X+28, TEXT_Y, TOMATO_TEXT_COLOR, s);

    x := TOMATO_X+56;

    { 'stabbed' debuff icon and time left }
    if stabbedDebuffTime > 0 then begin
      BlitSpritef(x, STATUS_Y+4, sprites[GRAPES_THUMBTACK_TILE]);

      value := stabbedDebuffTime div 1000;
      Str(value:3, s);
      DrawStringf(x, TEXT_Y, DEBUFF_TEXT_COLOR, s);

      inc(x, 28);
    end;


    { 'splashed' debuff icon and time left }
    if splashedDebuffTime > 0 then begin
      BlitSpritef(x, STATUS_Y+4, sprites[SPLASH_GRAPES_TILE_START]);

      value := splashedDebuffTime div 1000;
      Str(value:3, s);
      DrawStringf(x, TEXT_Y, DEBUFF_TEXT_COLOR, s);
    end;
  end;

  with grapesPlayer^ do begin
    { number of popped tomatoes }
    Str(score:3, s);
    DrawStringf(GRAPES_X+67, TEXT_Y, GRAPES_TEXT_COLOR, s);

    x := GRAPES_X+67-28;

    { 'stabbed' debuff icon and time left }
    if stabbedDebuffTime > 0 then begin
      BlitSpritef(x, STATUS_Y+4, sprites[TOMATO_THUMBTACK_TILE]);

      value := stabbedDebuffTime div 1000;
      Str(value:3, s);
      DrawStringf(x, TEXT_Y, DEBUFF_TEXT_COLOR, s);

      dec(x, 28);
    end;


    { 'splashed' debuff icon and time left }
    if splashedDebuffTime > 0 then begin
      BlitSpritef(x, STATUS_Y+4, sprites[SPLASH_TOMATO_TILE_START]);

      value := splashedDebuffTime div 1000;
      Str(value:3, s);
      DrawStringf(x, TEXT_Y, DEBUFF_TEXT_COLOR, s);
    end;
  end;

  UseFont(nil);
end;

procedure DrawMatchStatus;
var
  totalSeconds, minutes, seconds, seconds10 : word;
  s : string[2];
begin
  BlitSpritef(GENERAL_X+8, STATUS_Y+4, sprites[TIMER_SPRITE]);

  UseFont(nil);
  PrintAt(GENERAL_X+8+16+6, STATUS_Y+8);

  totalSeconds := matchTime div 1000;
  minutes := totalSeconds div 60;
  seconds := totalSeconds mod 60;
  seconds10 := (matchTime mod 1000) div 100;

  Str(minutes:2, s);
  PrintString(s, 15);

  PrintString(':', 15);

  if seconds < 10 then PrintString('0', 15);
  PrintWord(seconds, 15);

  PrintString('.', 15);
  PrintWord(seconds10, 15);
end;

procedure DrawBackdrop;
begin
  if isMapDirty then DrawMap;
  if isStatusBackdropDirty then DrawGameStatusBackdrop;

  CopyLayer(SCREEN_MAP_LAYER);
end;

procedure DrawUIFrame(x1, y1, width, height : integer;
                      const frameBitmaps : UIFrameBitmaps);
var
  i, n, x, y                 : integer;
  middleTilesX, middleTilesY : integer;
begin
  { TODO: this drawing routine will not look so great with dimensions
          that are not some multiple of 8 (both width and height) ... }
  { smallest reasonable dimensions that could really work given
    the tiles we're currently using for these ... }
  if width < 24 then width := 24;
  if height < 24 then height := 24;

  middleTilesX := (width - (2*8)) div 8;
  if middleTilesX < 0 then middleTilesX := 0;
  middleTilesY := (height - (2*8)) div 8;
  if middleTilesY < 0 then middleTilesY := 0;

  { middle }
  for y := 0 to middleTilesY-1 do begin
    for x := 0 to middleTilesX-1 do begin
      Blitf(x1+8+(x*8), y1+8+(y*8), frameBitmaps[4]);
    end;
  end;

  { top and bottom border }
  for i := 0 to middleTilesX-2 do begin
    Blitf(x1+16+(i*8), y1, frameBitmaps[1]);
    Blitf(x1+16+(i*8), y1+height-8, frameBitmaps[7]);
  end;

  { left and right borders }
  for i := 0 to middleTilesY-2 do begin
    Blitf(x1, y1+16+(i*8), frameBitmaps[3]);
    Blitf(x1+width-8, y1+16+(i*8), frameBitmaps[5]);
  end;

  { top-left corner }
  BlitSpritef(x1, y1, frameBitmaps[0]);

  { bottom-left corner }
  BlitSpritef(x1, y1+height-16, frameBitmaps[6]);

  { top-right corner }
  BlitSpritef(x1+width-16, y1, frameBitmaps[2]);

  { bottom-right corner }
  BlitSpritef(x1+width-16, y1+height-16, frameBitmaps[8]);
end;

{ ----------------------------------------------------------------------- }

procedure FadeOut;
begin
  FadeRangeToColor(0, 255, 0, 0, 0, 4);
end;

procedure FadeIn;
begin
  FadeRangeToPalette(0, 255, @pal, 4);
end;

procedure FadeOutAndIn(delay : word);
var
  elapsed : word;
begin
  FadeRangeToColor(0, 255, 0, 0, 0, 4);
  if delay > 0 then begin
    elapsed := 0;
    MarkTimer;
    while elapsed < delay do begin
      inc(elapsed, MarkTimer);
    end;
  end;
  FadeRangeToPalette(0, 255, @pal, 4);
end;

procedure BlackOutPalette;
begin
  FadeRangeToColor(0, 255, 0, 0, 0, 255);
end;

{ ----------------------------------------------------------------------- }

procedure BlitSpriteScaled(x, y: integer; xs, ys: word; const bmp: PBitmap);
var
  width, height         : word;
  xStep, yStep          : fixed;
  xIndex, yIndex        : fixed;
  srcOffset, destOffset : word;
  src, dest             : PByteArray;
  dx, dy                : integer;
  pixel                 : byte;
begin
  { TODO: clipping support }
  { TODO: re-write the render loop in assembly }

  width      := bmp^.Width;
  height     := bmp^.Height;

  xStep      := FixDiv(IntToFix(width), IntToFix(xs));
  yStep      := FixDiv(IntToFix(height), IntToFix(ys));

  dest       := GetBoundLayerPointerAt(x, y);
  destOffset := 0;
  src        := ptr(Seg(bmp^.Pixels), Ofs(bmp^.Pixels));
  srcOffset  := 0;

  yIndex := 0;

  for dy := 0 to (ys-1) do begin
    xIndex := 0;
    for dx := 0 to (xs-1) do begin
      pixel := src^[srcOffset + FixToInt(xIndex)];
      if pixel > 0 then
        dest^[destOffset + dx] := pixel;

      inc(xIndex, xStep);
    end;

    inc(yIndex, yStep);
    inc(destOffset, SCREEN_WIDTH);
    srcOffset := width * FixToInt(yIndex);
  end;
end;

end.
