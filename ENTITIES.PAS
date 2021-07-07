{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Entities;

interface

uses FixedP, MathFP;

const
  PLAYER_WALK_SPEED          = FP_0_6;
  PLAYER_TACK_PUSH_FORCE     = FP_8;

  ENTITY_FRICTION            = FP_0_2;
  FORCE_FRICTION             = FP_0_7;

  PRICK_RADIUS               = 4;

  SCORE_UP_PARTICLE_SPEED    = -trunc(0.075 * FP_FLOAT_SHIFT);
  OW_PARTICLE_SPEED          = -trunc(0.1 * FP_FLOAT_SHIFT);

  { cooldowns/times are all specified in terms of frame ticks }
  STAB_COOLDOWN              = 80;
  STABBED_DEBUFF_TIME        = 5000;
  SPLASHED_DEBUFF_TIME       = 5000;

type
  Direction = (South, North, East, West);


  { used to statically define an animation sequence }
  AnimationDesc = record
    frames     : array[0..5] of word; { 6 frames total ever ... }
    count      : word; { number of frames (max of 6) }
    delay      : word; { frame timer/delay between switching to next frame }
    time       : word; { total time. = count * delay }
    loops      : bytebool; { true = animation loops }
    base       : word; { spritesheet index of first frame. if
                         multi-directional, this should be the index of the
                         first frame for the south direction }
    dirLength  : word; { number of frames from the start of one direction
                         to the start of the next direction. if not a
                         multi-directional animation, this must be set to 0 }
  end;
  PAnimationDesc = ^AnimationDesc;

  { state needed for a currently running animation sequence. will be used
    in conjunction with an AnimationDesc that defines the animation sequence
    itself }
  AnimationState = record
    complete   : bytebool; { true = current animation sequence is complete }
    frameIndex : word; { index of the current animation sequence frame }
    time       : word; { current frame timer }
  end;
  PAnimationState = ^AnimationState;



  { general entity properties. an instance of this should be included
    in the actual entity's specific record-type. not all entity types
    actually use all of these properties. }
  Entity = record
    position       : Vec2FP;
    velocity       : Vec2FP;
    force          : Vec2FP;
    direction      : Direction;
    animation      : AnimationState;
    noCollision    : bytebool;
  end;


  { particle entity properties. sprite-animation-based particles
    have their lifetime directly linked to the length of the animation.
    TODO: non-sprite-animation-based particles. }
  Particle = record
    active         : bytebool;
    entity         : Entity;
    animation      : PAnimationDesc; { if non-nil, particle is a
                                       sprite-animation-based particle }
  end;


  FruitKind = (Tomato, Grapes);
  FruitState = (Plant, Growing, Grown, Popped);

  { fruit entity properties }
  Fruit = record
    entity         : Entity;
    kind           : FruitKind;
    state          : FruitState;
    { the meaning of these two values depends on the 'state' value }
    counter        : word;
    value          : word;
    isGold         : bytebool;
  end;

  PlayerState = (Idle, Walking, Stabbing, Victory, Defeat);

  { holds player state. duh. }
  Player = record
    entity             : Entity;
    fruitPref          : FruitKind;
    state              : PlayerState;
    stabCooldown       : word;
    stabbedDebuffTime  : word;
    splashedDebuffTime : word;
    skipRenderFlag     : bytebool;
    score              : word;
  end;
  PPlayer = ^Player;


procedure ResetAnimationState(var animation : AnimationState);
function GetAnimationFrame(const state : AnimationState;
                           const desc : AnimationDesc;
                           direction : Direction) : word;
procedure UpdateAnimation(var entity : Entity;
                          const animation : AnimationDesc);

function DoEntitiesOverlap(const a, b : Entity) : boolean;
function DoesEntityOverlap(const entity : Entity;
                           x1, y1, x2, y2 : integer) : boolean;
function IsEntityPositionValid(const entity : Entity) : boolean;
function MoveEntity(var entity : Entity) : boolean;
function IsEntityStopped(const entity : Entity) : boolean;
procedure UpdateEntity(var entity : Entity);

procedure SetPlayerState(var player : Player; state : PlayerState);
procedure GetThumbTackPointCoords(const player : Player; var out_x, out_y : integer);
procedure GetThumbTackRenderCoords(const player : Player; var out_x, out_y : integer);
procedure UpdatePlayer(var player : Player);
procedure InitPlayer(var player : Player; x, y : integer; fruit: FruitKind);
procedure MovePlayer(var player : Player; dir : Direction);
procedure StabPlayer(var player : Player);
procedure DoThumbTackStabAt(px, py : integer; player : PPlayer);

function SpawnRandomFruit : integer;
procedure PopAllFruit(kind : FruitKind; player : PPlayer);
procedure PopFruitAt(x, y : integer; player : PPlayer);
procedure UpdateAllFruit;

function GetUnusedParticleIndex : integer;
function SpawnTomatoSplash(x, y : integer) : integer;
function SpawnGrapesSplash(x, y : integer) : integer;
function SpawnPlantSplash(x, y : integer) : integer;
function SpawnStabFlash(x, y : integer) : integer;
function SpawnScoreUp(x, y : integer; kind : FruitKind) : integer;
function SpawnOw(x, y : integer) : integer;
procedure UpdateAllParticles;


implementation

uses Math, Toolbox, Maps, Assets, Shared;

procedure ResetAnimationState(var animation : AnimationState);
{ resets the given animation state, so it can be used to start an
  animation sequence from the very beginning }
begin
  with animation do begin
    complete   := false;
    frameIndex := 0;
    time       := 0;
  end;
end;

function GetAnimationFrame(const state : AnimationState;
                           const desc : AnimationDesc;
                           direction : Direction) : word;
{ returns the current spritesheet bitmap index that should be blitted
  to draw an entity based on it's animation state and facing direction }
begin
  with desc do begin
    GetAnimationFrame := frames[state.frameIndex]
                          + (ord(direction) * dirLength)
                          + base;
  end;
end;

procedure UpdateAnimation(var entity : Entity;
                          const animation : AnimationDesc);
{ cycles the entity's animation state. the passed AnimationDesc should be
  the corresponding animation descriptor/definition for the animation state
  that the entity is currently in }
begin
  with entity.animation do begin
    if not complete then begin
      inc(time, frameTicks);
      if time >= animation.delay then begin
        { move to next frame in the current animation sequence }
        time := 0;
        if frameIndex = (animation.count-1) then begin
          { we're at the last frame in the current animation sequence }
          if not animation.loops then begin
            complete := true;
          end else
            frameIndex := 0;
        end else
          inc(frameIndex);
      end;
    end;
  end;
end;

{ ------------------------------------------------------------------------ }

function DoEntitiesOverlap(const a, b : Entity) : boolean;
{ returns true if the given entities overlap fully or partially }
const
  EDGE = 2;
var
  ax1, ay1, ax2, ay2 : integer;
  bx1, by1, bx2, by2 : integer;
begin
  DoEntitiesOverlap := false;

  with a.position do begin
    ax1 := FixToInt(x)+EDGE;
    ay1 := FixToInt(y)+EDGE;
    ax2 := ax1 + (ENTITY_SIZE-1)-EDGE;
    ay2 := ay1 + (ENTITY_SIZE-1)-EDGE;
  end;
  with b.position do begin
    bx1 := FixToInt(x)+EDGE;
    by1 := FixToInt(y)+EDGE;
    bx2 := bx1 + (ENTITY_SIZE-1)-EDGE;
    by2 := by1 + (ENTITY_SIZE-1)-EDGE;
  end;

  if (ay1 < by1) and (ay2 < by1) then
    exit;
  if (ay1 > by2) and (ay2 > by2) then
    exit;
  if (ax1 < bx1) and (ax2 < bx1) then
    exit;
  if (ax1 > bx2) and (ax2 > bx2) then
    exit;

  DoEntitiesOverlap := true;
end;

function DoesEntityOverlap(const entity : Entity;
                           x1, y1, x2, y2 : integer) : boolean;
{ returns true if the entity partially or fully overlaps with the given
  area (specified in pixel coordinates) }
const
  EDGE = 2;
var
  ex1, ey1, ex2, ey2 : integer;
begin
  DoesEntityOverlap := false;

  with entity.position do begin
    ex1 := FixToInt(x)+EDGE;
    ey1 := FixToInt(y)+EDGE;
    ex2 := ex1 + (ENTITY_SIZE-1)-EDGE;
    ey2 := ey1 + (ENTITY_SIZE-1)-EDGE;
  end;

  if (ey1 < y1) and (ey2 < y1) then
    exit;
  if (ey1 > y2) and (ey2 > y2) then
    exit;
  if (ex1 < x1) and (ex2 < x1) then
    exit;
  if (ex1 > x2) and (ex2 > x2) then
    exit;

  DoesEntityOverlap := true;
end;

function IsEntityPositionValid(const entity : Entity) : boolean;
{ returns true if the given entity is currently located in a position
  that is "valid", meaning completely free of collisions with anything. }
begin
  IsEntityPositionValid := true;

  with entity.position do begin
    { any collision with the map? either collidable tiles or fruit ... }
    if IsMapCollision(FixToInt(x), FixToInt(y)) then
      IsEntityPositionValid := false

    else begin
      { TODO: this seems a bit clumsy ...? }

      { make sure we don't compare against ourself. since this function
        operates on generic Entity's, we kinda have to check this way }
      if @entity = @player1.entity then begin
        IsEntityPositionValid := (not DoEntitiesOverlap(entity,
                                                        player2.entity));
      end else begin
        IsEntityPositionValid := (not DoEntitiesOverlap(entity,
                                                        player1.entity));
      end;
    end;

  end;
end;

function MoveEntity(var entity : Entity) : boolean;
{ updates the entity's X and Y position based on their current movement
  velocity and any force velocity. checks for map collisions and prevents
  movement along the X and/or Y axis if any collisions are found. returns
  true if the entity collided against something. }
const
  { number of movement+collision sub-steps to divide this movement into }
  NUM_STEPS = 2;

  { reciprocal (also as fixed point) just so that we can use Vec2FP_Scale }
  STEP_SCALE = trunc((1 / NUM_STEPS) * FP_FLOAT_SHIFT);
var
  stepVelocity : Vec2FP;
  i            : integer;
begin
  MoveEntity := false;

  with entity do begin
    { calculate the sub-step velocity for the below loop ... }
    Vec2FP_Add(stepVelocity, velocity, force);
    if (stepVelocity.x = 0) and (stepVelocity.y = 0) then exit;

    { if this entity skips collision checks, just move it and return }
    if noCollision then begin
      Vec2FP_AddTo(position, stepVelocity);
      exit;
    end;

    { we're dividing the movement and collision checks into sub-steps!
      this is a possibly-hacky solution to fix issues with any frame-timings
      that might result in us (without using sub-steps) moving entities
      more than 1 pixel per loop. this could cause problems! e.g. the player
      might not be able to move into a 1-tile-wide gap because their
      movement keeps skipping over 1 pixel too much ... }
    Vec2FP_ScaleThis(stepVelocity, STEP_SCALE);
    for i := 1 to NUM_STEPS do begin
      { add velocity X to player's position, then test for collisions using
        this new position. if a collision occurs, we cannot move the player
        in the X direction by this amount, so we back it out }
      inc(position.x, stepVelocity.x);
      if not IsEntityPositionValid(entity) then begin
        MoveEntity := true;
        dec(position.x, stepVelocity.x);
      end;

      { same thing for the velocity Y now. note that, if no collision occured
        in the X direction, the position that is tested for here will also
        include the velocity X component ... }
      inc(position.y, stepVelocity.y);
      if not IsEntityPositionValid(entity) then begin
        MoveEntity := true;
        dec(position.y, stepVelocity.y);
      end;
    end;
  end;
end;

function IsEntityStopped(const entity : Entity) : boolean;
{ returns true if the entity's movement velocity is slow enough that they
  could be considered stopped. this does not take into account the entity's
  force velocity }
const
  THRESHOLD = trunc(0.05 * FP_FLOAT_SHIFT);
begin
  with entity.velocity do begin
    IsEntityStopped := (abs(x) < THRESHOLD) and (abs(y) < THRESHOLD);
  end;
end;

procedure UpdateEntity(var entity : Entity);
{ updates general entity state. this includes applying velocity/force
  vectors to the entity's position and also applying friction to those
  velocity/force vecotrs too }
begin
  { move entity in the direction of their velocity and any combined force
    that is currently being applied to them. also handles collision. }
  MoveEntity(entity);

  with entity do begin
    { slow both the velocity and force down by friction }
    { TODO: probably for the force vector, we should use something other
            than friction ... ? some per-force specific value maybe? }
    Vec2FP_ScaleThis(velocity, ENTITY_FRICTION);
    Vec2FP_ScaleThis(force, FORCE_FRICTION);
  end;
end;

{ ------------------------------------------------------------------------ }

procedure SetPlayerState(var player : Player; state : PlayerState);
{ switches the player state to the one specified, also resetting the
  player's current animation state }
begin
  if state = player.state then exit;
  player.state := state;
  ResetAnimationState(player.entity.animation);
end;

procedure GetThumbTackPointCoords(const player : Player;
                                  var out_x, out_y : integer);
{ computes the pixel coordinate of where the player's thumb tack's point
  should be (assuming they are currently stabbing). }
var
  dir : Direction;
begin
  { lol, perhaps just computing, say, 8-16 pixels out in a line directly
    centered on the player and outward in their facing direction and using
    that as the point coordinate would be best ... ?
    this all seems silly now that i've written it ... }
  with player.entity do begin
    dir := direction;
    with position do begin
      out_x := FixToInt(x)
               + thumbTackRenderOffsetsX[ord(dir)]
               + thumbTackPointOffsetsX[ord(dir)];
      out_y := FixToInt(y)
               + thumbTackRenderOffsetsY[ord(dir)]
               + thumbTackPointOffsetsY[ord(dir)];
    end;
  end;
end;

procedure GetThumbTackRenderCoords(const player : Player;
                                   var out_x, out_y : integer);
{ computes the pixel coordinate of where the player's thumb tack sprite
  should be (assuming they are currently stabbing). }
var
  dir : Direction;
begin
  with player.entity do begin
    dir := direction;
    with position do begin
      out_x := FixToInt(x) + thumbTackRenderOffsetsX[ord(dir)];
      out_y := FixToInt(y) + thumbTackRenderOffsetsY[ord(dir)];
    end;
  end;
end;

procedure UpdatePlayer(var player : Player);
{ updates player (and general entity) state. this includes entity
  movement, as well as player animation state }
var
  animation : ^AnimationDesc;
  i         : integer;
  px, py    : integer;
  dir       : Direction;
begin
  with player do begin
    { do general entity updates first ... this will handle movement via
      any velocity/force vectors }
    UpdateEntity(entity);

    if state = Stabbing then begin

      if (entity.animation.frameIndex = 0)
         and (entity.animation.time = 0)
         and (not entity.animation.complete) then begin
        { only for the very first frame of the stabbing animation,
          check for any fruit that collide with the thumb tack's pointy
          end and should be popped }
        dir := entity.direction;
        with entity.position do begin
          GetThumbTackPointCoords(player, px, py);
          DoThumbTackStabAt(px, py, @player);
        end;
      end;

      if entity.animation.complete then begin
        { keep player in the stabbing state until that animation has
          completed. }
        SetPlayerState(player, Idle);

        stabCooldown := STAB_COOLDOWN;

        { stab/attack cooldown time quadrupled when afflicted by either
          the 'stabbed' or 'splashed' cooldown }
        if (stabbedDebuffTime > 0) or (splashedDebuffTime > 0) then
          stabCooldown := stabCooldown * 4;
      end;

    end else if (state <> Victory) and (state <> Defeat) then begin
      { set player idle/walking based on their velocity.
        note that this check ignores their force velocity! }
      if IsEntityStopped(entity) then
        SetPlayerState(player, Idle)
      else
        SetPlayerState(player, Walking);
    end;



    UpdateAnimation(entity, playerAnimations[ord(state)]);


    { update cooldowns / debuff timers }

    if stabCooldown > 0 then
      if stabCooldown > frameTicks then
        dec(stabCooldown, frameTicks)
      else
        stabCooldown := 0;

    if stabbedDebuffTime > 0 then
      if stabbedDebuffTime > frameTicks then
        dec(stabbedDebuffTime, frameTicks)
      else
        stabbedDebuffTime := 0;

    if splashedDebuffTime > 0 then
      if splashedDebuffTime > frameTicks then
        dec(splashedDebuffTime, frameTicks)
      else
        splashedDebuffTime := 0;

    if (stabbedDebuffTime > 0) or (splashedDebuffTime > 0) then
      skipRenderFlag := not skipRenderFlag;
  end;
end;

procedure InitPlayer(var player : Player; x, y : integer; fruit: FruitKind);
begin
  MemFill(@player, 0, SizeOf(Player));
  player.entity.position.x := IntToFix(x);
  player.entity.position.y := IntToFix(y);
  player.entity.direction := South;
  player.fruitPref := fruit;

  case fruit of
    Tomato: tomatoPlayer := @player;
    Grapes: grapesPlayer := @player;
  end;

  SetPlayerState(player, Idle);
end;

procedure MovePlayer(var player : Player; dir : Direction);
{ sets the given player in motion in the given direction. this function
  does not actually adjust the players position in any way. it only sets
  their velocity }
var
  speed : fixed;
begin
  with player do begin
    if stabCooldown > 0 then exit;
    if (state <> Idle) and (state <> Walking) then exit;

    { movement speed is halved when afflicted by 'splashed' }
    if splashedDebuffTime > 0 then
      speed := FixMul(PLAYER_WALK_SPEED, FP_0_5)
    { movement speed is cut by 30% when afflicted by 'stabbed' }
    else if stabbedDebuffTime > 0 then
      speed := FixMul(PLAYER_WALK_SPEED, FP_0_7)
    else
      speed := PLAYER_WALK_SPEED;

    case dir of
      North: begin
          with entity do begin
            dec(velocity.y, speed);
            direction := North;
          end;
        end;
      South: begin
          with entity do begin
            inc(velocity.Y, speed);
            direction := South;
          end;
        end;
      West: begin
          with entity do begin
            dec(velocity.x, speed);
            direction := West;
          end;
        end;
      East: begin
          with entity do begin
            inc(velocity.x, speed);
            direction := East;
          end;
        end;
    end;
  end;
end;

procedure StabPlayer(var player : Player);
{ switches the player into the 'stabbing' state, which will start the
  animation as well as bring out the player's thumb tack (during the
  next player update anyway) }
begin
  with player do begin
    if stabCooldown > 0 then exit;
    if (state <> Idle) and (state <> Walking) then exit;

    SetPlayerState(player, Stabbing);
  end;
end;

procedure DoThumbTackStabAt(px, py : integer; player : PPlayer);
{ determines what, if anything, a thumb tack stab with the pixel coordinates
  of the point provided, collided with and what should happen. the player
  passed should be the player who owns the thumb tack. }
var
  otherPlayer : PPlayer;
  dir : Direction;
begin
  { always pop any fruit / destroy any plants at this position }
  PopFruitAt(px, py, player);


  { did we also hit the other player? }

  { determine which player is which ... }
  if player = @player1 then
    otherPlayer := @player2
  else
    otherPlayer := @player1;

  { now check if this thumb tack point collided with that other player }
  if DoesEntityOverlap(otherPlayer^.entity,
                       px - PRICK_RADIUS,
                       py - PRICK_RADIUS,
                       px + PRICK_RADIUS,
                       py + PRICK_RADIUS) then begin
    { we hit the other player. push the other player in the direction
      that this player is facing }

    dir := player^.entity.direction;

    with otherPlayer^.entity do begin
      case dir of
        North: AngleToVec2DFP(BIN_ANGLE_270, force);
        South: AngleToVec2DFP(BIN_ANGLE_90, force);
        West: AngleToVec2DFP(BIN_ANGLE_180, force);
        East: AngleToVec2DFP(0, force);
      end;
      Vec2FP_ScaleThis(force, PLAYER_TACK_PUSH_FORCE);
    end;

    { also apply the 'stabbed' debuff to the other player }
    otherPlayer^.stabbedDebuffTime := STABBED_DEBUFF_TIME;

    { finally, spawn a 'ow' particle as another indication that a player
      was stabbed }
    with otherPlayer^.entity.position do begin
      SpawnOw(FixToInt(x), FixToInt(y));
    end;

  end;
end;

{ ------------------------------------------------------------------------ }

procedure SetFruitState(var fruit : Fruit; state : FruitState);
begin
  if state = fruit.state then exit;
  fruit.state   := state;
  fruit.counter := 0;
  fruit.value   := 0;
  ResetAnimationState(fruit.entity.animation);
end;

function GetPlantRandomLifeTime : word;
const
  MINIMUM_TIME   = 3000;
  STEP_SIZE      = 2000;
begin
  GetPlantRandomLifeTime := MINIMUM_TIME
                            + ((1+random(5)) * STEP_SIZE)
                            - random(STEP_SIZE);
end;

function SpawnRandomFruit : integer;
{ spawns a new fruit (starting it off as a plant) in any random available
  dirt tile on the map. spawning may fail (if a free dirt tile could not
  be found randomly). returns the dirtTiles index of the new fruit, or
  -1 if spawning failed }
var
  idx : integer;
begin
  SpawnRandomFruit := -1;

  { find a random spot to spawn a new fruit in }
  idx := GetRandomUnusedDirtTileIndex;
  if idx = -1 then exit;

  SpawnRandomFruit := idx;

  with dirtTiles[idx] do begin
    { important! this marks the dirt tile as being 'used' }
    hasFruit := true;
    inc(numActiveDirtTiles);

    { zero out the fruit, and then fill in its starter properties }

    MemFill(@fruit, 0, SizeOf(fruit));

    SetFruitState(fruit, Plant);

    if random(2) = 0 then
      fruit.kind := Tomato
    else
      fruit.kind := Grapes;

    fruit.value := GetPlantRandomLifeTime;

    fruit.isGold := (random(100) < GOLD_FRUIT_SPAWN_CHANCE);

    fruit.entity.position.x := IntToFix(x*16);
    fruit.entity.position.y := IntToFix(y*16);
  end;
end;

procedure PopFruitIn(var tile : DirtTile; player : PPlayer);
{ switches any fruit entity located within the given dirt tile into the
  'popped' state, as well as starting up any relevant animations. if
  there is no fruit in this tile, or the fruit is not in the 'grown'
  state yet, nothing happens. the player passed in here will be the one
  given 'credit' for popping the fruit (or if nil, no credit is given to
  any player). }
var
  fx, fy : integer;
begin
  with tile do begin
    if not hasFruit then exit;

    case fruit.state of
      Plant, Growing: begin
          { no score credit for stabbing a fruit plant, or a growing
            but not yet full grown fruit. just despawn it. }
          hasFruit := false;
          dec(numActiveDirtTiles);

          with fruit.entity.position do begin
            SpawnPlantSplash(FixToInt(x), FixToInt(y));
          end;
        end;

      Grown: begin
          { stabbing fully grown fruit }
          SetFruitState(fruit, Popped);
          with fruit.entity.position do begin
            fx := FixToInt(x);
            fy := FixToInt(y);

            { if the stabbing player's fruit choice matches the popped
              fruit, then give the player score credit }
            if fruit.kind = player^.fruitPref then begin
              SpawnScoreUp(fx, fy, fruit.kind);
              inc(player^.score);
            end;

            if fruit.isGold then
              PopAllFruit(fruit.kind, player);

            SpawnStabFlash(fx, fy);
          end;
        end;
    end;
  end;
end;

procedure PopAllFruit(kind : FruitKind; player : PPlayer);
var
  idx : integer;
begin
  for idx := 0 to numDirtTiles-1 do begin
    with dirtTiles[idx] do begin
      if not hasFruit then continue;

      if (fruit.kind = kind) and (fruit.state = Grown) then begin
        PopFruitIn(dirtTiles[idx], player);
      end;
    end;
  end;
end;

procedure PopFruitAt(x, y : integer; player : PPlayer);
{ switches any fruit located near the given x/y coordinates into the
  'popped' state, assuming that the fruit are already in the 'grown'
  state (otherwise, they will not be changed). these x/y coordinates
  would normally be the pixel coordinates corresponding to a player's
  thumb tack point. the player passed in here will be the one given
  'credit' for popping the fruit (or if nil, no credit is given to
  any player). }
var
  left, right, top, bottom : integer;
  cx, cy                   : integer;
  dirtTile                 : PDirtTile;
begin
  { get the map tile x/y region to check for dirt tiles within }
  left := (x - PRICK_RADIUS) div TILE_SIZE;
  right := (x + PRICK_RADIUS) div TILE_SIZE;
  top := (y - PRICK_RADIUS) div TILE_SIZE;
  bottom := (y + PRICK_RADIUS) div TILE_SIZE;

  if left < 0 then left := 0;
  if right > MAP_RIGHT then right := MAP_RIGHT;
  if top < 0 then top := 0;
  if bottom > MAP_BOTTOM then bottom := MAP_BOTTOM;

  { for all dirt tiles located within this region, pop the fruit
    in them }
  for cy := top to bottom do begin
    for cx := left to right do begin
      dirtTile := dirtTileMapping[(cy * SCREEN_MAP_WIDTH) + cx];
      if dirtTile <> nil then begin
        PopFruitIn(dirtTile^, player);
      end;
    end;
  end;
end;

procedure UpdateAllFruit;
{ updates the state of all fruit currently active within dirtTiles }
const
  GROW_STEP_TIME = 40;
  SPRITE_MAX_SIZE = 16;
var
  i, fx, fy : integer;
begin
  { periodically spawn more fruit }
  if (fruitSpawnTimer >= 1000)
     and (numActiveDirtTiles < map.header.maxFruit) then begin
    SpawnRandomFruit;
    fruitSpawnTimer := 0;
  end;

  for i := 0 to numDirtTiles-1 do begin
    with dirtTiles[i] do begin
      if not hasFruit then continue;

      case fruit.state of
        Plant: begin
            { count time into the plant has been a plant for 'value' time
              at which point it should 'grow' into a fruit }
            with fruit do begin
              inc(counter, frameTicks);
              if counter >= value then begin
                SetFruitState(fruit, Growing);
                value := 2;
              end;
            end;
          end;

        Growing: begin
            { the fruit "grows" by scaling it's size up from zero to it's
              normal pixel sprite size. the size increments by 1 every
              so often }
            with fruit do begin
              if value < SPRITE_MAX_SIZE then begin
                inc(counter, frameTicks);
                if counter >= GROW_STEP_TIME then begin
                  inc(value);
                  counter := 0;
                end;
              end else begin
                SetFruitState(fruit, Grown);
              end;
            end;
          end;

        Grown: begin
          end;

        Popped: begin
            { when the popped "animation" (not really an animation, just
              abusing a 1-frame sequence with long delay as a timer)
              completes, we can deactivate this dirt tile and fruit }
            if fruit.entity.animation.complete then begin
              hasFruit := false;
              dec(numActiveDirtTiles);

              with fruit.entity.position do begin
                fx := FixToInt(x);
                fy := FixToInt(y);
              end;

              if fruit.kind = Tomato then begin
                SpawnTomatoSplash(fx, fy);

                { if the grapes-preference player is nearby this tomato
                  splash, then spawn an extra tomato splash at their exact
                  position and afflict them with the 'splashed' debuff }
                with grapesPlayer^ do begin
                  if DoesEntityOverlap(entity,
                                     fx-32,
                                     fy-32,
                                     fx+48,
                                     fy+48) then begin
                    with entity.position do
                      SpawnTomatoSplash(FixToInt(x), FixToInt(y));
                    splashedDebuffTime := SPLASHED_DEBUFF_TIME;
                  end;
                end;

              end else begin
                SpawnGrapesSplash(fx, fy);

                { if the tomato-preference player is nearby this grapes
                  splash, then spawn an extra grapes splash at their exact
                  position and afflict them with the 'splashed' debuff }
                with tomatoPlayer^ do begin
                  if DoesEntityOverlap(entity,
                                       fx-32,
                                       fy-32,
                                       fx+48,
                                       fy+48) then begin
                    with entity.position do
                      SpawnGrapesSplash(FixToInt(x), FixToInt(y));
                    splashedDebuffTime := SPLASHED_DEBUFF_TIME;
                  end;
                end;
              end;

              continue;
            end;
          end;
      end;

      with fruit do begin
        UpdateAnimation(entity, fruitAnimations[ord(state)]);
      end;
    end;
  end;
end;

{ ------------------------------------------------------------------------ }

function GetUnusedParticleIndex : integer;
{ returns the index of the next unused/inactive particle. returns -1 if
  there is no free index }
var
  i : integer;
begin
  GetUnusedParticleIndex := -1;

  for i := 0 to MAX_PARTICLES-1 do begin
    if not particles[i].active then begin
      GetUnusedParticleIndex := i;
      exit;
    end;
  end;
end;

function InitNewParticle(x, y : integer) : integer;
var
  i : integer;
begin
  InitNewParticle := -1;

  i := GetUnusedParticleIndex;
  if i = -1 then exit;

  MemFill(@particles[i], 0, SizeOf(Particle));
  with particles[i] do begin
    active := true;
    with entity do begin
      noCollision := true;
      position.x  := IntToFix(x);
      position.y  := IntToFix(y);
    end;
  end;

  InitNewParticle := i;
end;

function SpawnTomatoSplash(x, y : integer) : integer;
{ spawns a new 'tomato splash' particle at the given coordinates.
  returns the index of the spawned particle if successful, or -1 if there
  was no free particle index }
var
  i : integer;
begin
  SpawnTomatoSplash := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    animation := @tomatoSplashAnimation;
  end;

  SpawnTomatoSplash := i;
end;

function SpawnGrapesSplash(x, y : integer) : integer;
{ spawns a new 'grapes splash' particle at the given coordinates.
  returns the index of the spawned particle if successful, or -1 if there
  was no free particle index }
var
  i : integer;
begin
  SpawnGrapesSplash := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    animation := @grapesSplashAnimation;
  end;

  SpawnGrapesSplash := i;
end;

function SpawnPlantSplash(x, y : integer) : integer;
{ spawns a new 'plant splash' (for when a plant is destroyed) particle at
  the given coordinates. returns the index of the spawned particle if
  successful, or -1 if there was no free particle index }
var
  i : integer;
begin
  SpawnPlantSplash := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    animation := @plantDestroyAnimation;
  end;

  SpawnPlantSplash := i;
end;

function SpawnStabFlash(x, y : integer) : integer;
{ spawns a new 'stab flash' particle at the given coordinates.
  returns the index of the spawned particle if successful, or -1 if there
  was no free particle index }
var
  i : integer;
begin
  SpawnStabFlash := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    animation := @stabFlashAnimation;
  end;

  SpawnStabFlash := i;
end;

function SpawnScoreUp(x, y : integer; kind : FruitKind) : integer;
{ spawns a new '+1' score particle at the given coordinates, for the
  specified fruit (affects how it is displayed).
  returns the index of the spawned particle if successful, or -1 if there
  was no free particle index }
var
  i : integer;
begin
  SpawnScoreUp := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    if kind = Tomato then
      animation := @tomatoScoreUpAnimation
    else
      animation := @grapesScoreUpAnimation;

    with entity do begin
      velocity.y := SCORE_UP_PARTICLE_SPEED;
    end;
  end;

  SpawnScoreUp := i;
end;

function SpawnOw(x, y : integer) : integer;
{ spawns a new 'ow' particle (to indicate a player was stabbed) at the given
  coordinates.
  returns the index of the spawned particle if successful, or -1 if there
  was no free particle index }
var
  i : integer;
begin
  SpawnOw := -1;

  i := InitNewParticle(x, y);
  if i = -1 then exit;

  with particles[i] do begin
    animation := @owAnimation;

    with entity do begin
      velocity.y := OW_PARTICLE_SPEED;
    end;
  end;

  SpawnOw := i;
end;

procedure UpdateAllParticles;
var
  i : word;
begin
  for i := 0 to MAX_PARTICLES-1 do begin
    with particles[i] do begin
      if not active then continue;

      MoveEntity(entity);

      if animation <> nil then begin
        { particle is a "sprite-animated" particle type.
          this means its lifetime is tied to the animation. update it's
          animation, and when it is complete, kill the particle }
        if entity.animation.complete then
          active := false
        else
          UpdateAnimation(entity, animation^);

      end else begin
        { TODO: "pixel" particle types ... }

      end;
    end;
  end;
end;

end.


