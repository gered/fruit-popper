{$A+,B-,E+,F-,G+,I+,N+,P-,Q-,R-,S-,T-,V-,X+}

program MapEdit;

uses Maps;

procedure SaveMap(const filename : string; var map : MapFile);
var
  f      : file;
  header : array[0..2] of char;
begin
  Assign(f, filename);
  Rewrite(f, 1);

  header[0] := 'M'; header[1] := 'A'; header[2] := 'P';
  BlockWrite(f, header, SizeOf(header));

  BlockWrite(f, map, SizeOf(map));
end;

procedure SaveSimpleMap;
const
  filename : string = 'simple.map';
  data : MapArray = (
    74,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,75,
    73,26,24,38,24,38,24,39,16,16,16,16,40,24,38,24,38,24,27,73,
    73,25,70,25,70,25,70,18,15,15,15,15,19,70,25,70,25,70,25,73,
    73,44,24,54,24,52,16,33,15,15,15,15,32,16,53,24,54,24,47,73,
    73,25,70,25,70,18,15,15,15,15,15,15,15,15,19,70,25,70,25,73,
    73,44,24,54,24,36,15,15,15,15,15,15,15,15,37,24,54,24,47,73,
    73,25,70,25,70,18,15,15,15,15,15,15,15,15,19,70,25,70,25,73,
    73,44,24,54,24,50,17,31,15,15,15,15,30,17,51,24,54,24,47,73,
    73,25,70,25,70,25,70,18,15,15,15,15,19,70,25,70,25,70,25,73,
    73,28,24,41,24,41,24,42,17,17,17,17,43,24,41,24,41,24,29,73,
    76,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,72,77
  );
var
  map : MapFile;
begin
  FillChar(map, SizeOf(MapFile), 0);
  with map do begin
    with header do begin
      name         := 'Just a simple fruit garden';
      time         := 120;
      initialFruit := 10;
      maxFruit     := 32;
      player1x     := 7;
      player1y     := 5;
      player2x     := 12;
      player2y     := 5;
    end;
    map          := data;
  end;

  writeln('Saving ', filename);
  SaveMap(filename, map);
  writeln('Done!');
end;

procedure SaveSmallMap;
const
  filename : string = 'small.map';
  data : MapArray = (
    70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,
    70,00,00,00,00,00,02,01,01,01,01,01,01,03,00,00,00,00,00,70,
    70,00,02,01,03,00,04,01,01,05,00,04,01,01,11,06,06,08,00,70,
    70,02,01,01,05,00,00,20,21,71,20,21,00,04,13,06,06,06,08,70,
    70,01,01,05,70,00,00,18,32,16,33,19,00,00,70,06,06,06,10,70,
    70,01,01,00,00,00,00,22,31,15,15,32,21,00,02,13,06,10,00,70,
    70,04,05,00,00,07,08,00,18,30,17,31,32,21,01,01,01,03,00,70,
    70,00,00,70,07,06,10,00,22,23,00,22,17,23,01,01,01,01,00,70,
    70,00,70,00,09,10,00,81,72,80,00,00,00,00,04,01,01,05,00,70,
    70,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,70,
    70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  );
var
  map : MapFile;
begin
  FillChar(map, SizeOf(MapFile), 0);
  with map do begin
    with header do begin
      name         := 'Not a lot of growing space ...';
      time         := 120;
      initialFruit := 10;
      maxFruit     := 6;
      player1x     := 7;
      player1y     := 5;
      player2x     := 12;
      player2y     := 5;
    end;
    map          := data;
  end;

  writeln('Saving ', filename);
  SaveMap(filename, map);
  writeln('Done!');
end;

procedure SaveEdgesMap;
const
  filename : string = 'edges.map';
  data : MapArray = (
    70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,
    70,70,70,00,00,20,16,16,21,00,70,00,00,00,00,70,00,20,21,70,
    70,70,00,02,03,22,17,17,32,21,00,00,00,00,00,00,20,33,19,70,
    70,70,00,04,01,03,00,00,22,23,00,70,00,70,00,00,22,17,19,70,
    70,00,00,70,04,05,02,01,03,00,07,08,00,00,70,70,00,00,25,70,
    70,00,00,70,70,00,04,01,05,70,06,06,70,02,03,70,70,00,25,70,
    70,00,00,00,00,70,00,70,02,01,13,14,05,01,01,01,03,20,48,70,
    70,20,21,00,00,00,00,00,04,01,01,05,00,04,01,01,05,18,19,70,
    70,18,32,16,21,02,11,08,70,04,20,16,16,16,21,00,70,22,23,70,
    70,22,17,17,23,04,13,10,00,00,22,17,17,17,23,00,00,00,00,70,
    70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70
  );
var
  map : MapFile;
begin
  FillChar(map, SizeOf(MapFile), 0);
  with map do begin
    with header do begin
      name         := 'Growing space along the edges.';
      time         := 120;
      initialFruit := 10;
      maxFruit     := 10;
      player1x     := 5;
      player1y     := 4;
      player2x     := 14;
      player2y     := 6;
    end;
    map          := data;
  end;

  writeln('Saving ', filename);
  SaveMap(filename, map);
  writeln('Done!');
end;

begin
  SaveSimpleMap;
  SaveSmallMap;
  SaveEdgesMap;
end.