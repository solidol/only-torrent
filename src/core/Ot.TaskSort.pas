unit Ot.TaskSort;

interface

uses Ot.Types;

type
  TOtTaskSortKey = record
    Number, StableId: Int64;
    Name: string;
    IsText: Boolean;
  end;

function TaskSortKey(const Name: string; const Snapshot: TOtSnapshot;
  Uploaded, StableId: Int64; Column: Integer; Deleting: Boolean): TOtTaskSortKey;
function CompareTaskKeys(const A, B: TOtTaskSortKey): Integer;
function SameTaskKey(const A, B: TOtTaskSortKey): Boolean;

implementation

uses System.SysUtils, Ot.TransferMath;

function Compare64(A, B: Int64): Integer;
begin
  if A < B then Result := -1 else if A > B then Result := 1 else Result := 0;
end;

function TaskSortKey(const Name: string; const Snapshot: TOtSnapshot;
  Uploaded, StableId: Int64; Column: Integer; Deleting: Boolean): TOtTaskSortKey;
begin
  Result := Default(TOtTaskSortKey);
  Result.Name := Name; Result.StableId := StableId; Result.IsText := Column = 1;
  case Column of
    0: Result.Number := Ord(not (Snapshot.State in [8,9]));
    2: Result.Number := Snapshot.TotalBytes;
    3: Result.Number := Snapshot.Progress;
    4: if Deleting then Result.Number := 10 else Result.Number := Snapshot.State;
    5: Result.Number := Snapshot.Seeds;
    6: Result.Number := Snapshot.Peers;
    7: Result.Number := Snapshot.DownloadRate;
    8: Result.Number := Snapshot.UploadRate;
    9: Result.Number := Snapshot.DoneBytes;
    10: begin
      if Snapshot.Progress >= 1000000 then Result.Number := 0
      else if Snapshot.DownloadRate <= 0 then Result.Number := High(Int64)
      else Result.Number := RemainingSeconds(Snapshot.TotalBytes,Snapshot.DoneBytes,Snapshot.DownloadRate);
    end;
    11: Result.Number := Uploaded;
  end;
end;

function CompareTaskKeys(const A, B: TOtTaskSortKey): Integer;
begin
  if A.IsText then Result := CompareText(A.Name,B.Name)
  else Result := Compare64(A.Number,B.Number);
  if Result = 0 then Result := CompareText(A.Name,B.Name);
  if Result = 0 then Result := Compare64(A.StableId,B.StableId);
end;

function SameTaskKey(const A, B: TOtTaskSortKey): Boolean;
begin
  Result := (A.Number=B.Number) and (A.StableId=B.StableId) and
    (A.Name=B.Name) and (A.IsText=B.IsText);
end;

end.
