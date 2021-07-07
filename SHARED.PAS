{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Shared;

interface

uses FixedP, Entities;

const
  TIMER_FREQ                 = 1000;
  TIMER_FREQ_FP              = trunc(TIMER_FREQ * FP_FLOAT_SHIFT);

  TARGET_FPS                 = 70;
  TARGET_FRAME_TICKS         = TIMER_FREQ / TARGET_FPS;

  TILE_SIZE                  = 16;
  ENTITY_SIZE                = 16;

  BACKBUFFER_LAYER           = 1;

  MAX_PARTICLES              = 32;

  PLAYER_TOMATO_TILE_START   = 40;
  PLAYER_GRAPES_TILE_START   = 60;
  PLAYER_NEUTRAL_TILE        = 80;
  FRUIT_TOMATO_TILE_START    = 0;
  FRUIT_GRAPES_TILE_START    = 1;
  SPLASH_TOMATO_TILE_START   = 10;
  SPLASH_GRAPES_TILE_START   = 20;

  GOLD_FRUIT_TILE_OFFSET     = 2;

  TOMATO_TACK_TILE_START     = 16;
  GRAPES_TACK_TILE_START     = 26;

  TOMATO_THUMBTACK_TILE      = 6;
  GRAPES_THUMBTACK_TILE      = 7;

  TIMER_SPRITE               = 39;

  HEAD_TO_HEAD_TILE          = 5;

  TOMATO_SCORE_UP_TILE       = 8;
  GRAPES_SCORE_UP_TILE       = 9;

  OW_TILE                    = 38;

  TOMATO_TEXT_COLOR          = 224;
  GRAPES_TEXT_COLOR          = 160;
  DEBUFF_TEXT_COLOR          = 67;
  PLANT_TEXT_COLOR           = 96;

  GOLD_FRUIT_SPAWN_CHANCE    = 5;

type
  GameState = (StateMainMenu,
               StateLevelSelect,
               StateFruitSelect,
               StateHelp,
               StateMatch,
               StateResults,
               StateQuit);

var
  currentGameState           : GameState;

  selectedMap                : string[12];
  player1Selection           : FruitKind;
  player2Selection           : FruitKind;

  frameTicks                 : word;
  fruitSpawnTimer            : word;

  player1, player2           : Player;
  tomatoPlayer               : PPlayer;
  grapesPlayer               : PPlayer;

  playerAnimations           : array[0..ord(Defeat)] of AnimationDesc;
  playerSpriteOffsets        : array[0..ord(Grapes)] of word;
  thumbTackSpriteOffsets     : array[0..ord(Grapes)] of word;
  thumbTackRenderOffsetsX    : array[0..ord(West)] of integer;
  thumbTackRenderOffsetsY    : array[0..ord(West)] of integer;
  thumbTackPointOffsetsX     : array[0..ord(West)] of integer;
  thumbTackPointOffsetsY     : array[0..ord(West)] of integer;

  fruitAnimations            : array[0..ord(Popped)] of AnimationDesc;
  fruitSpriteOffsets         : array[0..ord(Grapes)] of word;
  splashSpriteOffsets        : array[0..ord(Grapes)] of word;

  particles                  : array[0..(MAX_PARTICLES-1)] of Particle;

  tomatoSplashAnimation      : AnimationDesc;
  grapesSplashAnimation      : AnimationDesc;
  stabFlashAnimation         : AnimationDesc;
  plantDestroyAnimation      : AnimationDesc;
  tomatoScoreUpAnimation     : AnimationDesc;
  grapesScoreUpAnimation     : AnimationDesc;
  owAnimation                : AnimationDesc;

  isStatusBackdropDirty      : boolean;

  matchTime                  : longint;

implementation

uses Toolbox;

begin
  { defaults for convenient testing purposes during development ... }
  selectedMap := 'test.map';
  player1Selection := Tomato;
  player2Selection := Grapes;


  playerSpriteOffsets[ord(Tomato)] := PLAYER_TOMATO_TILE_START;
  playerSpriteOffsets[ord(Grapes)] := PLAYER_GRAPES_TILE_START;

  thumbTackSpriteOffsets[ord(Tomato)] := TOMATO_TACK_TILE_START;
  thumbTackSpriteOffsets[ord(Grapes)] := GRAPES_TACK_TILE_START;

  thumbTackRenderOffsetsX[ord(North)] := 5;
  thumbTackRenderOffsetsY[ord(North)] := -5;
  thumbTackRenderOffsetsX[ord(South)] := -3;
  thumbTackRenderOffsetsY[ord(South)] := 8;
  thumbTackRenderOffsetsX[ord(West)] := -8;
  thumbTackRenderOffsetsY[ord(West)] := 2;
  thumbTackRenderOffsetsX[ord(East)] := 8;
  thumbTackRenderOffsetsY[ord(East)] := 3;

  thumbTackPointOffsetsX[ord(North)] := 7;
  thumbTackPointOffsetsY[ord(North)] := 3;
  thumbTackPointOffsetsX[ord(South)] := 7;
  thumbTackPointOffsetsY[ord(South)] := 12;
  thumbTackPointOffsetsX[ord(West)] := 2;
  thumbTackPointOffsetsY[ord(West)] := 8;
  thumbTackPointOffsetsX[ord(East)] := 13;
  thumbTackPointOffsetsY[ord(East)] := 8;

  fruitSpriteOffsets[ord(Tomato)] := FRUIT_TOMATO_TILE_START;
  fruitSpriteOffsets[ord(Grapes)] := FRUIT_GRAPES_TILE_START;

  splashSpriteOffsets[ord(Tomato)] := SPLASH_TOMATO_TILE_START;
  splashSpriteOffsets[ord(Grapes)] := SPLASH_GRAPES_TILE_START;

  MemFill(@particles, 0, SizeOf(particles));

  MemFill(@playerAnimations, 0, SizeOf(playerAnimations));

  with playerAnimations[ord(Idle)] do begin
    frames[0] := 0;
    count     := 1;
    delay     := 0;
    loops     := true;
    base      := 0;
    dirLength := 3;
  end;

  with playerAnimations[ord(Walking)] do begin
    frames[0] := 1;
    frames[1] := 0;
    frames[2] := 2;
    frames[3] := 0;
    count     := 4;
    delay     := 80;
    loops     := true;
    base      := 0;
    dirLength := 3;
    time      := count * delay;
  end;

  with playerAnimations[ord(Stabbing)] do begin
    frames[0] := 0;
    count     := 1;
    delay     := 160;
    base      := 12;
    dirLength := 1;
    loops     := false;
    time      := count * delay;
  end;

  with playerAnimations[ord(Victory)] do begin
    frames[0] := 0;
    count     := 1;
    delay     := 0;
    loops     := true;
    base      := 16;
    dirLength := 0;
  end;

  with playerAnimations[ord(Defeat)] do begin
    frames[0] := 0;
    count     := 1;
    delay     := 0;
    loops     := true;
    base      := 17;
    dirLength := 0;
  end;


  MemFill(@fruitAnimations, 0, SizeOf(fruitAnimations));

  with fruitAnimations[ord(Plant)] do begin
    frames[0] := 0;
    count     := 1;
    loops     := true;
    base      := 4;
  end;

  with fruitAnimations[ord(Growing)] do begin
    frames[0] := 0;
    count     := 1;
    loops     := false;
    base      := 0;
  end;

  with fruitAnimations[ord(Grown)] do begin
    frames[0] := 0;
    count     := 1;
    loops     := true;
    base      := 0;
  end;

  with fruitAnimations[ord(Popped)] do begin
    frames[0] := 0;
    count     := 1;
    loops     := false;
    delay     := 240;
    base      := 0;
  end;


  MemFill(@tomatoSplashAnimation, 0, SizeOf(tomatoSplashAnimation));
  with tomatoSplashAnimation do begin
    base      := 10;
    frames[0] := 0;
    frames[1] := 1;
    frames[2] := 2;
    frames[3] := 3;
    frames[4] := 4;
    frames[5] := 5;
    count     := 6;
    delay     := 80;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@grapesSplashAnimation, 0, SizeOf(grapesSplashAnimation));
  with grapesSplashAnimation do begin
    base      := 20;
    frames[0] := 0;
    frames[1] := 1;
    frames[2] := 2;
    frames[3] := 3;
    frames[4] := 4;
    frames[5] := 5;
    count     := 6;
    delay     := 80;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@stabFlashAnimation, 0, SizeOf(stabFlashAnimation));
  with stabFlashAnimation do begin
    base      := 30;
    frames[0] := 0;
    frames[1] := 1;
    frames[2] := 2;
    count     := 3;
    delay     := 40;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@plantDestroyAnimation, 0, SizeOf(plantDestroyAnimation));
  with plantDestroyAnimation do begin
    base      := 33;
    frames[0] := 0;
    frames[1] := 1;
    frames[2] := 2;
    count     := 3;
    delay     := 60;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@tomatoScoreUpAnimation, 0, SizeOf(tomatoScoreUpAnimation));
  with tomatoScoreUpAnimation do begin
    base      := TOMATO_SCORE_UP_TILE;
    frames[0] := 0;
    count     := 1;
    delay     := 2000;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@grapesScoreUpAnimation, 0, SizeOf(grapesScoreUpAnimation));
  with grapesScoreUpAnimation do begin
    base      := GRAPES_SCORE_UP_TILE;
    frames[0] := 0;
    count     := 1;
    delay     := 2000;
    loops     := false;
    time      := count * delay;
  end;

  MemFill(@owAnimation, 0, SizeOf(owAnimation));
  with owAnimation do begin
    base      := OW_TILE;
    frames[0] := 0;
    count     := 1;
    delay     := 1000;
    loops     := false;
    time      := count * delay;
  end;
end.
