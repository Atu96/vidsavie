import os
from urllib.parse import urlparse

from yt_dlp.extractor.bilibili import BiliBiliBangumiIE, BiliBiliIE, BilibiliCheeseIE


def _candidate_urls(media):
    values = [media.get('baseUrl'), media.get('base_url'), media.get('url')]
    for key in ('backupUrl', 'backup_url'):
        backup = media.get(key) or []
        values.extend(backup if isinstance(backup, list) else [backup])
    candidates = []
    for value in values:
        if not isinstance(value, str) or not value.startswith(('https://', 'http://')):
            continue
        if value not in candidates:
            candidates.append(value)
    return candidates


def _rotate_media_urls(value, index, hosts):
    if isinstance(value, dict):
        candidates = _candidate_urls(value)
        if candidates:
            if index == 0 or len(candidates) == 1:
                selected = candidates[0]
            else:
                # Once throttling triggers, stay on an API-provided backup
                # instead of cycling back to the known-slow primary mirror.
                backups = candidates[1:]
                selected = backups[(index - 1) % len(backups)]
            value['baseUrl'] = selected
            host = urlparse(selected).hostname
            if host:
                hosts.add(host)
        for child in value.values():
            _rotate_media_urls(child, index, hosts)
    elif isinstance(value, list):
        for child in value:
            _rotate_media_urls(child, index, hosts)


def _rotated_play_info(extractor, play_info):
    try:
        index = max(0, int(os.environ.get('VBD_BILIBILI_CDN_INDEX', '0')))
    except ValueError:
        index = 0
    hosts = set()
    _rotate_media_urls(play_info, index, hosts)
    if hosts:
        extractor.to_screen(f'Video Batch CDN {index}: {", ".join(sorted(hosts))}')
    return play_info


class _VideoBatchBiliBiliIE(BiliBiliIE, plugin_name='video_batch_cdn'):
    def extract_formats(self, play_info):
        return super().extract_formats(_rotated_play_info(self, play_info))


class _VideoBatchBiliBiliBangumiIE(BiliBiliBangumiIE, plugin_name='video_batch_cdn'):
    def extract_formats(self, play_info):
        return super().extract_formats(_rotated_play_info(self, play_info))


class _VideoBatchBilibiliCheeseIE(BilibiliCheeseIE, plugin_name='video_batch_cdn'):
    def extract_formats(self, play_info):
        return super().extract_formats(_rotated_play_info(self, play_info))
