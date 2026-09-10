import 'package:flutter/material.dart';

import 'store_api_service.dart';

class CreateStorePage extends StatefulWidget {
  const CreateStorePage({
    super.key,
    required this.onStoreCreated,
  });

  final VoidCallback onStoreCreated;

  @override
  State<CreateStorePage> createState() =>
      _CreateStorePageState();
}

class _CreateStorePageState
    extends State<CreateStorePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _addressController =
      TextEditingController();

  final _minimumOrderController =
      TextEditingController(text: '199');

  final StoreApiService _storeApiService =
      StoreApiService();

  String _moduleId = 'food';
  String _zoneId = 'zone1';

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _minimumOrderController.dispose();
    super.dispose();
  }

  Future<void> _createStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await _storeApiService.createStore(
        name: _nameController.text.trim(),
        moduleId: _moduleId,
        zoneId: _zoneId,
        address:
            _addressController.text.trim(),
        minimumOrder: double.tryParse(
              _minimumOrderController.text,
            ) ??
            0,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Store created successfully',
          ),
        ),
      );

      widget.onStoreCreated();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to create store: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Store'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Store name is required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _moduleId,
              decoration: const InputDecoration(
                labelText: 'Module',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'food',
                  child: Text('Food'),
                ),
                DropdownMenuItem(
                  value: 'grocery',
                  child: Text('Grocery'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _moduleId = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _zoneId,
              decoration: const InputDecoration(
                labelText: 'Zone',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'zone1',
                  child: Text(
                    'Hyderabad Central',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _zoneId = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Store Address',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Store address is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller:
                  _minimumOrderController,
              keyboardType:
                  TextInputType.number,
              decoration: const InputDecoration(
                labelText:
                    'Minimum Order Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed:
                  _isSaving ? null : _createStore,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Create Store',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
