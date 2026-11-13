#ifndef QSBRIDGE_H
#define QSBRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
#define QS_EXTERN extern "C"
#define QS_NOEXCEPT noexcept
#else
#define QS_EXTERN extern
#define QS_NOEXCEPT
#endif
#ifdef QSBRIDGE_BUILD
#define QS_API QS_EXTERN __declspec(dllexport)
#else
#define QS_API QS_EXTERN __declspec(dllimport)
#endif
typedef struct snapshot snapshot;
typedef struct metadata_info metadata_info;
typedef struct metadata_file metadata_file;
typedef struct metadata_extra metadata_extra;
typedef struct qs_session_options qs_session_options;
typedef struct qs_piece_header qs_piece_header;
typedef struct qs_partial_block qs_partial_block;
// ABI 2: cdecl, Win64, default 8-byte alignment, UTF-8 text.
// All allocation and destruction of opaque handles happens inside qsbridge.
struct snapshot {
    int64_t total, done;
    int32_t download_rate, upload_rate, peers, seeds, state, progress;
    char name[512], error[512];
};
struct metadata_info { int64_t total; int32_t files, trackers; char name[512], comment[1024]; };
struct metadata_file { int64_t size; char path[4096]; };
struct metadata_extra {
    int64_t created;
    int32_t pieces, piece_length;
    char creator[512], publisher[512], publisher_url[2048];
    uint8_t hash[32]; // first 20 bytes are the raw SHA-1; remainder reserved
    char web_seeds[4096];
};
struct qs_session_options {
    uint32_t size;
    int32_t port, download_bytes, upload_bytes, connections;
    int32_t discovery_flags, stop_tracker_timeout, reserved;
};
struct qs_piece_header {
    int64_t total_bytes;
    int32_t piece_length, piece_count, block_size, partial_count, is_seed, have_bytes;
};
struct qs_partial_block { int32_t piece, block, state, reserved; };
// Partial states are library-neutral: 1 received, 2 requested. Verified data
// is represented by the packed MSB-first piece bitmap or is_seed.
QS_API int qs_version(void) QS_NOEXCEPT;
QS_API char const* qs_error(void) QS_NOEXCEPT;
QS_API char const* qs_libtorrent_version(void) QS_NOEXCEPT;
QS_API void* qs_create(qs_session_options const* options, char const* user_agent) QS_NOEXCEPT;
QS_API void qs_destroy(void* session) QS_NOEXCEPT;
QS_API int qs_add(void* session, char const* file, char const* path) QS_NOEXCEPT;
QS_API int qs_add_selected(void* session, char const* file, char const* path, int const* priorities, int count, int start) QS_NOEXCEPT;
QS_API int qs_add_prepared(void* session, char const* file, char const* path,
    int const* priorities, int count, int start, int sequential, int download_bytes, int upload_bytes,
    char const* const* paths, char const* const* trackers, int tracker_count) QS_NOEXCEPT;
QS_API int qs_snapshot(void* session, int id, snapshot* out) QS_NOEXCEPT;
QS_API int qs_command(void* session, int id, int command) QS_NOEXCEPT;
QS_API int qs_configure(void* session, int port, int download_bytes, int upload_bytes, int connections) QS_NOEXCEPT;
QS_API void* qs_meta_open(char const* file) QS_NOEXCEPT;
QS_API void qs_meta_close(void* metadata) QS_NOEXCEPT;
QS_API int qs_meta_info(void* metadata, metadata_info* out) QS_NOEXCEPT;
QS_API int qs_meta_file(void* metadata, int index, metadata_file* out) QS_NOEXCEPT;
QS_API int qs_meta_tracker(void* metadata, int index, char* buffer, int capacity) QS_NOEXCEPT;
QS_API int qs_meta_extra(void* metadata, unsigned char const* bytes, int length, metadata_extra* out) QS_NOEXCEPT;
QS_API void* qs_piece_open(void* session, int id, qs_piece_header* out) QS_NOEXCEPT;
QS_API int qs_piece_bits(void* state, unsigned char* buffer, int capacity) QS_NOEXCEPT;
QS_API int qs_piece_blocks(void* state, qs_partial_block* buffer, int capacity) QS_NOEXCEPT;
QS_API void qs_piece_close(void* state) QS_NOEXCEPT;
#endif
