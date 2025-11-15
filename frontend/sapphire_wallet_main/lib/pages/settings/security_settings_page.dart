// lib/pages/settings/security_settings_page.dart
import 'package:flutter/material.dart';
import '../../services/security/secure_storage_service.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _storage = SecureStorageService();
  bool _isChanging = false;

  Future<void> _changePin() async {
    if (_currentPinController.text.length != 6 ||
        _newPinController.text.length != 6 ||
        _confirmPinController.text.length != 6) {
      _showError('All PINs must be 6 digits');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      _showError('New PINs do not match');
      return;
    }

    setState(() {
      _isChanging = true;
    });

    final isValid = await _storage.verifyPin(_currentPinController.text);
    if (!isValid) {
      _showError('Current PIN is incorrect');
      setState(() {
        _isChanging = false;
      });
      return;
    }

    await _storage.setPin(_newPinController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN changed successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your current PIN and choose a new one',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _currentPinController,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPinController,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChanging ? null : _changePin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isChanging
                    ? const CircularProgressIndicator()
                    : const Text('Change PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}