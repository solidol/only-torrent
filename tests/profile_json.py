"""Read the public JSON storage format for integration assertions."""
import json
from pathlib import Path

def tasks(profile):
    result = []
    for path in (Path(profile) / 'Tasks').glob('*.json'):
        if Path(str(path) + '.deleted').exists():
            continue
        result.append(json.loads(path.read_text(encoding='utf-8-sig')))
    return sorted(result, key=lambda t: (t['position'], t['id']))

def rows(profile, *columns):
    aliases = {'info_hash':'infoHash', 'torrent_file':'torrentFile', 'save_path':'savePath', 'updated_utc':'updatedUTC'}
    result = []
    for task in tasks(profile):
        row = []
        for column in columns:
            if column == 'details':
                value = json.dumps(task['details'])
            elif column in ('resume', 'length(resume)'):
                name = task['resumeFile']
                value = (Path(profile) / 'Resume' / name).read_bytes() if name else None
                if column == 'length(resume)': value = len(value or b'')
            else:
                value = task[aliases.get(column, column)]
            row.append(value)
        result.append(tuple(row))
    return result
