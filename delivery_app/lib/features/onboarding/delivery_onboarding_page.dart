import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'onboarding_api_service.dart';

class DeliveryOnboardingPage extends StatefulWidget {
  const DeliveryOnboardingPage({super.key});
  @override
  State<DeliveryOnboardingPage> createState() => _DeliveryOnboardingPageState();
}

class _DeliveryOnboardingPageState extends State<DeliveryOnboardingPage> {
  final _api = DeliveryOnboardingApiService();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _address = TextEditingController(),
      _dob = TextEditingController(),
      _pan = TextEditingController(),
      _vehicleNumber = TextEditingController(),
      _licence = TextEditingController(),
      _licenceExpiry = TextEditingController(),
      _insuranceExpiry = TextEditingController(),
      _beneficiary = TextEditingController(),
      _account = TextEditingController(),
      _confirm = TextEditingController(),
      _ifsc = TextEditingController(),
      _upi = TextEditingController();
  String _vehicleType = 'BIKE';
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
  bool get _needsVehicleDocuments =>
      ['BIKE', 'SCOOTER', 'CAR'].contains(_vehicleType);
  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _address,
      _dob,
      _pan,
      _vehicleNumber,
      _licence,
      _licenceExpiry,
      _insuranceExpiry,
      _beneficiary,
      _account,
      _confirm,
      _ifsc,
      _upi,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final required = [
      _name,
      _phone,
      _address,
      _pan,
      _beneficiary,
      _account,
      _ifsc,
    ];
    if (required.any((field) => field.text.trim().isEmpty) ||
        (_needsVehicleDocuments &&
            (_vehicleNumber.text.trim().isEmpty ||
                _licence.text.trim().isEmpty))) {
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
        'legalName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'dateOfBirth': _dob.text.trim(),
        'address': _address.text.trim(),
        'panNumber': _pan.text.trim(),
        'vehicleType': _vehicleType,
        'vehicleNumber': _vehicleNumber.text.trim(),
        if (_needsVehicleDocuments)
          'drivingLicenceNumber': _licence.text.trim(),
        if (_needsVehicleDocuments)
          'drivingLicenceExpiry': _licenceExpiry.text.trim(),
        if (_needsVehicleDocuments)
          'insuranceExpiry': _insuranceExpiry.text.trim(),
        'bank': {
          'beneficiaryName': _beneficiary.text.trim(),
          'accountNumber': _account.text.trim(),
          'ifsc': _ifsc.text.trim(),
        },
        'upiId': _upi.text.trim(),
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
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: optional ? '$label (optional)' : label,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery Verification')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _field('Legal name', _name),
        _field('Phone', _phone),
        _field('Email', _email, optional: true),
        _field('Date of birth', _dob),
        _field('Address', _address),
        _field('PAN', _pan),
        DropdownButtonFormField<String>(
          initialValue: _vehicleType,
          decoration: const InputDecoration(labelText: 'Vehicle type'),
          items: const ['BIKE', 'SCOOTER', 'CAR', 'BICYCLE', 'WALKER']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _vehicleType = value);
          },
        ),
        if (_needsVehicleDocuments) ...[
          _field('Vehicle number', _vehicleNumber),
          _field('Driving licence number', _licence),
          _field('Driving licence expiry', _licenceExpiry),
          _field('Insurance expiry', _insuranceExpiry),
        ],
        const SizedBox(height: 18),
        Text('Bank Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        _documentTile('IDENTITY_PROOF', 'Identity proof'),
        _documentTile('PAN', 'PAN document'),
        _documentTile('BANK_PROOF', 'Bank proof'),
        if (_needsVehicleDocuments) ...[
          _documentTile('DRIVING_LICENCE', 'Driving licence'),
          _documentTile('RC', 'Vehicle RC'),
          _documentTile('INSURANCE', 'Vehicle insurance'),
        ],
        _field('Beneficiary name', _beneficiary),
        _field('Account number', _account, optional: true),
        _field('Confirm account number', _confirm, optional: true),
        _field('IFSC', _ifsc, optional: true),
        _field('UPI ID', _upi, optional: true),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
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
