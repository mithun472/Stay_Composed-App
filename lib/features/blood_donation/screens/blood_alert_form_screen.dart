import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/blood_alert_model.dart';
import '../../../services/blood_alert_service.dart';
import '../../authentication/providers/auth_provider.dart';

/// Form: Name, Blood Group, Phone Number -> "Send Blood Alert"
/// -> POST /blood-alert. Backend mails every department; app never mails
/// directly and no department field is collected here.
class BloodAlertFormScreen extends ConsumerStatefulWidget {
  const BloodAlertFormScreen({super.key});

  @override
  ConsumerState<BloodAlertFormScreen> createState() => _BloodAlertFormScreenState();
}

class _BloodAlertFormScreenState extends ConsumerState<BloodAlertFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _bloodGroup;
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a blood group.')),
      );
      return;
    }

    final email = ref.read(authControllerProvider).user?.collegeEmail;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with your college email first.')),
      );
      return;
    }

    setState(() => _isSending = true);

    final alert = BloodAlert(
      studentName: _nameController.text.trim(),
      bloodType: _bloodGroup!,
      phoneNumber: _phoneController.text.trim(),
      senderEmail: email,
    );

    final result = await ref.read(bloodAlertServiceProvider).sendAlert(alert);

    if (!mounted) return;
    setState(() => _isSending = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blood alert sent to the college.')),
        );
        Navigator.of(context).pop();
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Blood Alert')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _bloodGroup,
              decoration: const InputDecoration(labelText: 'Choose Blood Group'),
              items: AppConstants.bloodGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodGroup = v),
              validator: (v) => v == null ? 'Choose a blood group' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your phone number' : null,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Send Blood Alert',
              icon: Icons.favorite_rounded,
              backgroundColor: AppColors.blood,
              isLoading: _isSending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}