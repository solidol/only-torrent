unit Ot.TransferMath;

interface

function RemainingSeconds(Total, Done: Int64; BytesPerSecond: Integer): Int64;
function DiskUsedPixels(Total, Free: Int64; Width: Integer): Integer;

implementation

uses System.Math;

function RemainingSeconds(Total, Done: Int64; BytesPerSecond: Integer): Int64;
begin
  if BytesPerSecond <= 0 then Exit(-1);
  Result := Max(Int64(0), Total - Done) div BytesPerSecond;
end;

function DiskUsedPixels(Total, Free: Int64; Width: Integer): Integer;
begin
  if (Total <= 0) or (Width <= 0) then Exit(0);
  Result := EnsureRange(Round(Width * ((Total - Free) / Total)), 0, Width);
end;

end.
