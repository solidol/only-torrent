unit Ot.TrackerMerge;

interface

type
  TOtTrackerMerge = record
    All, Added: TArray<string>;
  end;

function MergeTrackers(const Current, Incoming: TArray<string>): TOtTrackerMerge;
function TrackerRequests(const InfoHash: string; const Trackers: TArray<string>): TArray<string>;

implementation

uses System.SysUtils, System.StrUtils, System.Generics.Collections, Ot.Localization;

function MergeTrackers(const Current, Incoming: TArray<string>): TOtTrackerMerge;
var Seen: TDictionary<string,Byte>; All, Added: TList<string>; Url: string;
  procedure Include(const Value: string; IsNew: Boolean);
  var Clean: string;
  begin
    Clean := Trim(Value);
    if Clean='' then Exit;
    if (Pos(#0,Clean)>0) or (Pos(#10,Clean)>0) or (Pos(#13,Clean)>0) or
      not (StartsText('http://',Clean) or StartsText('https://',Clean) or StartsText('udp://',Clean)) then
      raise EArgumentException.Create(L('text.68666af49b79','Трекер має використовувати http, https або udp.'));
    // Compare the full URL exactly: path, query and passkeys are case-sensitive.
    if Seen.ContainsKey(Clean) then Exit;
    Seen.Add(Clean,0); All.Add(Clean);
    if IsNew then Added.Add(Clean);
  end;
begin
  Seen := TDictionary<string,Byte>.Create; All := TList<string>.Create; Added := TList<string>.Create;
  try
    for Url in Current do Include(Url,False);
    for Url in Incoming do Include(Url,True);
    Result.All := All.ToArray; Result.Added := Added.ToArray;
  finally Added.Free; All.Free; Seen.Free; end;
end;

function EncodeUrl(const Url: string): string;
const Hex: string = '0123456789ABCDEF';
var Value: Byte; Bytes: TBytes; Builder: TStringBuilder;
begin
  Bytes := TEncoding.UTF8.GetBytes(Url); Builder := TStringBuilder.Create;
  try
    for Value in Bytes do
      if CharInSet(Char(Value),['a'..'z','A'..'Z','0'..'9','-','.','_','~']) then Builder.Append(Char(Value))
      else begin Builder.Append('%'); Builder.Append(Hex[(Value shr 4)+1]); Builder.Append(Hex[(Value and 15)+1]); end;
    Result := Builder.ToString;
  finally Builder.Free; end;
end;

function TrackerRequests(const InfoHash: string; const Trackers: TArray<string>): TArray<string>;
var Prefix, Request, Part, Url: string; C: Char; Requests: TList<string>;
begin
  if Length(InfoHash)<>40 then raise EArgumentException.Create('Invalid tracker info-hash');
  for C in InfoHash do if not CharInSet(C,['0'..'9','a'..'f','A'..'F']) then
    raise EArgumentException.Create('Invalid tracker info-hash');
  Prefix := 'magnet:?xt=urn:btih:'+InfoHash; Request := Prefix;
  Requests := TList<string>.Create;
  try
    for Url in Trackers do
    begin
      Part := '&tr='+EncodeUrl(Url);
      if Length(Prefix)+Length(Part)>32768 then
        raise EArgumentException.Create(L('duplicate.longTracker','Адреса трекера занадто довга.'));
      if Length(Request)+Length(Part)>32768 then
      begin Requests.Add(Request); Request := Prefix; end;
      Request := Request+Part;
    end;
    if Request<>Prefix then Requests.Add(Request);
    Result := Requests.ToArray;
  finally Requests.Free; end;
end;

end.
