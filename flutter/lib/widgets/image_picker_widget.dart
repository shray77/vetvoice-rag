import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImagePickerWidget extends StatelessWidget {
  final File? image;
  final Function(File) onImageSelected;
  final VoidCallback onImageRemoved;

  const ImagePickerWidget({
    super.key,
    this.image,
    required this.onImageSelected,
    required this.onImageRemoved,
  });

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      onImageSelected(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              image!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              onPressed: onImageRemoved,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(backgroundColor: Colors.white70),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Add a photo of the skin condition',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
