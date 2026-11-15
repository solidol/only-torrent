unit Ot.StatusIcons;

interface

const OtIconCount = 20;

function TorrentStateIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
function TorrentStatusIcon(State: Integer; Uploading, Deleting: Boolean): Integer;

implementation

function TorrentStatusIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
begin
  if Deleting then Exit(6);
  case State of
    1,7: Result := 9;
    2: Result := 10;
    3: if Uploading then Result := 15 else Result := 11;
    4: Result := 12;
    5: Result := 13;
    6: Result := 14;
    8: Result := 3;
    9: Result := 1;
  else Result := 8;
  end;
end;

function TorrentStateIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
begin
  Result := TorrentStatusIcon(State,Uploading,Deleting);
  // Retain the original blue download glyph in the leading icon column.
  if Result = 11 then Result := 16 else if Result = 15 then Result := 17;
end;

end.
