import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // IMAGE PROCESSING

  /// Compress and resize image
  Future<MediaResult> processImage({
    required File imageFile,
    int maxWidth = 1080,
    int maxHeight = 1080,
    int quality = 85,
    bool generateThumbnail = true,
  }) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return MediaResult.error('Invalid image file');
      }

      // Resize image if needed
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? maxWidth : null,
          height: image.height > image.width ? maxHeight : null,
        );
      }

      // Compress image
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      // Save compressed image
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      // Generate thumbnail if requested
      File? thumbnailFile;
      if (generateThumbnail) {
        thumbnailFile = await _generateThumbnail(resizedImage);
      }

      return MediaResult.success(
        processedFile: compressedFile,
        thumbnailFile: thumbnailFile,
        originalSize: bytes.length,
        compressedSize: compressedBytes.length,
        compressionRatio: (1 - (compressedBytes.length / bytes.length)) * 100,
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
      return MediaResult.error('Failed to process image');
    }
  }

  /// Generate thumbnail from image
  Future<File?> _generateThumbnail(img.Image image) async {
    try {
      // Create 300x300 thumbnail
      final thumbnail = img.copyResize(
        image,
        width: 300,
        height: 300,
      );

      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 75);
      
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = File('${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await thumbnailFile.writeAsBytes(thumbnailBytes);
      
      return thumbnailFile;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Validate image file
  MediaValidationResult validateImageFile(File imageFile) {
    // Check file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    final fileName = imageFile.path.toLowerCase();
    final hasValidExtension = validExtensions.any((ext) => fileName.endsWith(ext));
    
    if (!hasValidExtension) {
      return MediaValidationResult.error('Invalid file format. Use JPG, PNG, or WebP');
    }

    // Check file size (5MB limit)
    final fileSizeBytes = imageFile.lengthSync();
    if (fileSizeBytes > 5 * 1024 * 1024) {
      return MediaValidationResult.error('File too large. Maximum size is 5MB');
    }

    if (fileSizeBytes < 1024) {
      return MediaValidationResult.error('File too small. Minimum size is 1KB');
    }

    return MediaValidationResult.success(
      fileSize: fileSizeBytes,
      isValid: true,
    );
  }

  // FIREBASE STORAGE UPLOAD

  /// Upload image to Firebase Storage
  Future<UploadResult> uploadImage({
    required File imageFile,
    required String userId,
    required String folder, // 'profile', 'messages', etc.
    String? fileName,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate file first
      final validation = validateImageFile(imageFile);
      if (!validation.isValid) {
        return UploadResult.error(validation.error!);
      }

      // Process image
      final processResult = await processImage(imageFile: imageFile);
      if (!processResult.success) {
        return UploadResult.error(processResult.error!);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = '.jpg'; // Always JPG after processing
      final uploadFileName = fileName ?? 'image_$timestamp$fileExtension';
      
      // Upload main image
      final mainImageRef = _storage.ref().child('$folder/$userId/$uploadFileName');
      final uploadTask = mainImageRef.putFile(processResult.processedFile!);
      
      // Listen to progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Upload thumbnail if available
      String? thumbnailUrl;
      if (processResult.thumbnailFile != null) {
        final thumbnailRef = _storage.ref().child('$folder/$userId/thumb_$uploadFileName');
        final thumbUploadTask = thumbnailRef.putFile(processResult.thumbnailFile!);
        final thumbSnapshot = await thumbUploadTask;
        thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
      }

      // Clean up temporary files
      await _cleanupTempFile(processResult.processedFile!);
      if (processResult.thumbnailFile != null) {
        await _cleanupTempFile(processResult.thumbnailFile!);
      }

      return UploadResult.success(
        downloadUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
        fileName: uploadFileName,
        fileSize: processResult.compressedSize!,
        compressionRatio: processResult.compressionRatio!,
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return UploadResult.error('Failed to upload image');
    }
  }

  /// Delete image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  // VIDEO PROCESSING (Basic)

  /// Validate video file
  MediaValidationResult validateVideoFile(File videoFile) {
    // Check file extension
    final validExtensions = ['.mp4', '.mov', '.avi'];
    final fileName = videoFile.path.toLowerCase();
    final hasValidExtension = validExtensions.any((ext) => fileName.endsWith(ext));
    
    if (!hasValidExtension) {
      return MediaValidationResult.error('Invalid video format. Use MP4, MOV, or AVI');
    }

    // Check file size (50MB limit for videos)
    final fileSizeBytes = videoFile.lengthSync();
    if (fileSizeBytes > 50 * 1024 * 1024) {
      return MediaValidationResult.error('Video too large. Maximum size is 50MB');
    }

    return MediaValidationResult.success(
      fileSize: fileSizeBytes,
      isValid: true,
    );
  }

  /// Upload video to Firebase Storage
  Future<UploadResult> uploadVideo({
    required File videoFile,
    required String userId,
    required String folder,
    String? fileName,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate file
      final validation = validateVideoFile(videoFile);
      if (!validation.isValid) {
        return UploadResult.error(validation.error!);
      }

      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = videoFile.path.substring(videoFile.path.lastIndexOf('.'));
      final uploadFileName = fileName ?? 'video_$timestamp$fileExtension';
      
      // Upload video
      final videoRef = _storage.ref().child('$folder/$userId/$uploadFileName');
      final uploadTask = videoRef.putFile(videoFile);
      
      // Listen to progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return UploadResult.success(
        downloadUrl: downloadUrl,
        fileName: uploadFileName,
        fileSize: videoFile.lengthSync(),
      );
    } catch (e) {
      debugPrint('Error uploading video: $e');
      return UploadResult.error('Failed to upload video');
    }
  }

  // UTILITY METHODS

  /// Get image dimensions
  Future<ImageDimensions?> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      return ImageDimensions(
        width: image.width,
        height: image.height,
      );
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Convert bytes to human readable size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Clean up temporary file
  Future<void> _cleanupTempFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error cleaning up temp file: $e');
    }
  }

  /// Get file MIME type
  String getMimeType(String filePath) {
    final extension = filePath.toLowerCase().substring(filePath.lastIndexOf('.'));
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  /// Create image from bytes (for testing)
  Future<File?> createImageFromBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('Error creating image from bytes: $e');
      return null;
    }
  }

  /// Clear all temporary files
  Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      for (final file in files) {
        if (file is File && 
            (file.path.contains('compressed_') || 
             file.path.contains('thumb_') ||
             file.path.contains('temp_'))) {
          await file.delete();
        }
      }
      
      debugPrint('Temp files cleared');
    } catch (e) {
      debugPrint('Error clearing temp files: $e');
    }
  }

  /// Get media cache info
  Future<MediaCacheInfo> getMediaCacheInfo() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      
      int totalFiles = 0;
      int totalSize = 0;
      int imageFiles = 0;
      int videoFiles = 0;
      
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.toLowerCase();
          if (fileName.contains('compressed_') || 
              fileName.contains('thumb_') ||
              fileName.contains('temp_')) {
            totalFiles++;
            totalSize += file.lengthSync();
            
            if (fileName.contains('.jpg') || fileName.contains('.png')) {
              imageFiles++;
            } else if (fileName.contains('.mp4') || fileName.contains('.mov')) {
              videoFiles++;
            }
          }
        }
      }
      
      return MediaCacheInfo(
        totalFiles: totalFiles,
        totalSize: totalSize,
        imageFiles: imageFiles,
        videoFiles: videoFiles,
        formattedSize: formatFileSize(totalSize),
      );
    } catch (e) {
      debugPrint('Error getting cache info: $e');
      return MediaCacheInfo.empty();
    }
  }
}

/// Media processing result
class MediaResult {
  final bool success;
  final File? processedFile;
  final File? thumbnailFile;
  final int? originalSize;
  final int? compressedSize;
  final double? compressionRatio;
  final String? error;

  const MediaResult._({
    required this.success,
    this.processedFile,
    this.thumbnailFile,
    this.originalSize,
    this.compressedSize,
    this.compressionRatio,
    this.error,
  });

  factory MediaResult.success({
    required File processedFile,
    File? thumbnailFile,
    required int originalSize,
    required int compressedSize,
    required double compressionRatio,
  }) {
    return MediaResult._(
      success: true,
      processedFile: processedFile,
      thumbnailFile: thumbnailFile,
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionRatio: compressionRatio,
    );
  }

  factory MediaResult.error(String error) {
    return MediaResult._(success: false, error: error);
  }
}

/// Media validation result
class MediaValidationResult {
  final bool isValid;
  final int? fileSize;
  final String? error;

  const MediaValidationResult._({
    required this.isValid,
    this.fileSize,
    this.error,
  });

  factory MediaValidationResult.success({
    required int fileSize,
    required bool isValid,
  }) {
    return MediaValidationResult._(
      isValid: true,
      fileSize: fileSize,
    );
  }

  factory MediaValidationResult.error(String error) {
    return MediaValidationResult._(isValid: false, error: error);
  }
}

/// Upload result
class UploadResult {
  final bool success;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final double? compressionRatio;
  final String? error;

  const UploadResult._({
    required this.success,
    this.downloadUrl,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.compressionRatio,
    this.error,
  });

  factory UploadResult.success({
    required String downloadUrl,
    String? thumbnailUrl,
    required String fileName,
    required int fileSize,
    double? compressionRatio,
  }) {
    return UploadResult._(
      success: true,
      downloadUrl: downloadUrl,
      thumbnailUrl: thumbnailUrl,
      fileName: fileName,
      fileSize: fileSize,
      compressionRatio: compressionRatio,
    );
  }

  factory UploadResult.error(String error) {
    return UploadResult._(success: false, error: error);
  }
}

/// Image dimensions
class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({
    required this.width,
    required this.height,
  });

  double get aspectRatio => width / height;
  
  @override
  String toString() => '${width}x$height';
}

/// Media cache information
class MediaCacheInfo {
  final int totalFiles;
  final int totalSize;
  final int imageFiles;
  final int videoFiles;
  final String formattedSize;

  MediaCacheInfo({
    required this.totalFiles,
    required this.totalSize,
    required this.imageFiles,
    required this.videoFiles,
    required this.formattedSize,
  });

  factory MediaCacheInfo.empty() {
    return MediaCacheInfo(
      totalFiles: 0,
      totalSize: 0,
      imageFiles: 0,
      videoFiles: 0,
      formattedSize: '0 B',
    );
  }
}