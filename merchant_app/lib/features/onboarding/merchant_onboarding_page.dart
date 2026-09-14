import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'onboarding_api_service.dart';

class MerchantOnboardingPage extends StatefulWidget {
  const MerchantOnboardingPage({super.key});
  @override
  State<MerchantOnboardingPage> createState() => _MerchantOnboardingPageState();
}

class _MerchantOnboardingPageState extends State<MerchantOnboardingPage> {
  final _api = MerchantOnboardingApiService();
  final _legal = TextEditingController(),
      _store = TextEditingController(),
      _owner = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController(),
      _pan = TextEditingController(),
      _gstin = TextEditingController(),
      _fssai = TextEditingController(),
      _beneficiary = TextEditingController(),
      _account = TextEditingController(),
      _confirm = TextEditingController(),
      _ifsc = TextEditingController();
  String _businessType = 'PROPRIETORSHIP', _accountType = 'CURRENT';
  bool _loading = false;
  String? _error;
  final Map<String, PlatformFile> _documents = {};

  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result.isNotEmpty) {
      setState(() => _documents[type] = result.single);
    }
  }

  Widget _documentTile(String type, String label) => Card(
    child: ListTile(
      title: Text(label),
      subtitle: Text(_documents[type]?.name ?? 'Not selected'),
      trailing: const Icon(Icons.upload_file),
      onTap: () => _pickDocument(type),
    ),
  );

  @override
  void dispose() {
    for (final controller in [
      _legal,
      _store,
      _owner,
      _email,
      _phone,
      _address,
      _pan,
      _gstin,
      _fssai,
      _beneficiary,
      _account,
      _confirm,
      _ifsc,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final required = [
      _legal,
      _owner,
      _phone,
      _address,
      _pan,
      _fssai,
      _beneficiary,
      _account,
      _ifsc,
    ];
    if (required.any((field) => field.text.trim().isEmpty)) {
      return setState(() => _error = 'Please complete all required fields.');
    }
    if (_account.text.trim() != _confirm.text.trim()) {
      return setState(() => _error = 'Bank account numbers do not match.');
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.update({
        'legalBusinessName': _legal.text.trim(),
        'customerFacingBusinessName': _store.text.trim(),
        'ownerName': _owner.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'registeredAddress': _address.text.trim(),
        'businessType': _businessType,
        'panNumber': _pan.text.trim(),
        'gstin': _gstin.text.trim(),
        'fssaiNumber': _fssai.text.trim(),
        'bank': {
          'beneficiaryName': _beneficiary.text.trim(),
          'accountNumber': _account.text.trim(),
          'ifsc': _ifsc.text.trim(),
          'accountType': _accountType,
        },
      });
      for (final entry in _documents.entries) {
        await _api.uploadDocument(entry.key, entry.value);
      }
      await _api.submit();
      if (mounted) context.go('/approval-pending');
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to submit verification.';
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: optional ? '$label (optional)' : label,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restaurant Verification')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Business Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        _field('Legal business name', _legal),
        _field('Restaurant name', _store, optional: true),
        _field('Owner / authorised person', _owner),
        _field('Email', _email, optional: true),
        _field('Phone', _phone),
        _field('Registered address', _address),
        DropdownButtonFormField<String>(
          initialValue: _businessType,
          decoration: const InputDecoration(labelText: 'Business type'),
          items:
              const ['PROPRIETORSHIP', 'PARTNERSHIP', 'PRIVATE_LIMITED', 'LLP']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _businessType = value);
          },
        ),
        const SizedBox(height: 28),
        Text('Compliance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        _field('PAN', _pan),
        _field('GSTIN', _gstin, optional: true),
        _field('FSSAI number', _fssai),
        const SizedBox(height: 28),
        Text('Bank Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        _documentTile('PAN', 'PAN document'),
        _documentTile('FSSAI', 'FSSAI certificate'),
        _documentTile('BANK_PROOF', 'Cancelled cheque / bank proof'),
        if (_gstin.text.trim().isNotEmpty)
          _documentTile('GST', 'GST certificate'),
        _field('Account holder name', _beneficiary),
        _field('Account number', _account, obscure: true),
        _field('Confirm account number', _confirm, obscure: true),
        _field('IFSC', _ifsc),
        DropdownButtonFormField<String>(
          initialValue: _accountType,
          decoration: const InputDecoration(labelText: 'Account type'),
          items: const ['CURRENT', 'SAVINGS']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _accountType = value);
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue to Verification'),
        ),
      ],
    ),
  );
}
