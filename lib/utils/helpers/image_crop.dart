import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../config/app_colors.dart';
import 'image_prep.dart';

/// Lets the user frame a picked photo before upload, with the ratio locked to how it is shown.
/// Returns the cropped file path, the original path for [ImageShape.original], or null if cancelled.
class ImageCrop {
  ImageCrop._();

  static Future<String?> frame(String path, ImageShape shape, {bool circle = false}) async {
    if (shape == ImageShape.original) return path;
    final banner = shape == ImageShape.banner;
    final preset = banner ? const _Ratio16x9() : CropAspectRatioPreset.square;
    final title = circle ? 'Adjust photo' : (banner ? 'Adjust banner' : 'Adjust logo');
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: banner ? const CropAspectRatio(ratioX: 16, ratioY: 9) : const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppColors.darkBackground,
          statusBarLight: false,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.75),
          showCropGrid: !circle,
          cropFrameColor: circle ? Colors.transparent : Colors.white,
          cropStyle: circle ? CropStyle.circle : CropStyle.rectangle,
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: preset,
          aspectRatioPresets: [preset],
        ),
        IOSUiSettings(
          title: title,
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
          cropStyle: circle ? CropStyle.circle : CropStyle.rectangle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: [preset],
        ),
      ],
    );
    return cropped?.path;
  }
}

class _Ratio16x9 implements CropAspectRatioPresetData {
  const _Ratio16x9();
  @override
  (int, int)? get data => (16, 9);
  @override
  String get name => '16x9';
}
