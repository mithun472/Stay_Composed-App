import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/campus_locations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/item_model.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/true_owner_service.dart';
import '../providers/true_owner_providers.dart';

/// One question+answer pair for a found-item challenge. Kept as a small
/// paired unit (rather than two parallel lists) so a half-filled row is
/// easy to spot and can't silently desync `challengeQuestions` from
/// `secretAnswers` — the backend rejects the two arrays if they're not
/// the same length.
class _QAPair {
  final TextEditingController question = TextEditingController();
  final TextEditingController answer = TextEditingController();

  void dispose() {
    question.dispose();
    answer.dispose();
  }

  bool get isEmpty => question.text.trim().isEmpty && answer.text.trim().isEmpty;
  bool get isComplete => question.text.trim().isNotEmpty && answer.text.trim().isNotEmpty;
}

/// `POST /items` for both directions of the flow — `type` decides the
/// copy and which private fields are collected. One screen rather than
/// two near-identical ones, since the payload is the same shape.
///
/// Requires `image_picker` in pubspec.yaml.
class ReportItemScreen extends ConsumerStatefulWidget {
  final String type; // 'lost' | 'found'
  const ReportItemScreen({super.key, required this.type});

  @override
  ConsumerState<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends ConsumerState<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _locationDetail = TextEditingController();
  final _description = TextEditingController();

  final List<TextEditingController> _secrets = [TextEditingController()];
  final List<_QAPair> _qaPairs = [_QAPair()];

  String? _category;
  String? _location;
  DateTime _date = DateTime.now();
  File? _pickedImage;
  bool _isSubmitting = false;

  bool get _isLost => widget.type == 'lost';
  bool get _isOthersLocation => _location == CampusLocations.others;

  @override
  void dispose() {
    _title.dispose();
    _locationDetail.dispose();
    _description.dispose();
    for (final c in _secrets) {
      c.dispose();
    }
    for (final p in _qaPairs) {
      p.dispose();
    }
    super.dispose();
  }

  List<String> _values(List<TextEditingController> controllers) => controllers
      .map((c) => c.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera ? 'Could not open the camera: $e' : 'Could not open the gallery: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Server-enforced rules the form can catch before spending a round trip:
    //   - found: image is compulsory
    //   - found: "Others" location needs a detail
    //   - found: every filled question needs its paired answer
    //   - found: at least one complete question+answer pair
    //   - lost: at least one secret detail
    if (!_isLost) {
      if (_pickedImage == null) {
        _snack('A photo is required for found items.');
        return;
      }
      if (_isOthersLocation && _locationDetail.text.trim().isEmpty) {
        _snack('Describe the location since you picked "Others".');
        return;
      }
      final incomplete = _qaPairs.any((p) => !p.isEmpty && !p.isComplete);
      if (incomplete) {
        _snack('Every challenge question needs an answer (or clear the empty one).');
        return;
      }
      final complete = _qaPairs.where((p) => p.isComplete).toList();
      if (complete.isEmpty) {
        _snack('Add at least one challenge question with its answer.');
        return;
      }
    } else {
      final secrets = _values(_secrets);
      if (secrets.isEmpty) {
        _snack('Add at least one secret detail so we can verify you later.');
        return;
      }
    }

    final email = ref.read(currentEmailProvider);
    if (email == null) {
      _snack('Sign in with your college email first.');
      return;
    }

    setState(() => _isSubmitting = true);

    String? imageUrl;
    if (_pickedImage != null) {
      final upload = await ref.read(imageUploadServiceProvider).uploadImage(_pickedImage!.path);
      final failed = upload.when(success: (url) {
        imageUrl = url;
        return false;
      }, failure: (message) {
        _snack('Image upload failed: $message');
        return true;
      });
      if (failed) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
    }

    final completePairs = _qaPairs.where((p) => p.isComplete).toList();

    final item = Item(
      id: '',
      type: widget.type,
      title: _title.text.trim(),
      category: _category ?? AppConstants.lostFoundCategories.last,
      location: _location ?? '',
      locationDetail: _locationDetail.text.trim(),
      date: _date.toIso8601String().split('T').first,
      description: _description.text.trim(),
      imageUrl: imageUrl,
      secretFeatures: _isLost ? _values(_secrets) : const [],
      challengeQuestions: _isLost ? const [] : completePairs.map((p) => p.question.text.trim()).toList(),
      secretAnswers: _isLost ? const [] : completePairs.map((p) => p.answer.text.trim()).toList(),
    );

    final result = await ref.read(trueOwnerServiceProvider).createItem(
          item,
          reporterEmail: email,
          reporterName: ref.read(currentNameProvider),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        ref.refreshTrueOwner();
        _snack(_isLost ? 'Lost report submitted.' : 'Found report submitted.');
        Navigator.of(context).pop();
      },
      failure: _snack,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLost ? 'Report Lost Item' : 'Report Found Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ImagePickerTile(
              image: _pickedImage,
              required: !_isLost,
              onPick: _showImageSourceSheet,
              onClear: () => setState(() => _pickedImage = null),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'What is it?', hintText: 'e.g. Black wallet'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a short title' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: AppConstants.lostFoundCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
              validator: (v) => v == null ? 'Choose a category' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _location,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isLost ? 'Where did you lose it? (optional)' : 'Where did you find it?',
              ),
              items: CampusLocations.all
                  .map((loc) => DropdownMenuItem(value: loc, child: Text(loc, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _location = v),
              validator: (v) {
                if (_isLost) return null; // location is optional for lost reports
                return (v == null || v.isEmpty) ? 'Location is required for found items' : null;
              },
            ),
            if (_isOthersLocation) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationDetail,
                decoration: const InputDecoration(
                  labelText: 'Describe the location',
                  hintText: 'e.g. Near the north gate',
                ),
                validator: (v) => (!_isLost && (v == null || v.trim().isEmpty))
                    ? 'Required since you picked "Others"'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(labelText: _isLost ? 'Date lost' : 'Date found'),
                child: Row(
                  children: [
                    Expanded(child: Text(_date.toIso8601String().split('T').first, style: AppTextStyles.body)),
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: _isLost
                    ? 'Colour, brand, anything visible from the outside.'
                    : 'Keep this general \u2014 everyone matched to it can read it.',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short description' : null,
            ),
            const SizedBox(height: 28),
            if (_isLost)
              _SecretFeaturesSection(
                controllers: _secrets,
                onAdd: () => setState(() => _secrets.add(TextEditingController())),
                onRemove: (i) => setState(() => _secrets.removeAt(i).dispose()),
              )
            else
              _ChallengeSection(
                pairs: _qaPairs,
                onAdd: () => setState(() => _qaPairs.add(_QAPair())),
                onRemove: (i) => setState(() => _qaPairs.removeAt(i).dispose()),
              ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: _isLost ? 'Submit lost report' : 'Submit found report',
              icon: Icons.send_rounded,
              backgroundColor: AppColors.trueOwner,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final File? image;
  final bool required;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ImagePickerTile({
    required this.image,
    required this.required,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(image!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              radius: 16,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: onClear,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: required ? AppColors.blood.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(required ? 'Add a photo (required)' : 'Add a photo (optional)', style: AppTextStyles.bodyMuted),
            Text(
              required ? 'Found items must include a photo' : 'Improves AI matching a lot',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lost-only: secret details only the true owner would know.
class _SecretFeaturesSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _SecretFeaturesSection({required this.controllers, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.trueOwnerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.trueOwner),
              const SizedBox(width: 8),
              Text('Secret details', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Only you know these. They\u2019re hashed on the server and never shown to anyone \u2014 '
            'they\u2019re what proves the item is yours.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controllers[i],
                      decoration: InputDecoration(
                        labelText: 'Detail ${i + 1}',
                        hintText: 'e.g. Student ID inside',
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ),
                  if (controllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                      onPressed: () => onRemove(i),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add another'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Found-only: paired question + hidden answer. The backend stores
/// `challengeQuestions` (shown to claimants) and `secretAnswers` (hashed,
/// never shown) as two index-aligned arrays, so each row here has to stay
/// a matched pair — never split into two independent lists.
class _ChallengeSection extends StatelessWidget {
  final List<_QAPair> pairs;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _ChallengeSection({required this.pairs, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.trueOwnerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.trueOwner),
              const SizedBox(width: 8),
              Text('Challenge questions', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The question is shown to a claimant; the answer is hashed and never shown. '
            'Pick things only the real owner would know \u2014 not visible from a photo.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < pairs.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Question ${i + 1}', style: AppTextStyles.caption),
                      ),
                      if (pairs.length > 1)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 18,
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                          onPressed: () => onRemove(i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: pairs[i].question,
                    decoration: const InputDecoration(hintText: 'e.g. What is inside the wallet?'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pairs[i].answer,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Hidden answer',
                      hintText: 'Only you and the real owner would know this',
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add another question'),
            ),
          ),
        ],
      ),
    );
  }
}