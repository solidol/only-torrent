#include "qsbridge.h"
#include <libtorrent/version.hpp>
#include <windows.h>
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/alert.hpp>
#include <libtorrent/file_storage.hpp>
#include <libtorrent/bdecode.hpp>
#include <algorithm>
#include <map>
#include <memory>
#include <cstring>
#include <cstdint>
#include <string>
#include <stdexcept>

namespace lt = libtorrent;
static_assert(sizeof(snapshot) == 1064, "snapshot ABI mismatch");
static_assert(sizeof(metadata_info) == 1552, "metadata ABI mismatch");
static_assert(sizeof(metadata_file) == 4104, "file ABI mismatch");
static_assert(sizeof(metadata_extra) == 7216, "extra metadata ABI mismatch");
static_assert(sizeof(qs_session_options) == 32, "session ABI mismatch");
static_assert(sizeof(qs_piece_header) == 32, "piece header ABI mismatch");
static_assert(sizeof(qs_partial_block) == 16, "partial block ABI mismatch");
struct engine {
    lt::session session;
    std::map<int, lt::torrent_handle> torrents;
    int next_id = 1;
    explicit engine(lt::settings_pack const& p) : session(p) {}
};
thread_local std::string last_error;
static engine& get(void* p) {
    if (!p) throw std::runtime_error("Invalid engine handle");
    return *static_cast<engine*>(p);
}
static void copy(char* dst, size_t capacity, std::string const& value) {
    size_t n = (std::min)(capacity - 1, value.size());
    // Avoid truncating inside a UTF-8 sequence.
    if (n < value.size()) while (n && (static_cast<unsigned char>(value[n]) & 0xc0) == 0x80) --n;
    std::memcpy(dst, value.data(), n);
    dst[n] = 0;
}
QS_API int qs_version() noexcept { return 2; }
QS_API char const* qs_libtorrent_version() noexcept { return lt::version(); }
QS_API char const* qs_error() noexcept { return last_error.c_str(); }
QS_API void* qs_create(qs_session_options const* options, char const* user_agent) noexcept {
    try {
        if (!options || options->size != sizeof(qs_session_options)) throw std::runtime_error("Invalid session options ABI");
        lt::settings_pack p;
        p.set_bool(lt::settings_pack::enable_dht, (options->discovery_flags & 1) != 0);
        p.set_bool(lt::settings_pack::enable_lsd, (options->discovery_flags & 2) != 0);
        p.set_bool(lt::settings_pack::enable_upnp, (options->discovery_flags & 4) != 0);
        p.set_bool(lt::settings_pack::enable_natpmp, (options->discovery_flags & 8) != 0);
        std::string port = std::to_string(options->port);
        p.set_str(lt::settings_pack::listen_interfaces, "0.0.0.0:" + port + ",[::]:" + port);
        if (user_agent) p.set_str(lt::settings_pack::user_agent, user_agent);
        p.set_int(lt::settings_pack::stop_tracker_timeout, options->stop_tracker_timeout);
        p.set_int(lt::settings_pack::download_rate_limit, options->download_bytes);
        p.set_int(lt::settings_pack::upload_rate_limit, options->upload_bytes);
        p.set_int(lt::settings_pack::connections_limit, options->connections);
        return new engine(p);
    } catch (std::exception const& e) { last_error = e.what(); return nullptr; }
      catch (...) { last_error = "Engine initialization error"; return nullptr; }
}
QS_API void qs_destroy(void* p) noexcept {
    try { delete static_cast<engine*>(p); } catch (...) {}
}
QS_API int qs_add(void* p, char const* file, char const* path) noexcept {
    try {
        auto& e = get(p);
        if (!file || !path || !*path) throw std::runtime_error("Missing torrent or save path");
        lt::error_code ec;
        lt::add_torrent_params a;
        a.ti = std::make_shared<lt::torrent_info>(std::string(file), ec);
        if (ec) throw std::runtime_error(ec.message());
        a.save_path = path;
        a.flags &= ~lt::torrent_flags::paused;
        a.flags &= ~lt::torrent_flags::auto_managed;
        a.flags |= lt::torrent_flags::duplicate_is_error;
        auto h = e.session.add_torrent(a, ec);
        if (ec) throw std::runtime_error(ec.message());
        int id = e.next_id++;
        e.torrents.emplace(id, h);
        return id;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Unknown add error"; return -1; }
}
// Normalize library enums to our stable C protocol. A future libtorrent adapter
// may change this mapping without changing Delphi models or forms.
#pragma warning(push)
#pragma warning(disable: 4996)
static int protocol_state(lt::torrent_status::state_t state) {
    switch (state) {
    case lt::torrent_status::checking_files: return 1;
    case lt::torrent_status::downloading_metadata: return 2;
    case lt::torrent_status::downloading: return 3;
    case lt::torrent_status::finished: return 4;
    case lt::torrent_status::seeding: return 5;
    case lt::torrent_status::checking_resume_data: return 7;
#if TORRENT_ABI_VERSION == 1
    case lt::torrent_status::queued_for_checking: return 0;
    case lt::torrent_status::allocating: return 6;
#endif
    default: return 0;
    }
}
#pragma warning(pop)
QS_API int qs_snapshot(void* p, int id, snapshot* out) noexcept {
    try {
        if (!out) throw std::runtime_error("Missing output buffer");
        auto& e = get(p);
        // Drain alerts so the bounded queue does not retain obsolete notifications.
        std::vector<lt::alert*> alerts;
        e.session.pop_alerts(&alerts);
        auto s = e.torrents.at(id).status();
        *out = {};
        out->total = s.total_wanted;
        out->done = s.total_wanted_done;
        out->download_rate = s.download_payload_rate;
        out->upload_rate = s.upload_payload_rate;
        out->peers = s.num_peers;
        out->seeds = s.num_seeds;
        out->state = protocol_state(s.state);
        if (s.flags & lt::torrent_flags::paused) out->state = 8;
        if (s.errc) out->state = 9;
        out->progress = s.progress_ppm;
        copy(out->name, sizeof(out->name), s.name);
        if (s.errc) copy(out->error, sizeof(out->error), s.errc.message());
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Unknown snapshot error"; return -1; }
}
QS_API int qs_command(void* p, int id, int command) noexcept {
    try {
        auto& e = get(p);
        auto h = e.torrents.at(id);
        switch (command) {
        case 0: h.pause(); break;
        case 1: h.resume(); break;
        case 2: e.session.remove_torrent(h); e.torrents.erase(id); break;
        default: throw std::runtime_error("Unknown command");
        }
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Unknown command error"; return -1; }
}

QS_API int qs_meta_extra(void* p, unsigned char const* data, int length, metadata_extra* out) noexcept {
    try {
        if (!p || !data || length <= 0 || !out) throw std::runtime_error("Invalid metadata buffer");
        auto& t = *static_cast<lt::torrent_info*>(p);
        *out = {};
        out->created = static_cast<int64_t>(t.creation_date());
        out->pieces = t.num_pieces(); out->piece_length = t.piece_length();
        copy(out->creator, sizeof(out->creator), t.creator());
        auto hash = t.info_hash();
        std::memcpy(out->hash, hash.data(), 20);
        std::string seeds;
        for (auto const& seed : t.web_seeds()) seeds += seed.url + "\r\n";
        copy(out->web_seeds, sizeof(out->web_seeds), seeds);
        lt::error_code ec;
        auto root = lt::bdecode(lt::span<char const>(reinterpret_cast<char const*>(data), length), ec);
        if (ec) throw std::runtime_error(ec.message());
        copy(out->publisher, sizeof(out->publisher), root.dict_find_string_value("publisher").to_string());
        copy(out->publisher_url, sizeof(out->publisher_url), root.dict_find_string_value("publisher-url").to_string());
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Metadata error"; return -1; }
}

struct piece_data {
    std::vector<unsigned char> have;
    std::vector<qs_partial_block> partial;
};
QS_API void* qs_piece_open(void* p, int id, qs_piece_header* out) noexcept {
    try {
        if (!out) throw std::runtime_error("Missing piece header");
        auto h = get(p).torrents.at(id);
        auto info = h.torrent_file();
        if (!info) throw std::runtime_error("Torrent metadata is unavailable");
        auto result = std::unique_ptr<piece_data>(new piece_data);
        auto status = h.status(lt::torrent_handle::query_pieces);
        *out = {};
        out->total_bytes = info->total_size();
        out->piece_length = info->piece_length(); out->piece_count = info->num_pieces();
        out->block_size = status.block_size > 0 ? status.block_size : (std::min)(16384, info->piece_length());
        out->is_seed = status.is_seeding ? 1 : 0;
        if (!status.is_seeding) {
            // Marshal libtorrent's public piece bitfield; no display aggregation.
            result->have.resize(static_cast<size_t>((status.pieces.size() + 7) / 8), 0);
            // libtorrent's bitfield::data() is already network/MSB-first order.
            if (!result->have.empty())
                std::memcpy(result->have.data(), status.pieces.data(), result->have.size());
            std::vector<lt::partial_piece_info> queue;
            h.get_download_queue(queue);
            for (auto const& piece : queue)
                for (int block = 0; block < piece.blocks_in_piece; ++block) {
                    auto state = piece.blocks[block].state;
                    if (state == lt::block_info::finished || state == lt::block_info::writing)
                        result->partial.push_back({static_cast<int>(piece.piece_index), block, 1, 0});
                    else if (state == lt::block_info::requested)
                        result->partial.push_back({static_cast<int>(piece.piece_index), block, 2, 0});
                }
        }
        out->have_bytes = static_cast<int>(result->have.size());
        out->partial_count = static_cast<int>(result->partial.size());
        return result.release();
    } catch (std::exception const& e) { last_error = e.what(); return nullptr; }
      catch (...) { last_error = "Piece snapshot error"; return nullptr; }
}
QS_API int qs_piece_bits(void* p, unsigned char* buffer, int capacity) noexcept {
    try {
        if (!p) throw std::runtime_error("Invalid piece snapshot");
        auto const& bytes = static_cast<piece_data*>(p)->have;
        if (capacity < static_cast<int>(bytes.size()) || (!buffer && !bytes.empty())) throw std::runtime_error("Piece buffer is too small");
        if (!bytes.empty()) std::memcpy(buffer, bytes.data(), bytes.size());
        return static_cast<int>(bytes.size());
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Piece copy error"; return -1; }
}
QS_API int qs_piece_blocks(void* p, qs_partial_block* buffer, int capacity) noexcept {
    try {
        if (!p) throw std::runtime_error("Invalid piece snapshot");
        auto const& blocks = static_cast<piece_data*>(p)->partial;
        if (capacity < static_cast<int>(blocks.size()) || (!buffer && !blocks.empty())) throw std::runtime_error("Block buffer is too small");
        if (!blocks.empty()) std::memcpy(buffer, blocks.data(), blocks.size() * sizeof(qs_partial_block));
        return static_cast<int>(blocks.size());
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Block copy error"; return -1; }
}
QS_API void qs_piece_close(void* p) noexcept { delete static_cast<piece_data*>(p); }
QS_API int qs_add_prepared(void* p, char const* file, char const* path,
    int const* priorities, int count, int start, int sequential, int download_bytes, int upload_bytes,
    char const* const* paths, char const* const* trackers, int tracker_count) noexcept {
    try {
        if (!file || !path || !priorities || count < 1 || tracker_count < 0 ||
            (tracker_count && !trackers)) throw std::runtime_error("Invalid prepared request ABI");
        auto& e = get(p);
        lt::error_code ec; lt::add_torrent_params a;
        a.ti = std::make_shared<lt::torrent_info>(std::string(file), ec);
        if (ec) throw std::runtime_error(ec.message());
        if (count != a.ti->num_files()) throw std::runtime_error("File count changed");
        for (int i = 0; i < count; ++i) {
            if (priorities[i] < 0 || priorities[i] > 7) throw std::runtime_error("Invalid priority enum");
            a.file_priorities.push_back(lt::download_priority_t(static_cast<std::uint8_t>(priorities[i])));
            if (paths) {
                if (!paths[i]) throw std::runtime_error("Null renamed path");
                a.renamed_files[lt::file_index_t(i)] = paths[i];
            }
        }
        for (int i = 0; i < tracker_count; ++i) {
            if (!trackers[i]) throw std::runtime_error("Null tracker URL");
            a.trackers.emplace_back(trackers[i]);
        }
        a.flags |= lt::torrent_flags::override_trackers | lt::torrent_flags::duplicate_is_error;
        a.flags &= ~lt::torrent_flags::auto_managed;
        if (start) a.flags &= ~lt::torrent_flags::paused; else a.flags |= lt::torrent_flags::paused;
        if (sequential) a.flags |= lt::torrent_flags::sequential_download;
        a.save_path = path; a.download_limit = download_bytes; a.upload_limit = upload_bytes;
        auto h = e.session.add_torrent(a, ec);
        if (ec) throw std::runtime_error(ec.message());
        int id = e.next_id++; e.torrents.emplace(id, h); return id;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Prepared add error"; return -1; }
}

QS_API void* qs_meta_open(char const* file) noexcept {
    try {
        if (!file) throw std::runtime_error("Missing torrent file");
        lt::error_code ec;
        auto t = std::unique_ptr<lt::torrent_info>(new lt::torrent_info(std::string(file), ec));
        if (ec) throw std::runtime_error(ec.message());
        return t.release();
    } catch (std::exception const& e) { last_error = e.what(); return nullptr; }
      catch (...) { last_error = "Metadata error"; return nullptr; }
}
QS_API void qs_meta_close(void* p) noexcept { delete static_cast<lt::torrent_info*>(p); }
QS_API int qs_meta_info(void* p, metadata_info* out) noexcept {
    try {
        if (!p || !out) throw std::runtime_error("Invalid metadata buffer");
        auto& t = *static_cast<lt::torrent_info*>(p);
        *out = {};
        out->total = t.total_size(); out->files = t.num_files();
        out->trackers = static_cast<int>(t.trackers().size());
        copy(out->name, sizeof(out->name), t.name());
        copy(out->comment, sizeof(out->comment), t.comment());
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Metadata error"; return -1; }
}
QS_API int qs_meta_file(void* p, int index, metadata_file* out) noexcept {
    try {
        if (!p || !out) throw std::runtime_error("Invalid metadata buffer");
        auto& t = *static_cast<lt::torrent_info*>(p);
        if (index < 0 || index >= t.num_files()) throw std::runtime_error("Invalid file index");
        *out = {};
        auto i = lt::file_index_t(index);
        out->size = t.files().file_size(i);
        copy(out->path, sizeof(out->path), t.files().file_path(i));
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Metadata error"; return -1; }
}
QS_API int qs_meta_tracker(void* p, int index, char* buffer, int capacity) noexcept {
    try {
        if (!p || !buffer || capacity < 1) throw std::runtime_error("Invalid tracker buffer");
        auto& t = *static_cast<lt::torrent_info*>(p);
        if (index < 0 || index >= static_cast<int>(t.trackers().size())) throw std::runtime_error("Invalid tracker index");
        copy(buffer, static_cast<size_t>(capacity), t.trackers()[index].url);
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Metadata error"; return -1; }
}
QS_API int qs_add_selected(void* p, char const* file, char const* path,
    int const* priorities, int count, int start) noexcept {
    try {
        auto& e = get(p);
        if (!file || !path || !*path || !priorities) throw std::runtime_error("Missing add options");
        lt::error_code ec;
        lt::add_torrent_params a;
        a.ti = std::make_shared<lt::torrent_info>(std::string(file), ec);
        if (ec) throw std::runtime_error(ec.message());
        if (count != a.ti->num_files()) throw std::runtime_error("File count changed; reopen the dialog");
        for (int i = 0; i < count; ++i) {
            if (priorities[i] < 0 || priorities[i] > 7) throw std::runtime_error("Invalid file priority enum");
            a.file_priorities.push_back(lt::download_priority_t(static_cast<std::uint8_t>(priorities[i])));
        }
        a.save_path = path;
        a.flags &= ~lt::torrent_flags::auto_managed;
        if (start) a.flags &= ~lt::torrent_flags::paused;
        else a.flags |= lt::torrent_flags::paused;
        a.flags |= lt::torrent_flags::duplicate_is_error;
        auto h = e.session.add_torrent(a, ec);
        if (ec) throw std::runtime_error(ec.message());
        int id = e.next_id++;
        e.torrents.emplace(id, h);
        return id;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Add options error"; return -1; }
}
QS_API int qs_configure(void* p, int port, int download_bytes, int upload_bytes, int connections) noexcept {
    try {
        auto& e = get(p);
        lt::settings_pack settings;
        std::string interfaces = "0.0.0.0:" + std::to_string(port) + ",[::]:" + std::to_string(port);
        if (e.session.get_settings().get_str(lt::settings_pack::listen_interfaces) != interfaces)
            settings.set_str(lt::settings_pack::listen_interfaces, interfaces);
        settings.set_int(lt::settings_pack::download_rate_limit, download_bytes);
        settings.set_int(lt::settings_pack::upload_rate_limit, upload_bytes);
        settings.set_int(lt::settings_pack::connections_limit, connections);
        e.session.apply_settings(settings);
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Configuration error"; return -1; }
}
