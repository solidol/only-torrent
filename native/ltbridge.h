#ifndef LTBRIDGE_H
#define LTBRIDGE_H
#include <stdint.h>
#ifdef __cplusplus
#define LT_EXTERN extern "C"
#define LT_NOEXCEPT noexcept
#else
#define LT_EXTERN extern
#define LT_NOEXCEPT
#endif
#ifdef LTBRIDGE_BUILD
#define LT_API LT_EXTERN __declspec(dllexport)
#else
#define LT_API LT_EXTERN __declspec(dllimport)
#endif
typedef struct snapshot snapshot;
typedef struct metadata_info metadata_info;
typedef struct metadata_file metadata_file;
typedef struct metadata_extra metadata_extra;
typedef struct lt_session_options lt_session_options;
typedef struct lt_piece_header lt_piece_header;
typedef struct lt_partial_block lt_partial_block;
// ABI 2: cdecl, Win64, default 8-byte alignment, UTF-8 text.
// All allocation and destruction of opaque handles happens inside ltbridge.
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
struct lt_session_options {
    uint32_t size;
    int32_t port, download_bytes, upload_bytes, connections;
    int32_t discovery_flags, stop_tracker_timeout, reserved;
};
struct lt_piece_header {
    int64_t total_bytes;
    int32_t piece_length, piece_count, block_size, partial_count, is_seed, have_bytes;
};
struct lt_partial_block { int32_t piece, block, state, reserved; };
// Partial states are library-neutral: 1 received, 2 requested. Verified data
// is represented by the packed MSB-first piece bitmap or is_seed.
LT_API int lt_version(void) LT_NOEXCEPT;
LT_API char const* lt_error(void) LT_NOEXCEPT;
LT_API char const* lt_libtorrent_version(void) LT_NOEXCEPT;
LT_API void* lt_create(lt_session_options const* options, char const* user_agent) LT_NOEXCEPT;
LT_API void lt_destroy(void* session) LT_NOEXCEPT;
LT_API int lt_add(void* session, char const* file, char const* path) LT_NOEXCEPT;
LT_API int lt_add_selected(void* session, char const* file, char const* path, int const* priorities, int count, int start) LT_NOEXCEPT;
LT_API int lt_add_prepared(void* session, char const* file, char const* path,
    int const* priorities, int count, int start, int sequential, int download_bytes, int upload_bytes,
    char const* const* paths, char const* const* trackers, int tracker_count) LT_NOEXCEPT;
LT_API int lt_snapshot(void* session, int id, snapshot* out) LT_NOEXCEPT;
LT_API int lt_command(void* session, int id, int command) LT_NOEXCEPT;
// Optional ABI 2 extension. Verify on disk and stop before downloading/seeding.
LT_API int lt_recheck_paused(void* session, int id) LT_NOEXCEPT;
// 0 no reply, 1 files deleted, 2 deletion failed, -1 API error.
LT_API int lt_remove_poll(void* session, int* id, char* error, int capacity) LT_NOEXCEPT;
LT_API int lt_configure(void* session, int port, int download_bytes, int upload_bytes, int connections) LT_NOEXCEPT;
LT_API void* lt_meta_open(char const* file) LT_NOEXCEPT;
LT_API void lt_meta_close(void* metadata) LT_NOEXCEPT;
LT_API int lt_meta_info(void* metadata, metadata_info* out) LT_NOEXCEPT;
LT_API int lt_meta_file(void* metadata, int index, metadata_file* out) LT_NOEXCEPT;
LT_API int lt_meta_tracker(void* metadata, int index, char* buffer, int capacity) LT_NOEXCEPT;
LT_API int lt_meta_extra(void* metadata, unsigned char const* bytes, int length, metadata_extra* out) LT_NOEXCEPT;
LT_API void* lt_piece_open(void* session, int id, lt_piece_header* out) LT_NOEXCEPT;
LT_API int lt_piece_bits(void* state, unsigned char* buffer, int capacity) LT_NOEXCEPT;
LT_API int lt_piece_blocks(void* state, lt_partial_block* buffer, int capacity) LT_NOEXCEPT;
LT_API void lt_piece_close(void* state) LT_NOEXCEPT;
// Additive ABI 2 persistence extension. Caller owns byte buffers; bridge owns blobs.
LT_API int lt_resume_request(void* session, int id, int flush) LT_NOEXCEPT;
LT_API void* lt_resume_poll(void* session, int* id, int* status, int* length) LT_NOEXCEPT;
LT_API int lt_blob_copy(void* blob, unsigned char* buffer, int capacity) LT_NOEXCEPT;
LT_API void lt_blob_close(void* blob) LT_NOEXCEPT;
// Metadata-only magnet resolver. No payload files are created or downloaded.
LT_API void* lt_magnet_open(char const* uri, int enable_dht) LT_NOEXCEPT;
// status: 0 waiting, 1 complete, -1 failure. A completed blob uses lt_blob_*.
LT_API void* lt_magnet_poll(void* job, int* status, int* length) LT_NOEXCEPT;
LT_API void lt_magnet_close(void* job) LT_NOEXCEPT;
LT_API int lt_apply_magnet(void* session, int id, char const* uri) LT_NOEXCEPT;
LT_API int lt_discovery(void* session, int enable_dht) LT_NOEXCEPT;
LT_API int lt_add_prepared_resume(void* session, char const* file, char const* path,
    int const* priorities, int count, int start, int sequential, int download_bytes, int upload_bytes,
    char const* const* paths, char const* const* trackers, int tracker_count,
    unsigned char const* resume, int resume_length, int* resume_used) LT_NOEXCEPT;
#endif
