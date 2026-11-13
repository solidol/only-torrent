unit Qs.BridgeApi;

interface

uses System.SysUtils, Qs.Types;

const QS_ABI_VERSION = 2;

type
  TQsMetaInfoRaw = record
    Total: Int64;
    Files, Trackers: Integer;
    Name: array[0..511] of AnsiChar;
    Comment: array[0..1023] of AnsiChar;
  end;
  TQsMetaFileRaw = record
    Size: Int64;
    Path: array[0..4095] of AnsiChar;
  end;
  TQsMetaExtraRaw = record
    Created: Int64;
    Pieces, PieceLength: Integer;
    Creator, Publisher: array[0..511] of AnsiChar;
    PublisherURL: array[0..2047] of AnsiChar;
    Hash: array[0..31] of Byte;
    WebSeeds: array[0..4095] of AnsiChar;
  end;
  TQsVersion = function: Integer; cdecl;
  TQsCreate = function(Options: Pointer; UserAgent: PAnsiChar): Pointer; cdecl;
  TQsDestroy = procedure(Session: Pointer); cdecl;
  TQsAdd = function(Session: Pointer; FileName, SavePath: PAnsiChar): Integer; cdecl;
  TQsSnapshotProc = function(Session: Pointer; Id: Integer; out Value: TQsSnapshot): Integer; cdecl;
  TQsCommand = function(Session: Pointer; Id, Command: Integer): Integer; cdecl;
  TQsError = function: PAnsiChar; cdecl;
  TQsMetaOpen = function(FileName: PAnsiChar): Pointer; cdecl;
  TQsMetaClose = procedure(Metadata: Pointer); cdecl;
  TQsMetaInfoProc = function(Metadata: Pointer; out Info: TQsMetaInfoRaw): Integer; cdecl;
  TQsMetaFileProc = function(Metadata: Pointer; Index: Integer; out Info: TQsMetaFileRaw): Integer; cdecl;
  TQsMetaTracker = function(Metadata: Pointer; Index: Integer; Buffer: PAnsiChar; Capacity: Integer): Integer; cdecl;
  TQsAddSelected = function(Session: Pointer; FileName, SavePath: PAnsiChar;
    Priorities: PInteger; Count, Start: Integer): Integer; cdecl;
  TQsConfigure = function(Session: Pointer; Port, DownKiB, UpKiB, Connections: Integer): Integer; cdecl;
  TQsMetaExtraProc = function(Metadata: Pointer; Data: PByte; Length: Integer; out Info: TQsMetaExtraRaw): Integer; cdecl;
  PPQsAnsiChar = ^PAnsiChar;
  TQsAddPrepared = function(Session: Pointer; FileName, Path: PAnsiChar;
    Priorities: PInteger; Count, Start, Sequential, DownloadBytes, UploadBytes: Integer;
    Paths, Trackers: PPQsAnsiChar; TrackerCount: Integer): Integer; cdecl;
  TQsPieceOpen = function(Session: Pointer; Id: Integer; out Header: TQsPieceHeader): Pointer; cdecl;
  TQsPieceBits = function(State: Pointer; Buffer: PByte; Capacity: Integer): Integer; cdecl;
  TQsPieceBlocks = function(State: Pointer; Buffer: Pointer; Capacity: Integer): Integer; cdecl;
  TQsPieceClose = procedure(State: Pointer); cdecl;
  TQsLibraryVersion = function: PAnsiChar; cdecl;
  TQsResumeRequest = function(Session: Pointer; Id, Flush: Integer): Integer; cdecl;
  TQsResumePoll = function(Session: Pointer; out Id, Status, Length: Integer): Pointer; cdecl;
  TQsBlobCopy = function(Blob: Pointer; Buffer: PByte; Capacity: Integer): Integer; cdecl;
  TQsBlobClose = procedure(Blob: Pointer); cdecl;
  TQsAddPreparedResume = function(Session: Pointer; FileName, Path: PAnsiChar;
    Priorities: PInteger; Count, Start, Sequential, DownloadBytes, UploadBytes: Integer;
    Paths, Trackers: PPQsAnsiChar; TrackerCount: Integer; Resume: PByte;
    ResumeLength: Integer; out ResumeUsed: Integer): Integer; cdecl;

implementation

end.
