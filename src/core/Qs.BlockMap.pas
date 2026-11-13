unit Qs.BlockMap;

interface

uses Qs.Types;

function BuildBlockMap(const State: TQsPieceState; Columns: Integer): TQsBlockMap;
function ResizeBlockMap(const Source: TQsBlockMap; Columns: Integer): TQsBlockMap;
function BlockLayerPixels(Height, Density: Integer): Integer;
function SameBlockMap(const Left, Right: TQsBlockMap): Boolean;

implementation

uses System.SysUtils, System.Math, System.Generics.Collections;

function SameBlockMap(const Left, Right: TQsBlockMap): Boolean;
  function SameBytes(const A, B: TBytes): Boolean;
  begin
    Result := Length(A) = Length(B);
    if Result and (Length(A) > 0) then
      Result := CompareMem(@A[0], @B[0], Length(A));
  end;
begin
  Result := (Left.TotalBlocks = Right.TotalBlocks) and
    (Left.BlockSize = Right.BlockSize) and
    SameBytes(Left.Verified, Right.Verified) and
    SameBytes(Left.Received, Right.Received) and
    SameBytes(Left.Requested, Right.Requested);
end;

function BucketStart(Total: Int64; Index, Count: Integer): Int64;
begin
  Result := (Total div Count) * Index + ((Total mod Count) * Index) div Count;
end;

function Density(Value, Total: Int64): Byte;
begin
  if Value <= 0 then Exit(0);
  if Value >= Total then Exit(255);
  if Value <= High(Int64) div 255 then
    Result := EnsureRange(Value * 255 div Total, Int64(1), Int64(254))
  else Result := EnsureRange(Trunc((Value / Total) * 255), Int64(1), Int64(254));
end;

function BuildBlockMap(const State: TQsPieceState; Columns: Integer): TQsBlockMap;
var PerPiece, Count, I, Piece, FirstBlock, EndBlock: Integer;
  LastBytes, First, Limit, V, R, Q: Int64;
  Groups: TObjectDictionary<Integer, TList<TQsPartialBlock>>;
  List: TList<TQsPartialBlock>; Block: TQsPartialBlock; Verified: Boolean;
begin
  Result := Default(TQsBlockMap);
  if (Columns < 1) or (Columns > 4096) then
    raise EArgumentOutOfRangeException.Create('Block map columns must be 1..4096');
  if (State.TotalBytes = 0) and (State.PieceCount = 0) then Exit;
  if (State.PieceCount < 1) or (State.PieceLength < 1) or
    (State.BlockSize < 1) or (State.BlockSize > State.PieceLength) then
    raise EArgumentException.Create('Invalid piece geometry');
  LastBytes := State.TotalBytes - Int64(State.PieceCount - 1) * State.PieceLength;
  if (LastBytes < 1) or (LastBytes > State.PieceLength) then
    raise EArgumentException.Create('Invalid torrent size');
  PerPiece := 1 + (State.PieceLength - 1) div State.BlockSize;
  Result.TotalBlocks := Int64(State.PieceCount - 1) * PerPiece +
    1 + (LastBytes - 1) div State.BlockSize;
  Result.BlockSize := State.BlockSize;
  Count := Min(Int64(Columns), Result.TotalBlocks);
  SetLength(Result.Verified, Count);
  SetLength(Result.Received, Count);
  SetLength(Result.Requested, Count);
  if State.IsSeeding then
  begin
    FillChar(Result.Verified[0], Count, 255);
    FillChar(Result.Received[0], Count, 255);
    FillChar(Result.Requested[0], Count, 255);
    Exit;
  end;
  Groups := TObjectDictionary<Integer, TList<TQsPartialBlock>>.Create([doOwnsValues]);
  try
    for Block in State.PartialBlocks do
    begin
      if (Block.Piece < 0) or (Block.Piece >= State.PieceCount) or
        (Block.Block < 0) or (Block.Block >= PerPiece) then
        raise EArgumentException.Create('Invalid partial block index');
      if not Groups.TryGetValue(Block.Piece, List) then
      begin
        List := TList<TQsPartialBlock>.Create;
        Groups.Add(Block.Piece, List);
      end;
      List.Add(Block);
    end;
    for I := 0 to Count - 1 do
    begin
      First := BucketStart(Result.TotalBlocks, I, Count);
      Limit := BucketStart(Result.TotalBlocks, I + 1, Count);
      V := 0; R := 0; Q := 0;
      for Piece := First div PerPiece to (Limit - 1) div PerPiece do
      begin
        FirstBlock := Max(Int64(0), First - Int64(Piece) * PerPiece);
        EndBlock := Min(Int64(PerPiece), Limit - Int64(Piece) * PerPiece);
        Verified := (Piece div 8 < Length(State.HavePieces)) and
          ((State.HavePieces[Piece div 8] and ($80 shr (Piece mod 8))) <> 0);
        if Verified then
        begin
          Inc(V, EndBlock - FirstBlock);
          Inc(R, EndBlock - FirstBlock);
          Inc(Q, EndBlock - FirstBlock);
        end
        else if Groups.TryGetValue(Piece, List) then
          for Block in List do
            if (Block.Block >= FirstBlock) and (Block.Block < EndBlock) then
              case Block.State of
                1: begin Inc(R); Inc(Q); end;
                2: Inc(Q);
              end;
      end;
      Result.Verified[I] := Density(V, Limit - First);
      Result.Received[I] := Density(R, Limit - First);
      Result.Requested[I] := Density(Q, Limit - First);
    end;
  finally
    Groups.Free;
  end;
end;

function ResizeBlockMap(const Source: TQsBlockMap; Columns: Integer): TQsBlockMap;
var I, J, First, Limit, Count, V, R, Q: Integer;
begin
  if (Length(Source.Verified) <> Length(Source.Received)) or
    (Length(Source.Verified) <> Length(Source.Requested)) then
    raise EArgumentException.Create('Inconsistent block map arrays');
  Count := Min(Max(0, Columns), Length(Source.Verified));
  if Count = Length(Source.Verified) then Exit(Source);
  Result := Default(TQsBlockMap);
  Result.TotalBlocks := Source.TotalBlocks;
  Result.BlockSize := Source.BlockSize;
  SetLength(Result.Verified, Count);
  SetLength(Result.Received, Count);
  SetLength(Result.Requested, Count);
  for I := 0 to Count - 1 do
  begin
    First := I * Length(Source.Verified) div Count;
    Limit := (I + 1) * Length(Source.Verified) div Count;
    V := 0; R := 0; Q := 0;
    for J := First to Limit - 1 do
    begin
      Inc(V, Source.Verified[J]); Inc(R, Source.Received[J]); Inc(Q, Source.Requested[J]);
    end;
    Result.Verified[I] := V div (Limit - First);
    Result.Received[I] := R div (Limit - First);
    Result.Requested[I] := Q div (Limit - First);
  end;
end;

function BlockLayerPixels(Height, Density: Integer): Integer;
begin
  if (Height <= 0) or (Density <= 0) then Exit(0);
  if Density >= 255 then Exit(Height);
  Result := Max(0, Min(Height - 1, Max(1, (Int64(Height) * Density + 127) div 255)));
end;

end.
