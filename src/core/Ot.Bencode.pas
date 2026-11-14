unit Ot.Bencode;

interface

uses System.SysUtils, System.Generics.Collections;

type
  TOtBencodeKind = (bkBytes, bkInteger, bkList, bkDictionary);
  TOtBencode = class
  public
    Kind: TOtBencodeKind;
    Bytes: TBytes;
    Number: Int64;
    Items: TObjectList<TOtBencode>;
    Fields: TObjectDictionary<string, TOtBencode>;
    constructor Create(AKind: TOtBencodeKind);
    destructor Destroy; override;
    function Find(const Key: string): TOtBencode;
    function Text: string;
    class function Decode(const Data: TBytes): TOtBencode; static;
  end;

implementation

constructor TOtBencode.Create(AKind: TOtBencodeKind);
begin
  inherited Create;
  Kind := AKind;
  if Kind = bkList then Items := TObjectList<TOtBencode>.Create(True);
  if Kind = bkDictionary then
    Fields := TObjectDictionary<string, TOtBencode>.Create([doOwnsValues]);
end;

destructor TOtBencode.Destroy;
begin
  Fields.Free;
  Items.Free;
  inherited;
end;

function TOtBencode.Find(const Key: string): TOtBencode;
begin
  Result := nil;
  if Fields <> nil then Fields.TryGetValue(Key, Result);
end;

function TOtBencode.Text: string;
var UTF8: TEncoding;
begin
  if Kind <> bkBytes then Exit('');
  UTF8 := TUTF8Encoding.Create(False);
  try
    try
      Result := UTF8.GetString(Bytes);
      if (Result = '') and (Length(Bytes) > 0) then Result := TEncoding.Default.GetString(Bytes);
    except
      on E: EEncodingError do Result := TEncoding.Default.GetString(Bytes);
    end;
  finally
    UTF8.Free;
  end;
end;

class function TOtBencode.Decode(const Data: TBytes): TOtBencode;
var Position, Nodes: Integer;
  procedure Invalid;
  begin
    raise EConvertError.Create('Invalid or oversized bencode data');
  end;
  function Parse(Depth: Integer): TOtBencode;
  var Marker: Byte; Start, Count: Integer; Value: Int64;
    Child, Key: TOtBencode; Name, Digits: string;
  begin
    Inc(Nodes);
    if (Depth > 64) or (Nodes > 250000) or (Position >= Length(Data)) then Invalid;
    Marker := Data[Position];
    Inc(Position);
    Result := nil;
    try
      case Char(Marker) of
        'i': begin
          Start := Position;
          while (Position < Length(Data)) and (Data[Position] <> Ord('e')) do Inc(Position);
          if (Position = Length(Data)) or (Position - Start > 20) then Invalid;
          Digits := TEncoding.ASCII.GetString(Data, Start, Position - Start);
          if not TryStrToInt64(Digits, Value) then Invalid;
          Result := TOtBencode.Create(bkInteger);
          Result.Number := Value;
          Inc(Position);
        end;
        'l', 'd': begin
          if Marker = Ord('l') then Result := TOtBencode.Create(bkList)
          else Result := TOtBencode.Create(bkDictionary);
          while (Position < Length(Data)) and (Data[Position] <> Ord('e')) do
          begin
            if Result.Kind = bkList then Result.Items.Add(Parse(Depth + 1))
            else begin
              Key := Parse(Depth + 1);
              try
                if Key.Kind <> bkBytes then Invalid;
                Name := Key.Text;
              finally
                Key.Free;
              end;
              if Result.Fields.ContainsKey(Name) then Invalid;
              Child := Parse(Depth + 1);
              try
                Result.Fields.Add(Name, Child);
              except
                Child.Free;
                raise;
              end;
            end;
          end;
          if Position = Length(Data) then Invalid;
          Inc(Position);
        end;
        '0'..'9': begin
          Value := Marker - Ord('0');
          while (Position < Length(Data)) and (Data[Position] <> Ord(':')) do
          begin
            if (Data[Position] < Ord('0')) or (Data[Position] > Ord('9')) or
              (Value > 67108864) then Invalid;
            Value := Value * 10 + Data[Position] - Ord('0');
            Inc(Position);
          end;
          if Position = Length(Data) then Invalid;
          Inc(Position);
          if (Value > Length(Data) - Position) then Invalid;
          Count := Integer(Value);
          Result := TOtBencode.Create(bkBytes);
          Result.Bytes := Copy(Data, Position, Count);
          Inc(Position, Count);
        end;
      else Invalid;
      end;
    except
      Result.Free;
      raise;
    end;
  end;
begin
  if (Length(Data) = 0) or (Length(Data) > 67108864) then Invalid;
  Position := 0;
  Nodes := 0;
  Result := Parse(0);
  if Position <> Length(Data) then
  begin
    Result.Free;
    Invalid;
  end;
end;

end.
