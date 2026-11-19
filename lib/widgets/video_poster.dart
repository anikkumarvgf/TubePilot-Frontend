/// Poster picture (first second) of an uploaded video, built from its Cloudinary URL.
/// Used when the video has no thumbnail of its own, so lists never show an empty movie icon.
/// Returns null when the video is not stored on Cloudinary.
String? videoPosterUrl(dynamic video) {
  if (video is! Map) return null;
  final raw = (video['posterUrl'] ?? video['storageUrl'] ?? video['videoUrl'] ?? '').toString();
  if (!raw.contains('/video/upload/')) return null;
  return raw
      .replaceFirst('/video/upload/', '/video/upload/so_1,w_360,c_limit,f_jpg/')
      .replaceFirst(RegExp(r'\.[A-Za-z0-9]+(\?.*)?$'), '.jpg');
}
