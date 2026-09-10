import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'products_api_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProductsApiService _apiService = ProductsApiService();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;
  String? _error;
  String? _updatingProductId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _apiService.getCategories(),
        _apiService.getProducts(),
      ]);

      if (!mounted) return;

      setState(() {
        _categories = results[0];
        _products = results[1];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    String categoryName = '';

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Category'),
          content: TextField(
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'Example: Main Course',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              categoryName = value;
            },
            onSubmitted: (value) {
              final name = value.trim();

              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = categoryName.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(name);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      final category = await _apiService.createCategory(name: name);

      if (!mounted) return;

      setState(() {
        _categories.add(category);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category created successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create category: $error')),
      );
    }
  }

  Future<void> _addProduct() async {
    if (_categories.isEmpty) {
      final createCategory = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Category required'),
            content: const Text(
              'Create at least one category before adding a product.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Create Category'),
              ),
            ],
          );
        },
      );

      if (createCategory == true) {
        await _createCategory();
      }

      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(categories: _categories),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormPage(categories: _categories, product: product),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _toggleAvailability(
    Map<String, dynamic> product,
    bool value,
  ) async {
    final productId = product['id']?.toString() ?? '';

    if (productId.isEmpty) return;

    try {
      setState(() {
        _updatingProductId = productId;
      });

      await _apiService.updateAvailability(
        productId: productId,
        isAvailable: value,
      );

      if (!mounted) return;

      setState(() {
        product['isAvailable'] = value;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update product: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingProductId = null;
        });
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    final productName = product['name']?.toString() ?? 'this product';

    if (productId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete $productName?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _updatingProductId = productId;
      });

      await _apiService.deleteProduct(productId);

      if (!mounted) return;

      setState(() {
        _products.removeWhere((item) => item['id']?.toString() == productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete product: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingProductId = null;
        });
      }
    }
  }

  String _categoryName(String categoryId) {
    for (final category in _categories) {
      if (category['id']?.toString() == categoryId) {
        return category['name']?.toString() ?? 'Category';
      }
    }

    return 'Category';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add Category',
            onPressed: _createCategory,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Unable to load products',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_products.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          const Text(
            'No products yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _categories.isEmpty
                ? 'Create a category and add your first product.'
                : 'Add your first product to start building your menu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_categories.isEmpty)
            FilledButton.icon(
              onPressed: _createCategory,
              icon: const Icon(Icons.add),
              label: const Text('Create Category'),
            ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];

        final productId = product['id']?.toString() ?? '';

        final available = product['isAvailable'] == true;

        final stock = product['stock'] ?? 0;

        final categoryId = product['categoryId']?.toString() ?? '';

        final price = product['price'] ?? 0;

        final imageUrl = product['imageUrl']?.toString() ?? '';

        final isUpdating = _updatingProductId == productId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            onTap: isUpdating
                ? null
                : () {
                    _editProduct(product);
                  },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.fastfood,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
            title: Text(
              product['name']?.toString() ?? 'Product',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_categoryName(categoryId)} • ₹$price'),
                  const SizedBox(height: 3),
                  Text('Stock: $stock'),
                  const SizedBox(height: 3),
                  Text(available ? 'Available' : 'Unavailable'),
                ],
              ),
            ),
            trailing: isUpdating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'availability':
                          _toggleAvailability(product, !available);
                          break;

                        case 'edit':
                          _editProduct(product);
                          break;

                        case 'delete':
                          _deleteProduct(product);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'availability',
                        child: Text(
                          available ? 'Mark Unavailable' : 'Mark Available',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Product'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Product'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, required this.categories, this.product});

  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  final ProductsApiService _apiService = ProductsApiService();

  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;

  late final TextEditingController _descriptionController;

  late final TextEditingController _priceController;

  late final TextEditingController _stockController;

  String? _categoryId;

  bool _isSaving = false;

  XFile? _selectedImage;
  String? _existingImageUrl;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _existingImageUrl = product?['imageUrl']?.toString();

    if (_existingImageUrl?.isEmpty == true) {
      _existingImageUrl = null;
    }

    _nameController = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );

    _priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );

    _stockController = TextEditingController(
      text: product?['stock']?.toString() ?? '0',
    );

    final existingCategoryId = product?['categoryId']?.toString();

    final categoryExists = widget.categories.any(
      (category) => category['id']?.toString() == existingCategoryId,
    );

    if (categoryExists) {
      _categoryId = existingCategoryId;
    } else if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select image: $error')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoryId == null) {
      return;
    }

    final price = double.tryParse(_priceController.text.trim());

    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        imageUrl = await _apiService.uploadProductImage(
          filePath: _selectedImage!.path,
        );
      }

      if (_isEditing) {
        await _apiService.updateProduct(
          productId: widget.product!['id'].toString(),
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          imageUrl: imageUrl,
        );
      } else {
        await _apiService.createProduct(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save product: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildProductImage() {
    Widget child;

    if (_selectedImage != null) {
      child = Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_existingImageUrl != null) {
      child = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    } else {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 48),
          SizedBox(height: 8),
          Text('Choose Product Image'),
        ],
      );
    }

    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProductImage(),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _selectedImage != null || _existingImageUrl != null
                      ? 'Change Image'
                      : 'Choose Image',
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(category['name']?.toString() ?? 'Category'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Category is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');

                if (price == null || price < 0) {
                  return 'Enter a valid price';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final stock = int.tryParse(value?.trim() ?? '');

                if (stock == null || stock < 0) {
                  return 'Enter valid stock';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Update Product' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
