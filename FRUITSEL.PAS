{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit FruitSel;

interface

procedure DoFruitSelect;

implementation

uses GDGfx, GDKeybrd, GDTimer, GDEvents, Assets, Draw, Entities, Shared;

var
  randomSelection : integer;

procedure DrawFruitSelect;
var
  uiFrame               : ^UIFrameBitmaps;
  playerTile, fruitTile : word;
begin
  Cls(0);

  BlitSpritef(29, 10, titleChooseFruit);

  UseFont(@fnt);
  if randomSelection = -1 then
    DrawString(62, 60, 15, 'Choosing by random selection ...')
  else
    DrawString(92, 60, 15, 'Fruit has been chosen!');

  if randomSelection = -1 then begin
    DrawUIFrame(60, 90, 64, 64, uiGeneralFrame);
    DrawString(68, 98, 15, 'Player 1');
    BlitSpritef(72, 122, sprites[PLAYER_NEUTRAL_TILE]);

    DrawUIFrame(196, 90, 64, 64, uiGeneralFrame);
    DrawString(204, 98, 15, 'Player 2');
    BlitSpritef(208, 122, sprites[PLAYER_NEUTRAL_TILE]);
  end else begin
    if player1Selection = Tomato then begin
      uiFrame    := @uiTomatoFrame;
      playerTile := PLAYER_TOMATO_TILE_START;
      fruitTile  := FRUIT_TOMATO_TILE_START;
    end else begin
      uiFrame    := @uiGrapesFrame;
      playerTile := PLAYER_GRAPES_TILE_START;
      fruitTile  := FRUIT_GRAPES_TILE_START;
    end;

    DrawUIFrame(60, 90, 64, 64, uiFrame^);
    DrawString(68, 98, 15, 'Player 1');
    BlitSpritef(72, 122, sprites[playerTile]);
    BlitSpritef(72+16+8, 122, sprites[fruitTile]);

    if player2Selection = Tomato then begin
      uiFrame    := @uiTomatoFrame;
      playerTile := PLAYER_TOMATO_TILE_START;
      fruitTile  := FRUIT_TOMATO_TILE_START;
    end else begin
      uiFrame    := @uiGrapesFrame;
      playerTile := PLAYER_GRAPES_TILE_START;
      fruitTile  := FRUIT_GRAPES_TILE_START;
    end;

    DrawUIFrame(196, 90, 64, 64, uiFrame^);
    DrawString(204, 98, 15, 'Player 2');
    BlitSpritef(208, 122, sprites[playerTile]);
    BlitSpritef(208+16+8, 122, sprites[fruitTile]);
  end;

  WaitForVsync;
  Flip(BACKBUFFER_LAYER);
end;

procedure DoFruitSelect;
var
  quit    : boolean;
  aborted : boolean;
  event   : PInputEvent;
begin
  UseLayer(BACKBUFFER_LAYER);

  randomSelection := -1;

  DrawFruitSelect;
  FadeIn;
  InitEvents;

  quit    := false;
  aborted := false;
  while not quit do begin
    while not IsEventsEmpty do begin
      event := PollEvents;

      if IsKeyReleasedEvent(event, KEY_ESC) then begin
        quit    := true;
        aborted := true;
      end;

      if IsKeyReleasedEvent(event, KEY_ENTER) then begin
        if randomSelection = -1 then begin
          randomSelection := random(2);
          if randomSelection = 0 then begin
            player1Selection := Tomato;
            player2Selection := Grapes;
          end else begin
            player1Selection := Grapes;
            player2Selection := Tomato;
          end;
        end else
          quit := true;
      end;
    end;

    DrawFruitSelect;
  end;

  CloseEvents;
  FadeOut;

  if (aborted) or (randomSelection = -1) then
    currentGameState := StateMainMenu
  else
    currentGameState := StateMatch;
end;

end.
