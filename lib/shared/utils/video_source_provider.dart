abstract class VideoSourceProvider {
  bool canHandle(String url);
  String getPlayableUrl(String url);
  String get providerName;
}

class GoogleDriveVideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'Google Drive';

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('drive.google.com') || lower.contains('docs.google.com/file');
  }

  @override
  String getPlayableUrl(String url) {
    // Extract file ID from file/d/[ID] format or id=[ID] query parameter
    final fileIdRegExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
    final fileIdMatch = fileIdRegExp.firstMatch(url);
    if (fileIdMatch != null) {
      final fileId = fileIdMatch.group(1);
      return 'https://docs.google.com/uc?export=download&confirm=no_antivirus&id=$fileId';
    }

    final queryIdRegExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
    final queryIdMatch = queryIdRegExp.firstMatch(url);
    if (queryIdMatch != null) {
      final fileId = queryIdMatch.group(1);
      return 'https://docs.google.com/uc?export=download&confirm=no_antivirus&id=$fileId';
    }

    return url;
  }
}

class DropboxVideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'Dropbox';

  @override
  bool canHandle(String url) {
    return url.toLowerCase().contains('dropbox.com');
  }

  @override
  String getPlayableUrl(String url) {
    // For Dropbox, change dl=0 to raw=1 to get the direct video stream
    if (url.contains('dl=0')) {
      return url.replaceAll('dl=0', 'raw=1');
    } else if (!url.contains('raw=1') && !url.contains('dl=1')) {
      return '$url${url.contains('?') ? '&' : '?'}raw=1';
    }
    return url;
  }
}

class OneDriveVideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'OneDrive';

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('onedrive.live.com') || lower.contains('1drv.ms') || lower.contains('sharepoint.com');
  }

  @override
  String getPlayableUrl(String url) {
    // Basic sharepoint/onedrive share url cleanup can be added here if known,
    // otherwise pass through.
    return url;
  }
}

class CloudflareR2VideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'Cloudflare R2';

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    // Typical R2 domains or standard R2 bucket paths
    return lower.contains('r2.cloudflarestorage.com') || lower.contains('.r2.dev');
  }

  @override
  String getPlayableUrl(String url) => url;
}

class BunnyStorageVideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'Bunny Storage';

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('bunnycdn.com') || lower.contains('b-cdn.net');
  }

  @override
  String getPlayableUrl(String url) => url;
}

class DirectMp4VideoProvider implements VideoSourceProvider {
  @override
  String get providerName => 'Direct Video URL';

  @override
  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.contains('/mp4/') ||
        lower.contains('.mp4?');
  }

  @override
  String getPlayableUrl(String url) => url;
}

class VideoSourceManager {
  static final List<VideoSourceProvider> _providers = [
    GoogleDriveVideoProvider(),
    DropboxVideoProvider(),
    OneDriveVideoProvider(),
    CloudflareR2VideoProvider(),
    BunnyStorageVideoProvider(),
    DirectMp4VideoProvider(),
  ];

  static String getPlayableUrl(String url) {
    final trimmed = url.trim();
    for (final provider in _providers) {
      if (provider.canHandle(trimmed)) {
        return provider.getPlayableUrl(trimmed);
      }
    }
    return trimmed; // fallback to raw input
  }

  static String getProviderName(String url) {
    final trimmed = url.trim();
    for (final provider in _providers) {
      if (provider.canHandle(trimmed)) {
        return provider.providerName;
      }
    }
    return 'External Source';
  }
}
