unit Qs.Types;

interface

uses System.SysUtils;

type
  TQsBlockMap = record
    Verified, Received, Requested: TBytes;
    TotalBlocks: Int64;
    BlockSize: Integer;
  end;
  TQsAddOptions = record
    Subfolder, Trackers: string;
    Start, Sequential: Boolean;
    DownloadKiB, UploadKiB: Integer;
  end;
  TQsMetaFile = record
    Size: Int64;
    Path: string;
  end;
  TQsMetadata = class
  public
    Name, Comment, Creator, Publisher, PublisherURL, InfoHash, WebSeeds: string;
    CreatedUTC: Int64;
    Pieces, PieceLength: Integer;
    TotalBytes: Int64;
    Files: TArray<TQsMetaFile>;
    Trackers: TArray<string>;
  end;
  TQsSnapshot = record
    TotalBytes: Int64;
    DoneBytes: Int64;
    DownloadRate: Integer;
    UploadRate: Integer;
    Peers: Integer;
    Seeds: Integer;
    State: Integer;
    Progress: Integer; // millionths
    Name: array[0..511] of AnsiChar; // UTF-8
    Error: array[0..511] of AnsiChar;
  end;
  TQsSessionOptions = record
    Size: Cardinal;
    Port, DownloadBytes, UploadBytes, Connections: Integer;
    DiscoveryFlags, StopTrackerTimeout, Reserved: Integer;
  end;
  TQsPartialBlock = record
    Piece, Block, State, Reserved: Integer;
  end;
  TQsPieceHeader = record
    TotalBytes: Int64;
    PieceLength, PieceCount, BlockSize, PartialCount, IsSeed, HaveBytes: Integer;
  end;
  TQsPieceState = record
    TotalBytes: Int64;
    PieceLength, PieceCount, BlockSize: Integer;
    IsSeeding: Boolean;
    HavePieces: TBytes; // MSB-first bitfield
    PartialBlocks: TArray<TQsPartialBlock>;
  end;
  TQsPreparedTask = record
    Paths, Trackers: TArray<string>;
    DownloadBytes, UploadBytes: Integer;
  end;
  TQsSelectionSummary = record
    Count: Integer;
    Bytes: Int64;
    Counts, Selected: array[0..3] of Integer;
  end;

implementation

end.
