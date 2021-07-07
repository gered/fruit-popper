unit Results;

interface

procedure DoResults;

implementation

uses GDGfx, GDKeybrd, GDTimer, GDEvents, Assets, Draw, Entities, Shared;

procedure DrawResults;
var
  uiFrame                : ^UIFrameBitmaps;
  playerTile, fruitTile  : word;
  c                      : color;
  s                      : string[3];
  player1win, player2win : boolean;
begin
  Cls(0);

  BlitSpritef(98, 10, titleResults);
  UseFont(@fnt);

  if player1.score > player2.score then begin
    DrawString(120, 60, 15, 'Player 1 Wins!');
    player1win := true;
    player2win := false;
  end else if player2.score > player1.score then begin
    DrawString(120, 60, 15, 'Player 2 Wins!');
    player1win := false;
    player2win := true;
  end else begin
    DrawString(130, 60, 16, 'It''s A Tie!');
    player1win := false;
    player2win := false;
  end;


  if player1Selection = Tomato then begin
    uiFrame    := @uiTomatoFrame;
    playerTile := PLAYER_TOMATO_TILE_START;
    fruitTile  := FRUIT_TOMATO_TILE_START;
    c          := TOMATO_TEXT_COLOR;
  end else begin
    uiFrame    := @uiGrapesFrame;
    playerTile := PLAYER_GRAPES_TILE_START;
    fruitTile  := FRUIT_GRAPES_TILE_START;
    c          := GRAPES_TEXT_COLOR;
  end;

  if player1win then
    inc(playerTile, 16)
  else if player2win then
    inc(playerTile, 17);

  UseFont(@fnt);
  DrawUIFrame(60, 90, 64, 64, uiFrame^);
  DrawString(68, 98, 15, 'Player 1');
  BlitSpritef(72, 122, sprites[playerTile]);
  BlitSpritef(72+16+8, 122, sprites[fruitTile]);
  UseFont(@chunkyFnt);
  Str(player1.score:3, s);
  DrawStringf(72+16+8, 132, c, s);

  if player2Selection = Tomato then begin
    uiFrame    := @uiTomatoFrame;
    playerTile := PLAYER_TOMATO_TILE_START;
    fruitTile  := FRUIT_TOMATO_TILE_START;
    c          := TOMATO_TEXT_COLOR;
  end else begin
    uiFrame    := @uiGrapesFrame;
    playerTile := PLAYER_GRAPES_TILE_START;
    fruitTile  := FRUIT_GRAPES_TILE_START;
    c          := GRAPES_TEXT_COLOR;
  end;

  if player2win then
    inc(playerTile, 16)
  else if player1win then
    inc(playerTile, 17);

  UseFont(@fnt);
  DrawUIFrame(196, 90, 64, 64, uiFrame^);
  DrawString(204, 98, 15, 'Player 2');
  BlitSpritef(208, 122, sprites[playerTile]);
  BlitSpritef(208+16+8, 122, sprites[fruitTile]);
  UseFont(@chunkyFnt);
  Str(player2.score:3, s);
  DrawStringf(208+16+8, 132, c, s);


  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure DoResults;
var
  quit    : boolean;
  event   : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  DrawResults;
  FadeIn;
  InitEvents;

  quit    := false;
  while not quit do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ESC) then quit := true;
      if IsKeyReleasedEvent(event, KEY_ENTER) then quit := true;
    end;

    DrawResults;
  end;

  CloseEvents;
  FadeOut;

  currentGameState := StateMainMenu;
end;

end.
