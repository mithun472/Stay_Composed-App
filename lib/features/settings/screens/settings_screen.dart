import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// Lets you paste the current ngrok URL for the Python backend
/// (e.g. https://abcd-1234.ngrok-free.app) and saves it locally.
/// Every service call reads this instead of a hardcoded URL, so a fresh
/// ngrok tunnel just means updating it here — no rebuild.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  String? _statusMessage;
  bool _isTesting = false;
  bool _lastTestFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await BackendConfig.getBaseUrl();
    if (saved != null && mounted) _urlController.text = saved;
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      setState(() {
        _statusMessage = 'Enter a full URL, starting with http:// or https://';
        _lastTestFailed = true;
      });
      return;
    }
    await ref.read(backendUrlProvider.notifier).update(url);
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Saved.';
      _lastTestFailed = false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final url = _urlController.text.trim();
    HttpClient? client;
    try {
      final uri = Uri.parse(url);
      client = HttpClient();
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      // ngrok's free-tier browser-warning interstitial only kicks in for
      // requests that look like they came from a browser, but this header
      // is harmless to send always and avoids that page intercepting the
      // real response if ngrok ever changes that behavior.
      request.headers.set('ngrok-skip-browser-warning', 'true');
      final response = await request.close().timeout(const Duration(seconds: 8));
      // Drain the body so the connection is released cleanly even though
      // we don't need the content.
      await response.drain<void>();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _statusMessage = 'Reachable (status ${response.statusCode}).';
          _lastTestFailed = false;
        });
      } else if (response.statusCode == 404 ||
          response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 522 ||
          response.statusCode == 523) {
        // The ngrok *edge* answered — the tunnel itself is up — but these
        // codes are what ngrok returns when nothing is listening on the
        // other end (backend process stopped/crashed) or the tunnel has
        // expired. That's not the same as the backend actually working,
        // so don't call it "Reachable".
        setState(() {
          _statusMessage =
              "Tunnel is up, but the backend isn't responding (status ${response.statusCode}). "
              'Check that the Python server is still running.';
          _lastTestFailed = true;
        });
      } else {
        setState(() {
          _statusMessage = 'Backend responded with an error (status ${response.statusCode}).';
          _lastTestFailed = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Couldn't reach that URL: $e";
        _lastTestFailed = true;
      });
    } finally {
      client?.close();
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Backend URL', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Paste your current ngrok URL for the Python backend. '
            'Update this whenever the tunnel restarts and gets a new address.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'ngrok URL',
              hintText: 'https://abcd-1234.ngrok-free.app',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isTesting ? null : _testConnection,
                  child: _isTesting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: PrimaryButton(label: 'Save', onPressed: _save)),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _statusMessage!,
              style: AppTextStyles.bodyMuted.copyWith(
                color: _lastTestFailed ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}