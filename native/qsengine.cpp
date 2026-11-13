#include <windows.h>
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/alert.hpp>
#include <libtorrent/file_storage.hpp>
#include <libtorrent/bdecode.hpp>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <algorithm>
#include <map>
#include <memory>
#include <cstring>
#include <cstdint>
#include <string>
#include <stdexcept>

namespace lt = libtorrent;
#define QS_API extern "C" __declspec(dllexport)
struct snapshot {
    int64_t total, done;
    int32_t download_rate, upload_rate, peers, seeds, state, progress;
    char name[512], error[512];
};
static_assert(sizeof(snapshot) == 1064, "Delphi ABI mismatch");
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
QS_API int qs_version() noexcept { return 1; }
QS_API char const* qs_error() noexcept { return last_error.c_str(); }
QS_API void* qs_create() noexcept {
    try {
        lt::settings_pack p;
        p.set_bool(lt::settings_pack::enable_dht, false);
        p.set_bool(lt::settings_pack::enable_lsd, false);
        p.set_bool(lt::settings_pack::enable_upnp, false);
        p.set_bool(lt::settings_pack::enable_natpmp, false);
        p.set_str(lt::settings_pack::listen_interfaces, "0.0.0.0:6881,[::]:6881");
        p.set_str(lt::settings_pack::user_agent, "qsTorrent/0.1");
        p.set_int(lt::settings_pack::stop_tracker_timeout, 2);
        return new engine(p);
    } catch (std::exception const& e) { last_error = e.what(); return nullptr; }
      catch (...) { last_error = "Unknown engine initialization error"; return nullptr; }
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
        out->state = static_cast<int>(s.state);
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

// Additive ABI v1 exports. Metadata inspection never creates a network session.
struct metadata_info {
    int64_t total;
    int32_t files, trackers;
    char name[512], comment[1024];
};
struct metadata_file { int64_t size; char path[4096]; };
static_assert(sizeof(metadata_info) == 1552, "metadata ABI mismatch");
static_assert(sizeof(metadata_file) == 4104, "file ABI mismatch");
struct metadata_extra {
    int64_t created;
    int32_t pieces, piece_length;
    char creator[512], publisher[512], publisher_url[2048], hash[64], web_seeds[4096];
};
static_assert(sizeof(metadata_extra) == 7248, "extra metadata ABI mismatch");

static std::wstring wide_path(char const* path) {
    int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, nullptr, 0);
    if (size == 0) throw std::runtime_error("Invalid UTF-8 path");
    std::wstring result(static_cast<size_t>(size), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, &result[0], size);
    result.resize(static_cast<size_t>(size - 1));
    return result;
}
QS_API int qs_meta_extra(void* p, char const* file, metadata_extra* out) noexcept {
    try {
        if (!p || !file || !out) throw std::runtime_error("Invalid metadata buffer");
        auto& t = *static_cast<lt::torrent_info*>(p);
        *out = {};
        out->created = static_cast<int64_t>(t.creation_date());
        out->pieces = t.num_pieces(); out->piece_length = t.piece_length();
        copy(out->creator, sizeof(out->creator), t.creator());
        auto hash = t.info_hash();
        char const* hex = "0123456789abcdef";
        for (int i = 0; i < 20; ++i) {
            auto value = static_cast<unsigned char>(hash.data()[i]);
            out->hash[i * 2] = hex[value >> 4]; out->hash[i * 2 + 1] = hex[value & 15];
        }
        std::string seeds;
        for (auto const& seed : t.web_seeds()) seeds += seed.url + "\r\n";
        copy(out->web_seeds, sizeof(out->web_seeds), seeds);
        auto filename = wide_path(file);
        std::ifstream stream(filename.c_str(), std::ios::binary | std::ios::ate);
        if (!stream) throw std::runtime_error("Cannot read torrent metadata");
        auto length = stream.tellg();
        if (length <= 0 || length > 64 * 1024 * 1024) throw std::runtime_error("Torrent metadata is too large");
        std::vector<char> bytes(static_cast<size_t>(length));
        stream.seekg(0); stream.read(bytes.data(), static_cast<std::streamsize>(bytes.size()));
        if (!stream) throw std::runtime_error("Cannot read torrent metadata");
        lt::error_code ec;
        auto root = lt::bdecode(lt::span<char const>(bytes.data(), bytes.size()), ec);
        if (ec) throw std::runtime_error(ec.message());
        copy(out->publisher, sizeof(out->publisher), root.dict_find_string_value("publisher").to_string());
        copy(out->publisher_url, sizeof(out->publisher_url), root.dict_find_string_value("publisher-url").to_string());
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Metadata error"; return -1; }
}

// Each column covers a contiguous range of real blocks. Three cumulative
// densities (0..255) distinguish verified, received and outstanding data.
// Memory is bounded by the viewport, never by the torrent's block count.
QS_API int qs_blocks(void* p, int id, int columns, unsigned char* verified,
    unsigned char* received, unsigned char* requested, int64_t* total, int* block_size) noexcept {
    try {
        if (!verified || !received || !requested || !total || !block_size || columns < 1 || columns > 4096)
            throw std::runtime_error("Invalid block viewport");
        auto h = get(p).torrents.at(id);
        auto info = h.torrent_file();
        if (!info) throw std::runtime_error("Torrent metadata is unavailable");
        auto status = h.status(lt::torrent_handle::query_pieces);
        int size = status.block_size > 0 ? status.block_size : (std::min)(16384, info->piece_length());
        int per_piece = (info->piece_length() + size - 1) / size;
        *total = info->num_pieces() == 0 ? 0 : int64_t(info->num_pieces() - 1) * per_piece +
            (info->piece_size(lt::piece_index_t(info->num_pieces() - 1)) + size - 1) / size;
        *block_size = size;
        int returned = static_cast<int>((std::min)(int64_t(columns), *total));
        if (status.is_seeding) {
            std::memset(verified, 255, static_cast<size_t>(returned));
            std::memset(received, 255, static_cast<size_t>(returned));
            std::memset(requested, 255, static_cast<size_t>(returned));
            return returned;
        }
        std::vector<lt::partial_piece_info> queue;
        h.get_download_queue(queue);
        std::unordered_map<int, lt::partial_piece_info const*> partial;
        for (auto const& entry : queue) partial.emplace(static_cast<int>(entry.piece_index), &entry);
        auto density = [](int64_t n, int64_t d) -> unsigned char {
            if (n == 0) return 0;
            if (n == d) return 255;
            return static_cast<unsigned char>((std::max)(int64_t(1), (std::min)(int64_t(254), n * 255 / d)));
        };
        for (int i = 0; i < returned; ++i) {
            int64_t first = int64_t(i) * *total / returned;
            int64_t end = int64_t(i + 1) * *total / returned;
            int64_t v = 0, r = 0, q = 0;
            for (int piece = static_cast<int>(first / per_piece); piece <= (end - 1) / per_piece; ++piece) {
                int begin_block = static_cast<int>((std::max)(int64_t(0), first - int64_t(piece) * per_piece));
                int end_block = static_cast<int>((std::min)(int64_t(per_piece), end - int64_t(piece) * per_piece));
                if (status.is_seeding || (piece < status.pieces.size() && status.pieces[lt::piece_index_t(piece)])) {
                    v += end_block - begin_block; r += end_block - begin_block; q += end_block - begin_block;
                } else {
                    auto found = partial.find(piece);
                    if (found == partial.end()) continue;
                    for (int block = begin_block; block < end_block && block < found->second->blocks_in_piece; ++block) {
                        auto const& b = found->second->blocks[block];
                        if (b.state == lt::block_info::finished || b.state == lt::block_info::writing) { ++r; ++q; }
                        else if (b.state == lt::block_info::requested) ++q;
                    }
                }
            }
            verified[i] = density(v, end - first);
            received[i] = density(r, end - first);
            requested[i] = density(q, end - first);
        }
        return returned;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Block viewport error"; return -1; }
}

QS_API int qs_add_options(void* p, char const* file, char const* path, char const* subfolder,
    int const* priorities, int count, int start, int sequential, int down_kib, int up_kib,
    char const* trackers) noexcept {
    try {
        auto& e = get(p);
        if (!file || !path || !*path || !subfolder || !priorities || !trackers)
            throw std::runtime_error("Missing add options");
        std::string folder(subfolder);
        if (folder.find_first_of("/\\:<>\"|?*") != std::string::npos || folder == "." || folder == "..")
            throw std::runtime_error("Subfolder must be a single directory name");
        if (down_kib < 0 || up_kib < 0 || down_kib > 1048576 || up_kib > 1048576)
            throw std::runtime_error("Invalid task rate limits");
        lt::error_code ec; lt::add_torrent_params a;
        a.ti = std::make_shared<lt::torrent_info>(std::string(file), ec);
        if (ec) throw std::runtime_error(ec.message());
        if (count != a.ti->num_files()) throw std::runtime_error("File count changed");
        bool any = false;
        for (int i = 0; i < count; ++i) {
            if (priorities[i] != 0 && priorities[i] != 4) throw std::runtime_error("Invalid file priority");
            a.file_priorities.push_back(lt::download_priority_t(static_cast<std::uint8_t>(priorities[i])));
            any |= priorities[i] != 0;
            auto original = a.ti->files().file_path(lt::file_index_t(i));
            auto separator = original.find_first_of("/\\");
            auto relative = separator == std::string::npos ? original : original.substr(separator + 1);
            a.renamed_files[lt::file_index_t(i)] = folder.empty() ? relative : folder + "/" + relative;
        }
        if (!any) throw std::runtime_error("Select at least one file");
        std::istringstream lines(trackers); std::string line;
        while (std::getline(lines, line)) {
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.empty()) continue;
            if (line.compare(0, 7, "http://") && line.compare(0, 8, "https://") && line.compare(0, 6, "udp://"))
                throw std::runtime_error("Tracker must use http, https or udp");
            a.trackers.push_back(line);
        }
        a.flags |= lt::torrent_flags::override_trackers | lt::torrent_flags::duplicate_is_error;
        a.flags &= ~lt::torrent_flags::auto_managed;
        if (start) a.flags &= ~lt::torrent_flags::paused; else a.flags |= lt::torrent_flags::paused;
        if (sequential) a.flags |= lt::torrent_flags::sequential_download;
        a.save_path = path; a.download_limit = down_kib * 1024; a.upload_limit = up_kib * 1024;
        auto h = e.session.add_torrent(a, ec);
        if (ec) throw std::runtime_error(ec.message());
        int id = e.next_id++; e.torrents.emplace(id, h); return id;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Add options error"; return -1; }
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
        bool any = false;
        for (int i = 0; i < count; ++i) {
            if (priorities[i] != 0 && priorities[i] != 4) throw std::runtime_error("Invalid file priority");
            a.file_priorities.push_back(lt::download_priority_t(static_cast<std::uint8_t>(priorities[i])));
            any |= priorities[i] != 0;
        }
        if (!any) throw std::runtime_error("Select at least one file");
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
QS_API int qs_configure(void* p, int port, int down_kib, int up_kib, int connections) noexcept {
    try {
        if (port < 1 || port > 65535 || down_kib < 0 || up_kib < 0 ||
            down_kib > 1048576 || up_kib > 1048576 || connections < 10 || connections > 10000)
            throw std::runtime_error("Invalid connection settings");
        auto& e = get(p);
        lt::settings_pack settings;
        std::string interfaces = "0.0.0.0:" + std::to_string(port) + ",[::]:" + std::to_string(port);
        if (e.session.get_settings().get_str(lt::settings_pack::listen_interfaces) != interfaces)
            settings.set_str(lt::settings_pack::listen_interfaces, interfaces);
        settings.set_int(lt::settings_pack::download_rate_limit, down_kib * 1024);
        settings.set_int(lt::settings_pack::upload_rate_limit, up_kib * 1024);
        settings.set_int(lt::settings_pack::connections_limit, connections);
        e.session.apply_settings(settings);
        return 0;
    } catch (std::exception const& e) { last_error = e.what(); return -1; }
      catch (...) { last_error = "Configuration error"; return -1; }
}
