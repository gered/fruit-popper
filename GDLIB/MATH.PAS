{ Math helper functions and lookup tables.
  Gered King, 2019 }

{ You MUST manually call 'InitTrigTables' in your programs before using
  any of these functions that use trig!! }

{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit Math;

interface

const
  PI                         = 3.141592654;
  PI_OVER_180                = PI / 180.0;

  DEG_TO_RAD                 = PI_OVER_180;
  RAD_TO_DEG                 = 1.0 / PI_OVER_180;

  DEG_TO_BIN                 = 1024 / 360;
  BIN_TO_DEG                 = 1.0 / (DEG_TO_BIN);
  RAD_TO_BIN                 = 512 / PI;
  BIN_TO_RAD                 = 1.0 / (RAD_TO_BIN);

  { note: might want to define these manually ... ?
    trunc vs round makes this fun if you ever change the binangle range.. }
  BIN_ANGLE_1                = round(1 * DEG_TO_BIN);
  BIN_ANGLE_45               = round(45 * DEG_TO_BIN);
  BIN_ANGLE_90               = round(90 * DEG_TO_BIN);
  BIN_ANGLE_135              = round(135 * DEG_TO_BIN);
  BIN_ANGLE_180              = round(180 * DEG_TO_BIN);
  BIN_ANGLE_225              = round(225 * DEG_TO_BIN);
  BIN_ANGLE_270              = round(270 * DEG_TO_BIN);
  BIN_ANGLE_315              = round(315 * DEG_TO_BIN);
  BIN_ANGLE_359              = round(359 * DEG_TO_BIN);
  BIN_ANGLE_360              = round(360 * DEG_TO_BIN);

  BIN_ANGLE_TAN_MASK         = BIN_ANGLE_180-1;
  BIN_ANGLE_MASK             = BIN_ANGLE_360-1;

  M33_11                     = 0;
  M33_12                     = 3;
  M33_13                     = 6;
  M33_21                     = 1;
  M33_22                     = 4;
  M33_23                     = 7;
  M33_31                     = 2;
  M33_32                     = 5;
  M33_33                     = 8;

type
  BinAngle = integer;        { binary angles, where 0-1023 = full circle }

  Vec2 = record
    X, Y : single;
  end;
  PVec2 = ^Vec2;

  Mtx33 = record
    m : array[0..8] of single;
  end;
  PMtx33 = ^Mtx33;

const
  ZERO_VEC2                  : Vec2 = (X: 0.0; Y: 0.0);
  IDENTITY_MTX33             : Mtx33 = (m: (1.0, 0.0, 0.0,
                                            0.0, 1.0, 0.0,
                                            0.0, 0.0, 1.0));

var
  SinTable                   : array[0..1023] of single;
  CosTable                   : array[0..1023] of single;
  TanTable                   : array[0..511] of single;

procedure InitTrigTables;

function Lerp(a, b, t: single) : single;
function InvLerp(a, b, lerped: single) : single;
function Atan(x : single) : binangle;
function Atan2(y, x : single) : binangle;
function AngleBetween(x1, y1, x2, y2: single) : binangle;
procedure AngleToDir2D(angle: binangle; var outX, outY: single);
procedure AngleToVec2D(angle: binangle; var out: Vec2);

procedure Vec2_Set(var out : Vec2; x, y : single);
procedure Vec2_Zero(var out : Vec2);
procedure Vec2_Add(var out : Vec2; const a, b : Vec2);
procedure Vec2_AddTo(var out : Vec2; const v : Vec2);
procedure Vec2_Sub(var out : Vec2; const a, b : Vec2);
procedure Vec2_SubFrom(var out : Vec2; const v : Vec2);
procedure Vec2_Scale(var out : Vec2; const a : Vec2; n : single);
function Vec2_Distance(const a, b : Vec2) : single;
function Vec2_DistanceSqr(const a, b : Vec2) : single;
function Vec2_Dot(const a, b : Vec2) : single;
function Vec2_Length(const a : Vec2) : single;
function Vec2_LengthSqr(const a : Vec2) : single;
procedure Vec2_Normalize(var out : Vec2; const a : Vec2);
procedure Vec2_NormalizeThis(var out : Vec2);
procedure Vec2_SetLength(var out : Vec2; const a : Vec2; length : single);
procedure Vec2_SetThisLength(var out : Vec2; length : single);
procedure Vec2_Lerp(var out : Vec2; const a, b : Vec2; t : single);

procedure Mtx33_Identity(var out : Mtx33);
procedure Mtx33_RotationX(var out : Mtx33; angle : binangle);
procedure Mtx33_RotationY(var out : Mtx33; angle : binangle);
procedure Mtx33_RotationZ(var out : Mtx33; angle : binangle);
procedure Mtx33_Mul(var out, a, b : Mtx33);
procedure Mtx33_Transform2D(var out : Vec2; var m : Mtx33; var v : Vec2);
procedure Mtx33_Translation2D(var out : Mtx33; x, y : single);
procedure Mtx33_Scaling2D(var out : Mtx33; x, y : single);
procedure Mtx33_Rotation2D(var out : Mtx33; angle : binangle);

implementation

function Fequ(a, b: single) : boolean;
begin
  { TODO: lol, this is maybe somewhat 'ok', but rewrite this garbage }
  Fequ := (abs(a - b) <= 0.00005);
end;

procedure InitTrigTables;
{ populates the trig lookup tables with sin/cos/tan values for the entire
  range of binary angles supported (0 to BIN_ANGLE_MASK). }
var
  angle   : binangle;
  r, s, c : single;
begin
  for angle := 0 to BIN_ANGLE_MASK do begin
    r := angle * BIN_TO_RAD;
    s := sin(r);
    c := cos(r);

    SinTable[angle] := s;
    CosTable[angle] := c;
    if angle <= BIN_ANGLE_TAN_MASK then begin
      if (angle = BIN_ANGLE_90) or (angle = BIN_ANGLE_270) then
        TanTable[angle] := 0
      else
        TanTable[angle] := (s / c);
    end;
  end;
end;

function Lerp(a, b, t: single) : single;
{ returns the interpolated value between the ranged defined by a and b. }
begin
  Lerp := a + (b - a) * t;
end;

function InvLerp(a, b, lerped: single) : single;
{ returns the 't' value used in a call to Lerp that returned the given
  'lerped' value using the range a to b (approximately, anyway). }
begin
  InvLerp := (lerped - a) / (b - a);
end;

function Atan(x : single) : binangle;
{ calculates the arctangent of X. returns the result as a binary angle.
  functionally equivalent to ArcTan(). }
var
  a, b, c : integer;
  d       : single;
begin
  if x >= 0 then begin
    a := 0;
    b := (BIN_ANGLE_90 - 1);
  end else begin
    a := BIN_ANGLE_90;
    b := (BIN_ANGLE_180 - 1);
  end;

  repeat
    c := (a + b) div 2;
    d := x - TanTable[c];

    if d > 0.0 then
      a := c + 1
    else if d < 0.0 then
      b := c - 1;
  until ((a > b) or (d = 0.0));

  if x >= 0 then
    Atan := c
  else
    Atan := -BIN_ANGLE_180 + c;
end;

function Atan2(y, x : single) : binangle;
{ calculates the arctangent of Y/X. returns the result as a binary angle.
  functionally equivalent to atan2() from the C runtime library. }
var
  r : single;
  b : binangle;
begin
  if x = 0.0 then begin
    if y = 0.0 then begin
      Atan2 := 0;
    end else begin
      if y < 0.0 then
        Atan2 := -BIN_ANGLE_90
      else
        Atan2 := BIN_ANGLE_90;
    end;
    exit;
  end;

  r := y / x;
  b := Atan(r);

  if x >= 0.0 then
    Atan2 := b
  else if y >= 0.0 then
    Atan2 := BIN_ANGLE_180 + b
  else
    Atan2 := b - BIN_ANGLE_180;
end;

function AngleBetween(x1, y1, x2, y2: single) : binangle;
{ calculates the binary angle between the two points }
var
  deltaX, deltaY : single;
begin
  deltaX := x2 - x1;
  deltaY := y2 - y1;
  if (Fequ(deltaX, 0.0) and Fequ(deltaY, 0.0)) then
    AngleBetween := 0
  else
    AngleBetween := Atan2(deltaY, deltaX);
end;

procedure AngleToDir2D(angle: binangle;
                       var outX, outY: single);
{ for a given binary angle, calculates a normalized 2D direction vector
  that points in the same direction as the angle }
begin
  outX := CosTable[angle and BIN_ANGLE_MASK];
  outY := SinTable[angle and BIN_ANGLE_MASK];
end;

procedure AngleToVec2D(angle: binangle;
                       var out: Vec2);
{ for a given binary angle, calculates a normalized Vec2 that points in the
  same direction as the angle }
begin
  with out do begin
    X := CosTable[angle and BIN_ANGLE_MASK];
    Y := SinTable[angle and BIN_ANGLE_MASK];
  end;
end;

procedure Vec2_Set(var out : Vec2; x, y : single);
begin
  out.X := x;
  out.Y := y;
end;

procedure Vec2_Zero(var out : Vec2);
begin
  with out do begin
    X := 0.0;
    Y := 0.0;
  end;
end;

procedure Vec2_Add(var out : Vec2; const a, b : Vec2);
begin
  with out do begin
    X := a.X + b.X;
    Y := a.Y + b.Y;
  end;
end;

procedure Vec2_AddTo(var out : Vec2; const v : Vec2);
begin
  with out do begin
    X := X + v.X;
    Y := Y + v.Y;
  end;
end;

procedure Vec2_Sub(var out : Vec2; const a, b : Vec2);
begin
  with out do begin
    X := a.X - b.X;
    Y := a.Y - b.Y;
  end;
end;

procedure Vec2_SubFrom(var out : Vec2; const v : Vec2);
begin
  with out do begin
    X := X - v.X;
    Y := Y - v.Y;
  end;
end;

procedure Vec2_Scale(var out : Vec2; const a : Vec2; n : single);
begin
  with out do begin
    X := a.X * n;
    Y := a.Y * n;
  end;
end;

function Vec2_Distance(const a, b : Vec2) : single;
var
  j, k : single;
begin
  j := b.X - a.X;
  k := b.Y - a.Y;
  Vec2_Distance := Sqrt((j * j) + (k * k));
end;

function Vec2_DistanceSqr(const a, b : Vec2) : single;
var
  j, k : single;
begin
  j := b.X - a.X;
  k := b.Y - a.Y;
  Vec2_DistanceSqr := (j * j) + (k * k);
end;

function Vec2_Dot(const a, b : Vec2) : single;
begin
  Vec2_Dot := (a.X * b.X) + (a.Y * b.Y);
end;

function Vec2_Length(const a : Vec2) : single;
begin
  with a do begin
    Vec2_Length := Sqrt((X * X) + (Y * Y));
  end;
end;

function Vec2_LengthSqr(const a : Vec2) : single;
begin
  with a do begin
    Vec2_LengthSqr := (X * X) + (Y * Y);
  end;
end;

procedure Vec2_Normalize(var out : Vec2; const a : Vec2);
var
  inverseLength : single;
begin
  inverseLength := 1.0 / Vec2_Length(a);
  with out do begin
    X := a.X * inverseLength;
    Y := a.Y * inverseLength;
  end;
end;

procedure Vec2_NormalizeThis(var out : Vec2);
var
  inverseLength : single;
begin
  inverseLength := 1.0 / Vec2_Length(out);
  with out do begin
    X := X * inverseLength;
    Y := Y * inverseLength;
  end;
end;

procedure Vec2_SetLength(var out : Vec2; const a : Vec2; length : single);
var
  scale : single;
begin
  scale := length / Vec2_Length(a);
  with out do begin
    X := a.X * scale;
    Y := a.Y * scale;
  end;
end;

procedure Vec2_SetThisLength(var out : Vec2; length : single);
var
  scale : single;
begin
  scale := length / Vec2_Length(out);
  with out do begin
    X := X * scale;
    Y := Y * scale;
  end;
end;

procedure Vec2_Lerp(var out : Vec2; const a, b : Vec2; t : single);
begin
  with out do begin
    X := a.X + (b.X - a.X) * t;
    Y := a.Y + (b.Y - a.Y) * t;
  end;
end;

procedure Mtx33_Identity(var out : Mtx33);
begin
  with out do begin
    m[M33_11] := 1.0;
    m[M33_12] := 0.0;
    m[M33_13] := 0.0;

    m[M33_21] := 0.0;
    m[M33_22] := 1.0;
    m[M33_23] := 0.0;

    m[M33_31] := 0.0;
    m[M33_32] := 0.0;
    m[M33_33] := 1.0;
  end;
end;

procedure Mtx33_RotationX(var out : Mtx33; angle : binangle);
var
  s, c : single;
begin
  s := SinTable[angle and BIN_ANGLE_MASK];
  c := CosTable[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := 1.0;
    m[M33_12] := 0.0;
    m[M33_13] := 0.0;

    m[M33_21] := 0.0;
    m[M33_22] := c;
    m[M33_23] := -s;

    m[M33_31] := 0.0;
    m[M33_32] := s;
    m[M33_33] := c;
  end;
end;

procedure Mtx33_RotationY(var out : Mtx33; angle : binangle);
var
  s, c : single;
begin
  s := SinTable[angle and BIN_ANGLE_MASK];
  c := CosTable[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := c;
    m[M33_12] := 0.0;
    m[M33_13] := s;

    m[M33_21] := 0.0;
    m[M33_22] := 1.0;
    m[M33_23] := 0.0;

    m[M33_31] := -s;
    m[M33_32] := 0.0;
    m[M33_33] := c;
  end;
end;

procedure Mtx33_RotationZ(var out : Mtx33; angle : binangle);
var
  s, c : single;
begin
  s := SinTable[angle and BIN_ANGLE_MASK];
  c := CosTable[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := c;
    m[M33_12] := -s;
    m[M33_13] := 0.0;

    m[M33_21] := s;
    m[M33_22] := c;
    m[M33_23] := 0.0;

    m[M33_31] := 0.0;
    m[M33_32] := 0.0;
    m[M33_33] := 1.0;
  end;
end;

procedure Mtx33_Mul(var out, a, b : Mtx33);
begin
  with out do begin
    m[M33_11] := a.m[M33_11] * b.m[M33_11] + a.m[M33_12] * b.m[M33_21] + a.m[M33_13] * b.m[M33_31];
    m[M33_12] := a.m[M33_11] * b.m[M33_12] + a.m[M33_12] * b.m[M33_22] + a.m[M33_13] * b.m[M33_32];
    m[M33_13] := a.m[M33_11] * b.m[M33_13] + a.m[M33_12] * b.m[M33_23] + a.m[M33_13] * b.m[M33_33];

    m[M33_21] := a.m[M33_21] * b.m[M33_11] + a.m[M33_22] * b.m[M33_21] + a.m[M33_23] * b.m[M33_31];
    m[M33_22] := a.m[M33_21] * b.m[M33_12] + a.m[M33_22] * b.m[M33_22] + a.m[M33_23] * b.m[M33_32];
    m[M33_23] := a.m[M33_21] * b.m[M33_13] + a.m[M33_22] * b.m[M33_23] + a.m[M33_23] * b.m[M33_33];

    m[M33_31] := a.m[M33_31] * b.m[M33_11] + a.m[M33_32] * b.m[M33_21] + a.m[M33_33] * b.m[M33_31];
    m[M33_32] := a.m[M33_31] * b.m[M33_12] + a.m[M33_32] * b.m[M33_22] + a.m[M33_33] * b.m[M33_32];
    m[M33_33] := a.m[M33_31] * b.m[M33_13] + a.m[M33_32] * b.m[M33_23] + a.m[M33_33] * b.m[M33_33];
  end;
end;

procedure Mtx33_Transform2D(var out : Vec2; var m : Mtx33; var v : Vec2);
begin
  with out do begin
    X := v.X * m.m[M33_11] + v.Y * m.m[M33_12] + m.m[M33_13];
    Y := v.X * m.m[M33_21] + v.Y * m.m[M33_22] + m.m[M33_23];
    X := X + m.m[M33_31];
    Y := Y + m.m[M33_32];
  end;
end;

procedure Mtx33_Translation2D(var out : Mtx33; x, y : single);
begin
  with out do begin
    m[M33_11] := 1.0;
    m[M33_12] := 0.0;
    m[M33_13] := 0.0;

    m[M33_21] := 0.0;
    m[M33_22] := 1.0;
    m[M33_23] := 0.0;

    m[M33_31] := x;
    m[M33_32] := y;
    m[M33_33] := 1.0;
  end;
end;

procedure Mtx33_Scaling2D(var out : Mtx33; x, y : single);
begin
  with out do begin
    m[M33_11] := x;
    m[M33_12] := 0.0;
    m[M33_13] := 0.0;

    m[M33_21] := 0.0;
    m[M33_22] := y;
    m[M33_23] := 0.0;

    m[M33_31] := 0.0;
    m[M33_32] := 0.0;
    m[M33_33] := 1.0;
  end;
end;

procedure Mtx33_Rotation2D(var out : Mtx33; angle : binangle);
begin
  Mtx33_RotationZ(out, angle);
end;

end.
