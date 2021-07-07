{ Math helper functions and lookup tables.
  Fixed-point alternatives to the stuff located in the Math unit.
  Gered King, 2019 }

{ You MUST manually call 'InitTrigTablesFP' in your programs before using
  any of these functions that use trig!! }


{$A+,B-,F-,G+,I-,N+,P-,Q-,R-,S-,T-,V-,X+}

unit MathFP;

interface

uses Math, FixedP;

const
  FP_PI                      = trunc(PI * FP_FLOAT_SHIFT);
  FP_PI_OVER_180             = trunc(PI_OVER_180 * FP_FLOAT_SHIFT);

  FP_DEG_TO_RAD              = trunc(DEG_TO_RAD * FP_FLOAT_SHIFT);
  FP_RAD_TO_DEG              = trunc(RAD_TO_DEG * FP_FLOAT_SHIFT);

  FP_DEG_TO_BIN              = trunc(DEG_TO_BIN * FP_FLOAT_SHIFT);
  FP_BIN_TO_DEG              = trunc(BIN_TO_DEG * FP_FLOAT_SHIFT);
  FP_RAD_TO_BIN              = trunc(RAD_TO_BIN * FP_FLOAT_SHIFT);
  FP_BIN_TO_RAD              = trunc(BIN_TO_RAD * FP_FLOAT_SHIFT);

type
  Vec2FP = record
    X, Y : fixed;
  end;
  PVec2FP = ^Vec2FP;

  Mtx33FP = record
    m : array[0..8] of fixed;
  end;
  PMtx33FP = ^Mtx33FP;

const
  ZERO_VEC2FP                : Vec2FP = (X: 0; Y: 0);
  IDENTITY_MTX33FP           : Mtx33FP = (m: (FP_1, 0,    0,
                                              0,    FP_1, 0,
                                              0,    0,    FP_1));

var
  SinTableFP                 : array[0..1023] of fixed;
  CosTableFP                 : array[0..1023] of fixed;
  TanTableFP                 : array[0..511] of fixed;

procedure InitTrigTablesFP;

function LerpFP(a, b, t: fixed) : fixed;
function InvLerpFP(a, b, lerped: fixed) : fixed;
function AtanFP(x : fixed) : binangle;
function Atan2FP(y, x : fixed) : binangle;
function AngleBetweenFP(x1, y1, x2, y2: fixed) : binangle;
procedure AngleToDir2DFP(angle: binangle; var outX, outY: fixed);
procedure AngleToVec2DFP(angle: binangle; var out: Vec2FP);

procedure Vec2FP_Set(var out : Vec2FP; x, y : fixed);
procedure Vec2FP_Zero(var out : Vec2FP);
procedure Vec2FP_Add(var out : Vec2FP; const a, b : Vec2FP);
procedure Vec2FP_AddTo(var out : Vec2FP; const v : Vec2FP);
procedure Vec2FP_Sub(var out : Vec2FP; const a, b : Vec2FP);
procedure Vec2FP_SubFrom(var out : Vec2FP; const v : Vec2FP);
procedure Vec2FP_Scale(var out : Vec2FP; const a : Vec2FP; n : fixed);
procedure Vec2FP_ScaleThis(var out : Vec2FP; n : fixed);
function Vec2FP_Distance(const a, b : Vec2FP) : fixed;
function Vec2FP_DistanceSqr(const a, b : Vec2FP) : fixed;
function Vec2FP_Dot(const a, b : Vec2FP) : fixed;
function Vec2FP_Length(const a : Vec2FP) : fixed;
function Vec2FP_LengthSqr(const a : Vec2FP) : fixed;
procedure Vec2FP_Normalize(var out : Vec2FP; const a : Vec2FP);
procedure Vec2FP_NormalizeThis(var out : Vec2FP);
procedure Vec2FP_SetLength(var out : Vec2FP; const a : Vec2FP; length : fixed);
procedure Vec2FP_SetThisLength(var out : Vec2FP; length : fixed);
procedure Vec2FP_Lerp(var out : Vec2FP; const a, b : Vec2FP; t : fixed);

procedure Mtx33FP_Identity(var out : Mtx33FP);
procedure Mtx33FP_RotationX(var out : Mtx33FP; angle : binangle);
procedure Mtx33FP_RotationY(var out : Mtx33FP; angle : binangle);
procedure Mtx33FP_RotationZ(var out : Mtx33FP; angle : binangle);
procedure Mtx33FP_Mul(var out, a, b : Mtx33FP);
procedure Mtx33FP_Transform2D(var out : Vec2FP; var m : Mtx33FP; var v : Vec2FP);
procedure Mtx33FP_Translation2D(var out : Mtx33FP; x, y : fixed);
procedure Mtx33FP_Scaling2D(var out : Mtx33FP; x, y : fixed);
procedure Mtx33FP_Rotation2D(var out : Mtx33FP; angle : binangle);

implementation

procedure InitTrigTablesFP;
{ populates the trig lookup tables with sin/cos/tan values for the entire
  range of binary angles supported (0 to BIN_ANGLE_MASK).
  fixed-point version of Math.InitTrigTables. }
var
  angle   : binangle;
  r, s, c : single;
begin
  for angle := 0 to BIN_ANGLE_MASK do begin
    r := angle * BIN_TO_RAD;
    s := sin(r);
    c := cos(r);

    SinTableFP[angle] := FloatToFix(s);
    CosTableFP[angle] := FloatToFix(c);
    if angle <= BIN_ANGLE_TAN_MASK then begin
      if (angle = BIN_ANGLE_90) or (angle = BIN_ANGLE_270) then
        TanTableFP[angle] := 0
      else
        TanTableFP[angle] := FloatToFix((s / c));
    end;
  end;
end;

function LerpFP(a, b, t: fixed) : fixed;
{ returns the interpolated value between the ranged defined by a and b.
  fixed-point version of Math.Lerp. }
begin
  LerpFP := a + FixMul((b - a), t);
end;

function InvLerpFP(a, b, lerped: fixed) : fixed;
{ returns the 't' value used in a call to Lerp that returned the given
  'lerped' value using the range a to b (approximately, anyway).
  fixed-point version of Math.InvLerp. }
begin
  InvLerpFP := FixDiv((lerped - a), (b - a));
end;

function AtanFP(x : fixed) : binangle;
{ calculates the arctangent of X. returns the result as a binary angle.
  functionally equivalent to ArcTan().
  fixed-point version of Math.Atan. }
var
  a, b, c : integer;
  d       : fixed;
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
    d := x - TanTableFP[c];

    if d > 0 then
      a := c + 1
    else if d < 0 then
      b := c - 1;
  until ((a > b) or (d = 0));

  if x >= 0 then
    AtanFP := c
  else
    AtanFP := -BIN_ANGLE_180 + c;
end;

function Atan2FP(y, x : fixed) : binangle;
{ calculates the arctangent of Y/X. returns the result as a binary angle.
  functionally equivalent to atan2() from the C runtime library.
  fixed-point version of Math.Atan2. }
var
  r : fixed;
  b : binangle;
begin
  if x = 0 then begin
    if y = 0 then begin
      Atan2FP := 0;
    end else begin
      if y < 0 then
        Atan2FP := -BIN_ANGLE_90
      else
        Atan2FP := BIN_ANGLE_90;
    end;
    exit;
  end;

  r := FixDiv(y, x);
  b := AtanFP(r);

  if x >= 0 then
    Atan2FP := b
  else if y >= 0 then
    Atan2FP := BIN_ANGLE_180 + b
  else
    Atan2FP := b - BIN_ANGLE_180;
end;

function AngleBetweenFP(x1, y1, x2, y2: fixed) : binangle;
{ calculates the binary angle between the two points.
  fixed-point version of Math.AngleBetween. }
var
  deltaX, deltaY : fixed;
begin
  deltaX := x2 - x1;
  deltaY := y2 - y1;
  if (deltaX = 0) and (deltaY = 0) then
    AngleBetweenFP := 0
  else
    AngleBetweenFP := Atan2FP(deltaY, deltaX);
end;

procedure AngleToDir2DFP(angle: binangle;
                         var outX, outY: fixed);
{ for a given binary angle, calculates a normalized 2D direction vector
  that points in the same direction as the angle.
  fixed-point version of Math.AngleToDir2D. }
begin
  outX := CosTableFP[angle and BIN_ANGLE_MASK];
  outY := SinTableFP[angle and BIN_ANGLE_MASK];
end;

procedure AngleToVec2DFP(angle: binangle;
                         var out: Vec2FP);
{ for a given binary angle, calculates a normalized Vec2 that points in the
  same direction as the angle.
  fixed-point version of Math.AngleToVec2D. }
begin
  with out do begin
    X := CosTableFP[angle and BIN_ANGLE_MASK];
    Y := SinTableFP[angle and BIN_ANGLE_MASK];
  end;
end;

procedure Vec2FP_Set(var out : Vec2FP; x, y : fixed);
begin
  out.X := x;
  out.Y := y;
end;

procedure Vec2FP_Zero(var out : Vec2FP);
begin
  with out do begin
    X := 0;
    Y := 0;
  end;
end;

procedure Vec2FP_Add(var out : Vec2FP; const a, b : Vec2FP);
begin
  with out do begin
    X := a.X + b.X;
    Y := a.Y + b.Y;
  end;
end;

procedure Vec2FP_AddTo(var out : Vec2FP; const v : Vec2FP);
begin
  inc(out.X, v.X);
  inc(out.Y, v.Y);
end;

procedure Vec2FP_Sub(var out : Vec2FP; const a, b : Vec2FP);
begin
  with out do begin
    X := a.X - b.X;
    Y := a.Y - b.Y;
  end;
end;

procedure Vec2FP_SubFrom(var out : Vec2FP; const v : Vec2FP);
begin
  dec(out.X, v.X);
  dec(out.Y, v.Y);
end;

procedure Vec2FP_Scale(var out : Vec2FP; const a : Vec2FP; n : fixed);
begin
  with out do begin
    X := FixMul(a.X, n);
    Y := FixMul(a.Y, n);
  end;
end;

procedure Vec2FP_ScaleThis(var out : Vec2FP; n : fixed);
begin
  with out do begin
    X := FixMul(X, n);
    Y := FixMul(Y, n);
  end;
end;

function Vec2FP_Distance(const a, b : Vec2FP) : fixed;
var
  j, k : fixed;
begin
  j := b.X - a.X;
  k := b.Y - a.Y;
  Vec2FP_Distance := FixSqrt(FixSqr(j) + FixSqr(k));
end;

function Vec2FP_DistanceSqr(const a, b : Vec2FP) : fixed;
var
  j, k : fixed;
begin
  j := b.X - a.X;
  k := b.Y - a.Y;
  Vec2FP_DistanceSqr := FixSqr(j) + FixSqr(k);
end;

function Vec2FP_Dot(const a, b : Vec2FP) : fixed;
begin
  Vec2FP_Dot := FixMul(a.X, b.X) + FixMul(a.Y, b.Y);
end;

function Vec2FP_Length(const a : Vec2FP) : fixed;
begin
  with a do begin
    Vec2FP_Length := FixSqrt(FixSqr(X) + FixSqr(Y));
  end;
end;

function Vec2FP_LengthSqr(const a : Vec2FP) : fixed;
begin
  with a do begin
    Vec2FP_LengthSqr := FixSqr(X) + FixSqr(Y);
  end;
end;

procedure Vec2FP_Normalize(var out : Vec2FP; const a : Vec2FP);
var
  inverseLength : fixed;
begin
  inverseLength := FixDiv(FP_1, Vec2FP_Length(a));
  with out do begin
    X := FixMul(a.X, inverseLength);
    Y := FixMul(a.Y, inverseLength);
  end;
end;

procedure Vec2FP_NormalizeThis(var out : Vec2FP);
var
  inverseLength : fixed;
begin
  inverseLength := FixDiv(FP_1, Vec2FP_Length(out));
  with out do begin
    X := FixMul(X, inverseLength);
    Y := FixMul(Y, inverseLength);
  end;
end;

procedure Vec2FP_SetLength(var out : Vec2FP; const a : Vec2FP; length : fixed);
var
  scale : fixed;
begin
  scale := FixDiv(length, Vec2FP_Length(a));
  with out do begin
    X := FixMul(a.X, scale);
    Y := FixMul(a.Y, scale);
  end;
end;

procedure Vec2FP_SetThisLength(var out : Vec2FP; length : fixed);
var
  scale : fixed;
begin
  scale := FixDiv(length, Vec2FP_Length(out));
  with out do begin
    X := FixMul(X, scale);
    Y := FixMul(Y, scale);
  end;
end;

procedure Vec2FP_Lerp(var out : Vec2FP; const a, b : Vec2FP; t : fixed);
begin
  with out do begin
    X := a.X + FixMul((b.X - a.X), t);
    Y := a.Y + FixMul((b.Y - a.Y), t);
  end;
end;

procedure Mtx33FP_Identity(var out : Mtx33FP);
begin
  with out do begin
    m[M33_11] := FP_1;
    m[M33_12] := 0;
    m[M33_13] := 0;

    m[M33_21] := 0;
    m[M33_22] := FP_1;
    m[M33_23] := 0;

    m[M33_31] := 0;
    m[M33_32] := 0;
    m[M33_33] := FP_1;
  end;
end;

procedure Mtx33FP_RotationX(var out : Mtx33FP; angle : binangle);
var
  s, c : fixed;
begin
  s := SinTableFP[angle and BIN_ANGLE_MASK];
  c := CosTableFP[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := FP_1;
    m[M33_12] := 0;
    m[M33_13] := 0;

    m[M33_21] := 0;
    m[M33_22] := c;
    m[M33_23] := -s;

    m[M33_31] := 0;
    m[M33_32] := s;
    m[M33_33] := c;
  end;
end;

procedure Mtx33FP_RotationY(var out : Mtx33FP; angle : binangle);
var
  s, c : fixed;
begin
  s := SinTableFP[angle and BIN_ANGLE_MASK];
  c := CosTableFP[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := c;
    m[M33_12] := 0;
    m[M33_13] := s;

    m[M33_21] := 0;
    m[M33_22] := FP_1;
    m[M33_23] := 0;

    m[M33_31] := -s;
    m[M33_32] := 0;
    m[M33_33] := c;
  end;
end;

procedure Mtx33FP_RotationZ(var out : Mtx33FP; angle : binangle);
var
  s, c : fixed;
begin
  s := SinTableFP[angle and BIN_ANGLE_MASK];
  c := CosTableFP[angle and BIN_ANGLE_MASK];

  with out do begin
    m[M33_11] := c;
    m[M33_12] := -s;
    m[M33_13] := 0;

    m[M33_21] := s;
    m[M33_22] := c;
    m[M33_23] := 0;

    m[M33_31] := 0;
    m[M33_32] := 0;
    m[M33_33] := FP_1;
  end;
end;

procedure Mtx33FP_Mul(var out, a, b : Mtx33FP);
begin
  with out do begin
    m[M33_11] := FixMul(a.m[M33_11], b.m[M33_11]) + FixMul(a.m[M33_12], b.m[M33_21]) + FixMul(a.m[M33_13], b.m[M33_31]);
    m[M33_12] := FixMul(a.m[M33_11], b.m[M33_12]) + FixMul(a.m[M33_12], b.m[M33_22]) + FixMul(a.m[M33_13], b.m[M33_32]);
    m[M33_13] := FixMul(a.m[M33_11], b.m[M33_13]) + FixMul(a.m[M33_12], b.m[M33_23]) + FixMul(a.m[M33_13], b.m[M33_33]);

    m[M33_21] := FixMul(a.m[M33_21], b.m[M33_11]) + FixMul(a.m[M33_22], b.m[M33_21]) + FixMul(a.m[M33_23], b.m[M33_31]);
    m[M33_22] := FixMul(a.m[M33_21], b.m[M33_12]) + FixMul(a.m[M33_22], b.m[M33_22]) + FixMul(a.m[M33_23], b.m[M33_32]);
    m[M33_23] := FixMul(a.m[M33_21], b.m[M33_13]) + FixMul(a.m[M33_22], b.m[M33_23]) + FixMul(a.m[M33_23], b.m[M33_33]);

    m[M33_31] := FixMul(a.m[M33_31], b.m[M33_11]) + FixMul(a.m[M33_32], b.m[M33_21]) + FixMul(a.m[M33_33], b.m[M33_31]);
    m[M33_32] := FixMul(a.m[M33_31], b.m[M33_12]) + FixMul(a.m[M33_32], b.m[M33_22]) + FixMul(a.m[M33_33], b.m[M33_32]);
    m[M33_33] := FixMul(a.m[M33_31], b.m[M33_13]) + FixMul(a.m[M33_32], b.m[M33_23]) + FixMul(a.m[M33_33], b.m[M33_33]);
  end;
end;

procedure Mtx33FP_Transform2D(var out : Vec2FP; var m : Mtx33FP; var v : Vec2FP);
begin
  with out do begin
    X := FixMul(v.X, m.m[M33_11]) + FixMul(v.Y, m.m[M33_12]) + m.m[M33_13];
    Y := FixMul(v.X, m.m[M33_21]) + FixMul(v.Y, m.m[M33_22]) + m.m[M33_23];
    X := X + m.m[M33_31];
    Y := Y + m.m[M33_32];
  end;
end;

procedure Mtx33FP_Translation2D(var out : Mtx33FP; x, y : fixed);
begin
  with out do begin
    m[M33_11] := FP_1;
    m[M33_12] := 0;
    m[M33_13] := 0;

    m[M33_21] := 0;
    m[M33_22] := FP_1;
    m[M33_23] := 0;

    m[M33_31] := x;
    m[M33_32] := y;
    m[M33_33] := FP_1;
  end;
end;

procedure Mtx33FP_Scaling2D(var out : Mtx33FP; x, y : fixed);
begin
  with out do begin
    m[M33_11] := x;
    m[M33_12] := 0;
    m[M33_13] := 0;

    m[M33_21] := 0;
    m[M33_22] := y;
    m[M33_23] := 0;

    m[M33_31] := 0;
    m[M33_32] := 0;
    m[M33_33] := FP_1;
  end;
end;

procedure Mtx33FP_Rotation2D(var out : Mtx33FP; angle : binangle);
begin
  Mtx33FP_RotationZ(out, angle);
end;


end.

