{$A+,B-,E+,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Maps;

interface

uses Entities;

const
  SCREEN_MAP_LAYER           = 2;

  SCREEN_MAP_WIDTH           = 20;
  SCREEN_MAP_HEIGHT          = 11;
  SCREEN_MAP_SIZE            = SCREEN_MAP_WIDTH*SCREEN_MAP_HEIGHT;

  MAP_RIGHT                  = SCREEN_MAP_WIDTH - 1;
  MAP_BOTTOM                 = SCREEN_MAP_HEIGHT - 1;

  { every tile beginning with this index should be
    considered 'solid' for collision-purposes }
  SOLID_TILE_START           = 70;

  { inclusive start/end tile indices marking the range in which all
    possible "dirt" tiles are found within }
  DIRT_TILES_START           = 15;
  DIRT_TILES_END             = 54;

type
  DirtTile = record
    fruit    : Fruit;
    hasFruit : bytebool;
    x, y     : word;
    mapIndex : word;
  end;
  PDirtTile = ^DirtTile;

  MapArray = array[0..(SCREEN_MAP_SIZE-1)] of byte;

  MapHeader = record
    name         : string[32]; { display name }
    time         : word;       { match time in seconds }
    initialFruit : word;       { initial amount of fruit plants to spawn }
    maxFruit     : word;       { max number of fruit/plants that can be
                                 active. once reached, no more will spawn
                                 until some of the existing ones are
                                 removed }
    player1x     : word;       { player 1 starting tile coordinates }
    player1y     : word;
    player2x     : word;       { player 2 starting tile coordinates }
    player2y     : word;
  end;

  MapFile = record
    header       : MapHeader;
    map          : MapArray;
  end;

  MapToDirtTileArray = array[0..(SCREEN_MAP_SIZE-1)] of PDirtTile;

  { even though this is sized identically to the map itself, the actual
    number of indices used will be less. AND these indices DO NOT
    correspond to the same indices in the map itself! }
  DirtTileArray = array[0..(SCREEN_MAP_SIZE-1)] of DirtTile;

const
  { if true, the map should be re-rendered to SCREEN_MAP_LAYER }
  isMapDirty : boolean = false;

var
  map : MapFile;

  { a mapping of map x,y coordinates to DirtTile instances. any index
    where the value in this array is nil means that that x,y coordinate
    is not for a dirt tile }
  dirtTileMapping      : MapToDirtTileArray;

  { contains all of the dirt tiles. the indices in this array DO NOT
    correspond to map x,y coordinates. use the above dirtTileMapping
    array to find a dirt tile located in this array given a set of x,y
    coordinates. }
  { TODO: perhaps this should be implemented as a linked-list? }
  dirtTiles            : DirtTileArray;
  numDirtTiles         : word;
  numActiveDirtTiles   : word;

function IsMapCollision(x, y : integer) : boolean;
function DoesEntityOverlapMapTile(const entity : Entity;
                                  xt, yt : integer) : boolean;
procedure InitDirtTiles;
function GetUnusedDirtTileIndex : integer;
function GetRandomUnusedDirtTileIndex : integer;

implementation

uses FixedP, Toolbox, Shared;

function IsMapCollision(x, y : integer) : boolean;
{ returns true if an entity-sized object located at the given x,y
  coordinates (which indicate the top-left of the entity) will collide
  with any 'solid' tiles on the map. }
const
  EDGE = 2;
var
  left, right, top, bottom : integer;
  cx, cy                   : integer;
  index                    : word;
begin
  IsMapCollision := false;

  { TODO: something to make collision feel less "sticky" and a bit more
          forgiving ... }

  left := (x+EDGE) div TILE_SIZE;
  right := ((x-EDGE) + ENTITY_SIZE-1) div TILE_SIZE;
  top := (y+EDGE) div TILE_SIZE;
  bottom := ((y-EDGE) + ENTITY_SIZE-1) div TILE_SIZE;

  if left < 0 then left := 0;
  if right > MAP_RIGHT then right := MAP_RIGHT;
  if top < 0 then top := 0;
  if bottom > MAP_BOTTOM then bottom := MAP_BOTTOM;

  with map do begin
    for cy := top to bottom do begin
      for cx := left to right do begin
        index := (cy * SCREEN_MAP_WIDTH) + cx;
        if map[index] >= SOLID_TILE_START then begin
          IsMapCollision := true;
          exit;
        end else if (dirtTileMapping[index] <> nil)
                    and (dirtTileMapping[index]^.hasFruit) then begin
          IsMapCollision := true;
          exit;
        end;
      end;
    end;
  end;
end;

function DoesEntityOverlapMapTile(const entity : Entity;
                                  xt, yt : integer) : boolean;
{ returns true if the given entity fully or partially overlaps the boundaries
  of the given map tile coordinates. the x and y coordinates given should be
  tile coordinates, not pixel coordinates. }
const
  EDGE = 2;
var
  ex1, ey1, ex2, ey2 : integer;
  x2, y2 : integer;
begin
  DoesEntityOverlapMapTile := false;

  with entity.position do begin
    ex1 := FixToInt(x)+EDGE;
    ey1 := FixToInt(y)+EDGE;
    ex2 := ex1 + (ENTITY_SIZE-1)-EDGE;
    ey2 := ey1 + (ENTITY_SIZE-1)-EDGE;
  end;

  xt := xt * TILE_SIZE;
  yt := yt * TILE_SIZE;
  x2 := xt + (TILE_SIZE-1);
  y2 := yt + (TILE_SIZE-1);

  if (ey1 < yt) and (ey2 < yt) then
    exit;
  if (ey1 > y2) and (ey2 > y2) then
    exit;
  if (ex1 < xt) and (ex2 < xt) then
    exit;
  if (ex1 > x2) and (ex2 > x2) then
    exit;

  DoesEntityOverlapMapTile := true;
end;

procedure InitDirtTiles;
{ after a map has been freshly loaded, call this to scan the map for
  all its dirt tiles. x,y coord to DirtTile instance mapping information
  will be prepared as well as initializing the dirt tiles array itself }
var
  mapIdx, dirtIdx, x, y : word;
  tile                  : byte;
begin
  MemFill(@dirtTileMapping, 0, SizeOf(dirtTileMapping));
  MemFill(@dirtTiles, 0, SizeOf(dirtTiles));

  dirtIdx := 0;
  for y := 0 to SCREEN_MAP_HEIGHT-1 do begin
    for x := 0 to SCREEN_MAP_WIDTH-1 do begin
      mapIdx := (y * SCREEN_MAP_WIDTH) + x;
      tile := map.map[mapIdx];

      { if this map location contains a dirt tile ... }
      if (tile >= DIRT_TILES_START) and (tile <= DIRT_TILES_END) then begin
        { set up this next DirtTile instance with coordinate info about
          this map location }
        dirtTiles[dirtIdx].x := x;
        dirtTiles[dirtIdx].y := y;
        dirtTiles[dirtIdx].mapIndex := mapIdx;

        { and add a pointer for this map coordinate index to the table }
        dirtTileMapping[mapIdx] := @dirtTiles[dirtIdx];

        inc(dirtIdx);
      end;
    end;
  end;

  numDirtTiles := dirtIdx;
  numActiveDirtTiles := 0;
end;

function GetUnusedDirtTileIndex : integer;
{ returns the index of the next unused/inactive dirt tile from dirtTiles.
  returns -1 if there is no free index }
var
  idx : integer;
begin
  GetUnusedDirtTileIndex := -1;

  for idx := 0 to numDirtTiles-1 do begin
    if dirtTiles[idx].hasFruit then begin
      GetUnusedDirtTileIndex := idx;
      exit;
    end;
  end;
end;

function GetRandomUnusedDirtTileIndex : integer;
{ returns the index of a random unused/inactive dirt tile from dirtTiles.
  returns -1 if there is no free index }
const
  MAX_TRIES = 10;  { TODO: LOL, this is a bad way to do this }
var
  try, idx : integer;
begin
  GetRandomUnusedDirtTileIndex := -1;

  for try := 0 to MAX_TRIES do begin
    idx := random(numDirtTiles);
    { make sure there is no fruit in this tile ... }
    if not dirtTiles[idx].hasFruit then begin
      with dirtTiles[idx] do begin
        { and also make sure that neither player is currently anywhere
          within this tile either }
        if (not DoesEntityOverlapMapTile(player1.entity, x, y))
           and (not DoesEntityOverlapMapTile(player2.entity, x, y)) then begin
          { now we know for sure that this tile is clear }
          GetRandomUnusedDirtTileIndex := idx;
          exit;
        end;
      end;
    end;
  end;
end;



end.
